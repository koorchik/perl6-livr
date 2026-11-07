unit module LIVR::Rules::Special;
use LIVR::Utils :DEFAULT, :internal;

# The same check as in the reference JavaScript implementation: a dot-separated or quoted
# local part, and a domain name or an IPv4 address in brackets. Without subrules, as they
# make a regex slower.
our sub email(@, %builders) {
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

our sub equal_to_field([$field, *@], %builders) {
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
our sub url(@, %builders) {
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

# YYYY-MM-DD with ASCII digits, a valid date of the proleptic Gregorian calendar. Without
# captures: they make a match several times slower
my $iso-date-re = rx/^ <[0..9]> ** 4 '-' <[0..9]> ** 2 '-' <[0..9]> ** 2 $/;

sub is-iso-date(Str $value --> Bool:D) {
    return False unless $value ~~ $iso-date-re;

    my $month = $value.substr(5, 2).Int;
    my $day = $value.substr(8, 2).Int;
    return False unless 1 <= $month <= 12 && $day >= 1;
    return True if $day <= 28;

    my $year = $value.substr(0, 4).Int;
    my $days-in-month = $month == 2
        ?? ($year %% 4 && ($year !%% 100 || $year %% 400) ?? 29 !! 28)
        !! 31 - ($month - 1) % 7 % 2;
    return $day <= $days-in-month;
}

#   iso_date: YYYY-MM-DD, the value is not changed
#   { iso_date => { min => ..., max => ... } }: with bounds (LIVR 2.5), see LIVR::Rules::Dates.
#   An argument that is not an options object is a schema error (LIVR 2.0 ignored it)
our sub iso_date(@args, %builders) {
    # { iso_date => Any } (null) is the plain iso_date: LIVR 2.0 ignored the arguments
    if @args && !(@args == 1 && !@args[0].defined) {
        # Loaded on first use, as the other LIVR 2.5 rules
        require LIVR::Rules::Dates;
        return LIVR::Rules::Dates::iso_date(@args, %builders);
    }

    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'WRONG_DATE' unless $value ~~ Str && is-iso-date($value);
        return;
    };
}
