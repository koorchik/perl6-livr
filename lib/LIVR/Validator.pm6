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
            # croak "RULE_BUILDER [$rule_name] SHOULD BE A CODEREF" unless ref($rule_builder) eq 'CODE';
            %!validator-builders{$name} = $builder;
        }
    }

    method prepare {
        for %.livr-rules.kv -> $field, $field-rules {
            # $field_rules = [$field_rules] if ref($field_rules) ne 'ARRAY';
            my @field-rules = [ $field-rules ];

            my @validators;

            for @field-rules -> $rule {
                my ($rule-name, $rule-args) = self!parse-rule($rule);
                @validators.push( self!build-validator($rule-name, $rule-args) );
            }

            %!validators{$field} = @validators;
        }

        $!is-prepared = True;
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
                } elsif ( $data{$field-name}:exists ) {
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
        my ($name, $args);

        if $rule ~~ Hash {
            ($name, $args) = $rule.kv;
            $args = [$args] unless $args ~~ Array;
        } else {
            $name = $rule;
            $args = [];
        }

        return( $name, $args );
    }

    method !build-validator($rule-name, $rule-args) {
        # die "Rule [$name] not registered\n" unless $self->{validator_builders}->{$name};
        return %!validator-builders{$rule-name}( $rule-args, self.livr-rules );
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
