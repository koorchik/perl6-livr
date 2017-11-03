unit package LIVR::Rules::Modifiers;
use LIVR::Utils;

our sub trim([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;
        
        $output = $value.trim;
        return;
    };
}

our sub to_lc([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;
        
        $output = $value.lc;
        return;
    };
}

our sub to_uc([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;
        
        $output = $value.uc;
        return;
    };
}


# sub remove {
#     my $chars = shift;
#     my $re = qr/[\Q$chars\E]/;

#     return sub {
#         my ( $value, undef, $output_ref ) = @_;
#         return if !defined($value) || ref($value) || $value eq '';

#         $value =~ s/$re//g;

#         $$output_ref = $value;
#         return;
#     };
# }

# sub leave_only {
#     my $chars = shift;
#     my $re = qr/[^\Q$chars\E]/;

#     return sub {
#         my ( $value, undef, $output_ref ) = @_;
#         return if !defined($value) || ref($value) || $value eq '';

#         $value =~ s/$re//g;

#         $$output_ref = $value;
#         return;
#     };
# }

# sub default {
#     my $default_value = shift;

#     return sub {
#         my ( $value, undef, $output_ref ) = @_;

#         if ( !defined($value) || $value eq '' ) {
#             $$output_ref = $default_value;
#         }

#         return;
#     };
# }