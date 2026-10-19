unit module LIVR::Rules::Special;
use LIVR::Utils;

# The same check as in the reference JavaScript implementation: a dot-separated or quoted
# local part, and a domain name or an IPv4 address in brackets. Without subrules, as they
# make a regex slower.
our sub email([], %builders) {
    my $email-re = rx/^
        [
            <-[<>()\[\]\\.,;:\s@"]>+ [ '.' <-[<>()\[\]\\.,;:\s@"]>+ ]*
            || '"' <-[@\n\r\x[2028]\x[2029]]>+ '"'
        ]
        '@'
        [ '[' <[0..9]> ** 1..3 [ '.' <[0..9]> ** 1..3 ] ** 3 ']' || [ <[a..zA..Z\-0..9]>+ '.' ]+ <[a..zA..Z]> ** 2..* ]
    $/;

    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'WRONG_EMAIL' unless $value.Str ~~ $email-re;
        return;
    };
}

our sub equal_to_field([$field], %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'FIELDS_NOT_EQUAL' unless %all-values{$field}.defined && $value eq %all-values{$field};
        return;
    };
}

# The HTTP URI regex of Perl's Regexp::Common. Native Raku syntax, as the RakuAST
# compiler (the default one in Rakudo 2026.09) does not support Perl 5 regexes (:P5).
# Without subrules, as they make it 3 times slower, and without nested quantifiers
# like [ <[a..z]>+ ]*, as they backtrack exponentially when there are no subrules.
our sub url([], %builders) {
    my $url-re = rx/^
        'http' 's'? '://'
        [
            # A host name. Its labels do not start or end with "-", the last one starts with a letter
            [ <[a..zA..Z0..9]> [ <[\-a..zA..Z0..9]>* <[a..zA..Z0..9]> ]? '.' ]*
            <[a..zA..Z]> [ <[\-a..zA..Z0..9]>* <[a..zA..Z0..9]> ]? '.'?

            # Or an IPv4 address
            || <[0..9]>+ '.' <[0..9]>+ '.' <[0..9]>+ '.' <[0..9]>+
        ]
        [ ':' <[0..9]>* ]?
        [
            # The path and the query, with %-escaped characters
            '/' <[a..zA..Z0..9\-_.!~*'():@&=+$,;/]>* [ '%' <[a..fA..F0..9]> ** 2 <[a..zA..Z0..9\-_.!~*'():@&=+$,;/]>* ]*
            [ '?' <[;/?:@&=+$,a..zA..Z0..9\-_.!~*'()]>* [ '%' <[a..fA..F0..9]> ** 2 <[;/?:@&=+$,a..zA..Z0..9\-_.!~*'()]>* ]* ]?
        ]?
    $/;

    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        # Without the anchor: from the last "#" to the end
        my $url = $value.Str;
        with $url.rindex('#') -> $anchor-pos { $url = $url.substr(0, $anchor-pos) }

        if ($value.chars < 2083 && $url.lc.match($url-re)) {
            $output = $value.Str;
            return;
        }

        return 'WRONG_URL';
    };
}

our sub iso_date([], %builders) {
    my $iso-date-re = rx/^
        \d ** 4 \-               # year
        <[0..1]><[0..9]> \-      # month
        <[0..3]><[0..9]>         # day
    $/;

    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;
        
        if $value ~~ $iso-date-re {
            my Date $date = Date.new($value);
       
            return if $date eq $value;

            CATCH {
                return 'WRONG_DATE';
            }
        }

        return 'WRONG_DATE';
    };
}
