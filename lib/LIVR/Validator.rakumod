class LIVR::Validator {
    has $.is-auto-trim = False;
    has %.livr-rules;
    has $.errors is readonly;

    has Bool $!is-prepared = False;
    has @!field-validators; # field name => validators of the field

    # Rule builders. A new validator shares the default rules, and the nested validators of meta
    # rules share the rules of their parent: rules are copied only when a validator registers
    # its own, not every time a validator is built.
    has $!rule-builders;
    has Bool $!owns-rule-builders = False;

    # Rule builders that a validator owns. They remember the default rules they were copied from,
    # so that nested validators with the same default rules can share them.
    my class RuleBuilders is Hash {
        has $.defaults is rw;
    }

    # Replaced, not changed, by a registration: validators keep the default rules they were
    # created with
    my $DEFAULT-RULES = {};

    my $IS-DEFAULT-AUTO-TRIM = 0;

    method register-default-rules(%rules) {
        my %default-rules = %$DEFAULT-RULES, %rules;
        $DEFAULT-RULES = %default-rules;
    }

    method register-aliased-default-rule(Hash $alias) {
        die 'Alias name required' unless $alias<name>;
        self.register-default-rules({ $alias<name> => self!build-aliased-rule(%$alias) });
    }

    method get-default-rules() {
        return $DEFAULT-RULES;
    }

    method default-auto-trim(Bool:D $is-auto-trim) {
        $IS-DEFAULT-AUTO-TRIM = $is-auto-trim;
    }

    submethod BUILD(:%!livr-rules, Bool :$is-auto-trim) {
        $!is-auto-trim = $is-auto-trim.defined ?? $is-auto-trim !! $IS-DEFAULT-AUTO-TRIM;
        $!rule-builders = $DEFAULT-RULES;
    }

    method !own-rule-builders() {
        return if $!owns-rule-builders;

        my $defaults = $!rule-builders ~~ RuleBuilders ?? $!rule-builders.defaults !! $!rule-builders;
        $!rule-builders = RuleBuilders.new(%$!rule-builders);
        $!rule-builders.defaults = $defaults;
        $!owns-rule-builders = True;
    }

    method register-rules(%rules) {
        # The rules of the parent validator, as meta rules register them, are shared when they
        # come from the same default rules
        return self if %rules === $!rule-builders;
        if !$!owns-rule-builders && %rules ~~ RuleBuilders && %rules.defaults === $!rule-builders {
            $!rule-builders = %rules;
            return self;
        }

        self!own-rule-builders();
        for %rules.pairs -> $rule {
            die "RULE_BUILDER [{$rule.key}] SHOULD BE A CODEREF" unless $rule.value ~~ Block;
            $!rule-builders{$rule.key} = $rule.value;
        }

        return self;
    }

    method get-rules() {
        # The caller may change them, so they are not shared anymore
        self!own-rule-builders();
        $!rule-builders;
    }

    method register-aliased-rule(Hash $alias) {
        die 'Alias name required' unless $alias<name>;
        my $rule-builder = self!build-aliased-rule(%$alias);

        self!own-rule-builders();
        $!rule-builders{ $alias<name> } = $rule-builder;

        return self;
    }

    method prepare {
        @!field-validators = ();

        for %!livr-rules.kv -> $field, $field-rules {
            my @field-rules = $field-rules ~~ Array ?? @$field-rules !! [$field-rules];

            my @validators;
            for @field-rules -> $rule {
                my ($rule-name, $rule-args) = self!parse-rule($rule);
                @validators.push( self!build-validator($rule-name, $rule-args) );
            }

            @!field-validators.push( $field => @validators ) if @validators;
        }

        $!is-prepared = True;

        return self;
    }

    method validate($data is copy) {
        self.prepare() unless $!is-prepared;

        unless ( $data ~~ Hash ) {
            $!errors = 'FORMAT_ERROR';
            return;
        }

        $data = self!auto-trim($data) if $!is-auto-trim;

        my ( %errors, %result );

        for @!field-validators -> $field-validators {
            my $field-name = $field-validators.key;
            my $value = $data{$field-name};

            # The output of the previous rules, the same as %result{$field-name}
            my $has-output = False;
            my $output;

            for $field-validators.value.list -> $validator-cb {
                my $field-result = $output // $value;

                my $error-code = $validator-cb( $has-output ?? $output !! $value, $data, $field-result );

                if $error-code {
                    %errors{$field-name} = $error-code;
                    $has-output = False;
                    last;
                } elsif $field-result.defined {
                    $has-output = True;
                    $output = $field-result;
                } elsif !$has-output && ($data{$field-name}:exists) {
                    $has-output = True;
                    $output = $field-result;
                }
            }

            %result{$field-name} = $output if $has-output;
        }

        if %errors.elems {
            $!errors = %errors;
            return;
        } else {
            $!errors = ();
            return %result;
        }
    }

    # All rules of a field as one rule, sub ($value, $all-values, $output is rw), for meta rules
    # and aliases. The rules run as in "validate": in order, each one gets the output of the
    # previous one. The caller passes the containing object as $all-values, and $output must
    # hold the value. Nil when the field has no rules.
    method field-rule(Str() $field) {
        self.prepare() unless $!is-prepared;

        my $field-validators = @!field-validators.first(*.key eq $field) // return Nil;
        my @validators = $field-validators.value.list;

        return @validators[0] if @validators == 1 && !$!is-auto-trim;

        my $is-auto-trim = $!is-auto-trim;
        return sub ($value, $all-values, $output is rw) {
            my $current = $is-auto-trim ?? self!auto-trim($value) !! $value;

            for @validators -> &validator {
                my $result = $current;
                my $error-code = validator($current, $all-values, $result);
                return $error-code if $error-code;
                $current = $result;
            }

            $output = $current;
            return;
        };
    }

    method !parse-rule($rule) {
        if $rule ~~ Hash {
            my ($name, $args) = $rule.kv;
            my $args-array = $args ~~ Array ?? $args !! [$args] ;
            return( $name, $args-array );
        } else {
            return( $rule, [] );
        }
    }

    method !build-validator($rule-name, $rule-args) {
        # null in place of a rule name ({ values => Any }) is not a rule either
        my $rule-builder = $rule-name.defined ?? $!rule-builders{$rule-name} !! Nil;
        die "Rule [{$rule-name // 'null'}] not registered\n" unless $rule-builder;
        return $rule-builder( $rule-args, $!rule-builders );
    }

    method !build-aliased-rule(%alias) {
        die 'Alias name required'  unless %alias<name>;
        die 'Alias rules required' unless %alias<rules>;

        my $livr-rules = { value => %alias<rules> };
        my $error = %alias<error>;

        return sub (@, %builders) {
            my &value-rule = LIVR::Validator.new(livr-rules => $livr-rules)
                .register-rules(%builders)
                .field-rule('value')
                // return sub ($value, $all-values, $output is rw) { $output = Any; return };

            # Aliases are transparent: their rules see the containing object of the field
            return &value-rule unless $error;

            return sub ($value, $all-values, $output is rw) {
                return $error if value-rule($value, $all-values, $output);
                return;
            };
        };
    }

    method !auto-trim($data) {
        if ( $data ~~ Str ) {
            return $data.trim;
        } elsif ( $data ~~ Hash ) {
            my $trimmed-data = {};
        
            for %$data.kv -> $key, $value {
                $trimmed-data{$key} = self!auto-trim( $value );
            }
        
            return $trimmed-data;
        } elsif ( $data ~~ Array ) {
            my $trimmed-data = [];
        
            for @$data -> $value {
                $trimmed-data.push( self!auto-trim( $value ) );
            }
        
            return $trimmed-data;
        }

        return $data;
    }
}
