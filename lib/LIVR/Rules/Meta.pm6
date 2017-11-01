unit package LIVR::Rules::Meta;
use LIVR::Validator;
use LIVR::Utils;

our sub nested_object([$livr-rules], %builders) {
    my $validator = LIVR::Validator.new(livr-rules => $livr-rules)
        .register-rules(%builders)
        .prepare();

    return sub ($nested-object, $all-values, $output is rw) {
        return if is-no-value($nested-object);
        return 'FORMAT_ERROR' unless $nested-object ~~ Hash;

        my $result = $validator.validate( $nested-object );

        if $result.defined {
            $output = $result;
            return;
        } else {
            return $validator.errors;
        }
    }
}

our sub list_of(@args is copy, $builders) {
    my @rules;
    if (@args[0] ~~ Array) {
        @rules = |@args[0];
    } else {
        @rules = @args;
    }

    my $validator = LIVR::Validator.new(livr-rules => { field => @rules })
        .register-rules($builders)
        .prepare();

    return sub ($values, $all-values, $output is rw) {
        return if is-no-value($values);
        return 'FORMAT_ERROR' unless $values ~~ Array;

        my ( @results, @errors );

        for @$values -> $value {
            my $result = $validator.validate({field => $value});
            

            if $result.defined {
                @results.push( $result<field> );
                @errors.push(Any);
            } else {
                 @errors.push( $validator.errors()<field> );
                 @results.push(Any);
            }
        }

        if @errors.elems {
            return @errors;
        } else {
            $output = @results;
            return;
        }
    }
}

our sub list_of_objects([$livr-rules], $builders) {
    my $validator = LIVR::Validator.new(livr-rules => $livr-rules)
        .register-rules($builders)
        .prepare();

    return sub ($objects, $all-values, $output is rw) {
        return if is-no-value($objects);
        return 'FORMAT_ERROR' unless $objects ~~ Array;

        my ( @results, @errors );

        for @$objects -> $object {
            my $result = $validator.validate($object);
            
            if $result.defined {
                @results.push( $result );
                @errors.push(Any);
            } else {
                 @errors.push( $validator.errors() );
                 @results.push(Any);
            }
        }

        if @errors.elems {
            return @errors;
        } else {
            $output = @results;
            return;
        }
    }
}

our sub list_of_different_objects([$selector-field, $livrs], $builders) {
    my %validators;
    
    for %$livrs.kv -> $selector-value, $livr-rules {
        my $validator = LIVR::Validator.new(livr-rules => $livr-rules)
            .register-rules($builders)
            .prepare();

        %validators{$selector-value} = $validator;
    }

    return sub ($objects, $all-values, $output is rw) {
        return if is-no-value($objects);
        return 'FORMAT_ERROR' unless $objects ~~ Array;

        my ( @results, @errors );

        for @$objects -> $object {
            if $object !~~ Hash || !$object{$selector-field} || !%validators{ $object{$selector-field} } {
                @errors.push('FORMAT_ERROR');
                next;
            }

            my $validator = %validators{ $object{$selector-field} };
            my $result = $validator.validate($object);
            
            if $result.defined {
                @results.push( $result );
                @errors.push(Any);
            } else {
                 @errors.push( $validator.errors() );
                 @results.push(Any);
            }
        }

        if @errors.elems {
            return @errors;
        } else {
            $output = @results;
            return;
        }
    }
}



# sub variable_object {
#     my ( $selector_field, $livrs, $rule_builders ) = @_;

#     my %validators;
#     foreach my $selector_value ( keys %$livrs ) {
#         my $validator = Validator::LIVR->new( $livrs->{$selector_value} )->register_rules(%$rule_builders)->prepare();

#         $validators{$selector_value} = $validator;
#     }


#     return sub {
#         my ( $object, $params, $output_ref ) = @_;
#         return if !defined($object) || $object eq '';


#         if ( ref($object) ne 'HASH' || !$object->{$selector_field} || !$validators{$object->{$selector_field}} ) {
#             return 'FORMAT_ERROR';
#         }

#         my $validator = $validators{ $object->{$selector_field} };

#         if ( my $result = $validator->validate($object) ) {
#             $$output_ref = $result;
#             return;
#         } else {
#             return $validator->get_errors();
#         }
#     }
# }


# sub livr_or { # we call it livr_or to avoid conflicts with the "or" operator
#     my @rule_sets = @_;
#     my $rule_builders = pop @rule_sets;

#     my @validators = map {
#         Validator::LIVR->new( { field => $_ } )->register_rules(%$rule_builders)->prepare()
#     } @rule_sets;

#     return sub {
#         my ($value, undef, $output_ref) = @_;
#         return if !defined($value) || $value eq '';

#         my $last_error;

#         for my $validator (@validators) {
#             my $result = $validator->validate({ field => $value });

#             if ($result) {
#                 $$output_ref = $result->{field};
#                 return;
#             } else {
#                 $last_error = $validator->get_errors()->{field};
#             }
#         }

#         return $last_error if $last_error;
#         return;
#     }
# }
