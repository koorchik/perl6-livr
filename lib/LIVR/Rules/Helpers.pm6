unit package LIVR::Rules::Helpers;
use LIVR::Validator;

our sub nested_object([$livr-rules], %builders) {
    my $validator = LIVR::Validator.new(livr-rules => $livr-rules)
        .register-rules(%builders)
        .prepare();

    return sub ($nested-object, $all-values, $output is rw) {
        return if !$nested-object.defined || $nested-object eq '';
        return 'FORMAT_ERROR' unless $nested-object ~~ Hash;

        my $result = $validator.validate( $nested-object );

        if ( $result ) {
            $output = $result;
            return;
        } else {
            return $validator.errors;
        }
    }
}


# sub list_of {
#     my ( $rules, $rule_builders );
#
#     if (ref $_[0] eq 'ARRAY') {
#         ( $rules, $rule_builders ) = @_;
#     } else {
#         $rules = [@_];
#         $rule_builders = pop @$rules;
#     }
#
#     my $livr =  { field => $rules };
#
#     my $validator = Validator::LIVR->new($livr)->register_rules(%$rule_builders)->prepare();
#
#     return sub {
#         my ( $values, $params, $output_ref ) = @_;
#         return if !defined($values) || $values eq '';
#
#         return 'FORMAT_ERROR' unless ref($values) eq 'ARRAY';
#
#         my ( @results, @errors );
#
#         foreach my $val (@$values) {
#             if ( my $result = $validator->validate( {field => $val} ) ) {
#                 push @results, $result->{field};
#                 push @errors, undef;
#             } else {
#                 push @errors, $validator->get_errors()->{field};
#                 push @results, undef;
#             }
#         }
#
#         if ( grep {$_} @errors ) {
#             return \@errors;
#         } else {
#             $$output_ref = \@results;
#             return;
#         }
#     }
# }
#
#
# sub list_of_objects {
#     my ($livr, $rule_builders) = @_;
#
#     my $validator = Validator::LIVR->new($livr)->register_rules(%$rule_builders)->prepare();
#
#     return sub {
#         my ( $objects, $params, $output_ref ) = @_;
#         return if !defined($objects) || $objects eq '';
#
#         return 'FORMAT_ERROR' unless ref($objects) eq 'ARRAY';
#
#         my ( @results, @errors );
#
#         foreach my $obj (@$objects) {
#             if ( my $result = $validator->validate($obj) ) {
#                 push @results, $result;
#                 push @errors, undef;
#             } else {
#                 push @errors, $validator->get_errors();
#                 push @results, undef;
#             }
#         }
#
#         if ( grep {$_} @errors ) {
#             return \@errors;
#         } else {
#             $$output_ref = \@results;
#             return;
#         }
#     }
# }
#
# sub list_of_different_objects {
#     my ( $selector_field, $livrs, $rule_builders ) = @_;
#
#     my %validators;
#     foreach my $selector_value ( keys %$livrs ) {
#         my $validator = Validator::LIVR->new( $livrs->{$selector_value} )->register_rules(%$rule_builders)->prepare();
#
#         $validators{$selector_value} = $validator;
#     }
#
#
#     return sub {
#         my ( $objects, $params, $output_ref ) = @_;
#         return if !defined($objects) || $objects eq '';
#
#         return 'FORMAT_ERROR' unless ref($objects) eq 'ARRAY';
#
#         my ( @results, @errors );
#
#         foreach my $obj (@$objects) {
#             if ( ref($obj) ne 'HASH' || !$obj->{$selector_field} || !$validators{$obj->{$selector_field}} ) {
#                 push @errors, 'FORMAT_ERROR';
#                 next;
#             }
#
#             my $validator = $validators{ $obj->{$selector_field} };
#
#             if ( my $result = $validator->validate($obj) ) {
#                 push @results, $result;
#                 push @errors, undef;
#             } else {
#                 push @errors, $validator->get_errors();
#             }
#         }
#
#         if ( grep {$_} @errors ) {
#             return \@errors;
#         } else {
#             $$output_ref = \@results;
#             return;
#         }
#     }
# }
