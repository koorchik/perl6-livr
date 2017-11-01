class LIVR::Validator {
    has Bool $.is-auto-trim = False;
    has %.livr-rules;
    has $.errors is readonly;

    has Bool $!is-prepared = False;
    has %!validators;
    has %!validator-builders;

    my %DEFAULT_RULES;

    method register-default-rules(%rules) {
        %DEFAULT_RULES.push(%rules);
    }

    submethod BUILD(:%!livr-rules) {
        self.register-rules(%DEFAULT_RULES);
    }

    method register-rules(%rules) {
        for %rules.kv -> $name, $builder {
            die "RULE_BUILDER [$name] SHOULD BE A CODEREF" unless $builder ~~ Block;
            %!validator-builders{$name} = $builder;
        }

        return self;
    }

    method prepare {
        for %.livr-rules.kv -> $field, $field-rules {
            my @field-rules = $field-rules ~~ Array ?? @$field-rules !! [$field-rules];

            my @validators;
            for @field-rules -> $rule {
                my ($rule-name, $rule-args) = self!parse-rule($rule);
                @validators.push( self!build-validator($rule-name, $rule-args) );
            }

            %!validators{$field} = @validators;
        }

        $!is-prepared = True;

        return self;
    }

    method validate($data) {
        self.prepare() unless $!is-prepared;

        unless ( $data ~~ Hash ) {
            $!errors = 'FORMAT_ERROR';
            return;
        }

        $data = self!auto-trim($data) if $!is-auto-trim;

        my ( %errors, %result );

        for %!validators.kv -> $field-name, $validators {
            next unless $validators && $validators.elems;

            my $value = $data{$field-name};
            my $is-ok = True;

            for @$validators -> $validator-cb {
                my $field-result = %result{$field-name} // $value;

                my $error-code = $validator-cb(
                    %result{$field-name}:exists ?? %result{$field-name} !! $value,
                    $data,
                    $field-result
                );

                if ( $error-code ) {
                    %errors{$field-name} = $error-code;
                    $is-ok = False;
                    last;
                } elsif (  $field-result.defined ) {
                    %result{$field-name} = $field-result;
                } elsif ( $data{$field-name}:exists && ! (%result{$field-name}:exists) ) {
                    %result{$field-name} = $field-result;
                }
            }
        }

        if ( %errors.elems ) {
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

    method !auto-trim($data) {
        # my $ref_type = ref($data);
        #
        # if ( !$ref_type && $data ) {
        #     $data =~ s/^\s+//;
        #     $data =~ s/\s+$//;
        #     return $data;
        # }
        # elsif ( $ref_type eq 'HASH' ) {
        #     my $trimmed_data = {};
        #
        #     foreach my $key ( keys %$data ) {
        #         $trimmed_data->{$key} = $self->_auto_trim( $data->{$key} );
        #     }
        #
        #     return $trimmed_data;
        # }
        # elsif ( $ref_type eq 'ARRAY' ) {
        #     my $trimmed_data = [];
        #
        #     for ( my $i = 0; $i < @$data; $i++ ) {
        #         $trimmed_data->[$i] = $self->_auto_trim( $data->[$i] )
        #     }
        #
        #     return $trimmed_data;
        # }

        return $data;
    }
}
