class LIVR::Validator {
    has $.is-auto-trim = False;
    has %.livr-rules;
    has $.errors is readonly;

    has Bool $!is-prepared = False;
    has @!field-validators; # field name => validators of the field
    has %!validator-builders;

    my %DEFAULT-RULES;

    my $IS-DEFAULT-AUTO-TRIM = 0;

    method register-default-rules(%rules) {
        %DEFAULT-RULES ,= %rules;
    }

    method register-aliased-default-rule(Hash $alias) {
        die 'Alias name required' unless $alias<name>;
        %DEFAULT-RULES{ $alias<name> } = self!build-aliased-rule(%$alias);
    }

    method get-default-rules() {
        return %DEFAULT-RULES;
    }

    method default-auto-trim(Bool:D $is-auto-trim) {
        $IS-DEFAULT-AUTO-TRIM = $is-auto-trim;
    }

    submethod BUILD(:%!livr-rules, Bool :$is-auto-trim) {
        $!is-auto-trim = $is-auto-trim.defined ?? $is-auto-trim !! $IS-DEFAULT-AUTO-TRIM;
        %!validator-builders = %DEFAULT-RULES;
    }

    method register-rules(%rules) {
        for %rules.pairs -> $rule {
            die "RULE_BUILDER [{$rule.key}] SHOULD BE A CODEREF" unless $rule.value ~~ Block;
            %!validator-builders{$rule.key} = $rule.value;
        }

        return self;
    }

    method get-rules() {
        %!validator-builders;
    }

    method register-aliased-rule(Hash $alias) {
        die 'Alias name required' unless $alias<name>;
        %!validator-builders{ $alias<name> } = self!build-aliased-rule(%$alias);
        
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
        die "Rule [$rule-name] not registered\n" unless %!validator-builders{$rule-name};
        return %!validator-builders{$rule-name}( $rule-args, %!validator-builders );
    }

    method !build-aliased-rule(%alias) {
        die 'Alias name required'  unless %alias<name>;
        die 'Alias rules required' unless %alias<rules>;

        my $livr-rules = { value => %alias<rules> };

        return sub ([], %builders) {
            my $validator = LIVR::Validator.new(livr-rules => $livr-rules)
                .register-rules(%builders)
                .prepare();

            return sub ($value, $all-values, $output is rw) {
                my $result = $validator.validate( { value => $value } );

                if ( $result.defined ) {
                    $output = $result<value>;
                    return;
                } else {
                    return %alias<error> || $validator.errors()<value>;
                }
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
