unit package LIVR::Rules::Special;
use LIVR::Utils;
use Email::Valid;
# use Regexp::Common qw/URI/;
# use Time::Piece;
#

my $email-validator = Email::Valid.new(:simple(True));

our sub email([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'WRONG_EMAIL' unless $email-validator.validate($value);
        return 'WRONG_EMAIL' if $email-validator.parse($value)<email><domain> ~~ /_/; # issue in Email::Valid
        return;
    };
}

our sub equal_to_field([$field], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'FIELDS_NOT_EQUAL' unless $value eq $all-values{$field};
        return;
    };
}

our sub url([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        # $value .=subst(/#[^#]*$/, '');

        # return 'WRONG_URL' unless lc($value) =~ /^$RE{URI}{HTTP}{-scheme => 'https?'}$/;
        return;
    };
}

# our sub email([], $builders) {
#     return sub ($value, $all-values, $output is rw) {
#         return if is-no-value($value);
#         return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

#         my $iso_date_re = qr#^
#             (?<year>\d{4})-
#             (?<month>[0-1][0-9])-
#             (?<day>[0-3][0-9])
#         $#x;

#         return 'WRONG_EMAIL' unless $email-validator.validate($value);
#         return 'WRONG_EMAIL' if $email-validator.parse($value)<email><domain> ~~ /_/; # issue in Email::Valid
#         return;
#     };
# }


# sub iso_date {
#     return sub {
#         my $value = shift;
#         return if !defined($value) || $value eq '';
#         return 'FORMAT_ERROR' if ref($value);
#
#         my $iso_date_re = qr#^
#             (?<year>\d{4})-
#             (?<month>[0-1][0-9])-
#             (?<day>[0-3][0-9])
#         $#x;
#
#         if ( $value =~ $iso_date_re ) {
#             my $date = eval { Time::Piece->strptime($value, "%Y-%m-%d") };
#             return "WRONG_DATE" if !$date || $@;
#
#             if ( $date->year == $+{year} && $date->mon == $+{month} && $date->mday == $+{day} ) {
#                 return;
#             }
#         }
#
#         return "WRONG_DATE";
#     };
# }
