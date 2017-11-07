unit package LIVR::Rules::Special;
use LIVR::Utils;
use Email::Valid;

my $email-validator = Email::Valid.new(:simple(True));

our sub email([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'WRONG_EMAIL' unless $email-validator.validate($value.Str);
        return 'WRONG_EMAIL' if $email-validator.parse($value.Str)<email><domain> ~~ /_/; # issue in Email::Valid
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
    my $url-re = rx:P5`^(?:(?:https?)://(?:(?:(?:(?:(?:(?:[a-zA-Z0-9][-a-zA-Z0-9]*)?[a-zA-Z0-9])[.])*(?:[a-zA-Z][-a-zA-Z0-9]*[a-zA-Z0-9]|[a-zA-Z])[.]?)|(?:[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+)))(?::(?:(?:[0-9]*)))?(?:/(?:(?:(?:(?:(?:(?:[a-zA-Z0-9\-_.!~*'():@&=+$,]+|(?:%[a-fA-F0-9][a-fA-F0-9]))*)(?:;(?:(?:[a-zA-Z0-9\-_.!~*'():@&=+$,]+|(?:%[a-fA-F0-9][a-fA-F0-9]))*))*)(?:/(?:(?:(?:[a-zA-Z0-9\-_.!~*'():@&=+$,]+|(?:%[a-fA-F0-9][a-fA-F0-9]))*)(?:;(?:(?:[a-zA-Z0-9\-_.!~*'():@&=+$,]+|(?:%[a-fA-F0-9][a-fA-F0-9]))*))*))*))(?:[?](?:(?:(?:[;/?:@&=+$,a-zA-Z0-9\-_.!~*'()]+|(?:%[a-fA-F0-9][a-fA-F0-9]))*)))?))?)$`;
    my $anchor-re = rx:P5/#[^#]*$/;

    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        if ($value.chars < 2083 && $value.subst($anchor-re, '').lc.match($url-re)) {
            $output = $value.Str;
            return;
        }

        return 'WRONG_URL';
    };
}

our sub iso_date([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        # $value .=subst(/#[^#]*$/, '');

        # my $rx = rx/^(?:(?:http|https)://)(?:\\S+(?::\\S*)?@)?(?:(?:(?:[1-9]\\d?|1\\d\\d|2[0-1]\\d|22[0-3])(?:\\.(?:1?\\d{1,2}|2[0-4]\\d|25[0-5])){2}(?:\\.(?:[0-9]\\d?|1\\d\\d|2[0-4]\\d|25[0-4]))|(?:(?:[a-z\\u00a1-\\uffff0-9]-*)*[a-z\\u00a1-\\uffff0-9]+)(?:\\.(?:[a-z\\u00a1-\\uffff0-9]-*)*[a-z\\u00a1-\\uffff0-9]+)*(?:\\.(?:[a-z\\u00a1-\\uffff]{2,})))\\.?|localhost)(?::\\d{2,5})?(?:[/?#]\\S*)?$/
        # return 'WRONG_URL' unless lc($value) =~ /^$RE{URI}{HTTP}{-scheme => 'https?'}$/;
        return;
    };
}

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
