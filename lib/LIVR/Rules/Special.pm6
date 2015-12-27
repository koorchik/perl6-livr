unit package LIVR::Rules::Special;

# use Email::Valid;
# use Regexp::Common qw/URI/;
# use Time::Piece;
#

our sub email([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;

#         return 'WRONG_EMAIL' unless Email::Valid->address($value);
        return;
    };
}

our sub equal_to_field([$field], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;

        return 'FIELDS_NOT_EQUAL' unless $value eq $all-values{$field};
        return;
    };
}


# sub url {
#     return sub {
#         my $value = shift;
#         return if !defined($value) || $value eq '';
#         return 'FORMAT_ERROR' if ref($value);
#
#         $value =~ s/#[^#]*$//;
#
#         return 'WRONG_URL' unless lc($value) =~ /^$RE{URI}{HTTP}{-scheme => 'https?'}$/;
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