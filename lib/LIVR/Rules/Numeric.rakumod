unit module LIVR::Rules::Numeric;
use LIVR::Utils :DEFAULT, :internal;

# The LIVR 2.0 rules ignore extra arguments

our sub integer(@, %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'NOT_INTEGER' unless looks-like-number($value) && $value.Int eq $value;
        $output = $value.Int;
        return;
    };
}

our sub positive_integer(@, %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'NOT_POSITIVE_INTEGER' unless looks-like-number($value)
                                          && $value.Int eq $value
                                          && $value > 0;

        $output = $value.Int;
        return;
    };
}

our sub decimal(@, %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'NOT_DECIMAL' unless looks-like-number($value);

        $output = $value.Numeric;
        return;
    };
}

our sub positive_decimal(@, %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;


        return 'NOT_POSITIVE_DECIMAL' unless looks-like-number($value)
                                          && $value > 0;
                                 
        $output = $value.Numeric;
        return;
    };
}

our sub max_number([Numeric $max-number, *@], %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;
        return 'NOT_NUMBER' unless looks-like-number($value);

        return 'TOO_HIGH' if $value > $max-number;

        $output = $value.Numeric;
        return;
    };
}

our sub min_number([Numeric $min-number, *@], %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;
        return 'NOT_NUMBER' unless looks-like-number($value);

        return 'TOO_LOW' if $value < $min-number;
        
        $output = $value.Numeric;
        return;
    };
}

our sub number_between([Numeric $min-number, Numeric $max-number, *@], %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;
        return 'NOT_NUMBER' unless looks-like-number($value);

        return 'TOO_LOW' if $value < $min-number;
        return 'TOO_HIGH' if $value > $max-number;
        
        $output = $value.Numeric;
        return;
    };
}


# LIVR 2.5

# A number in the grammar of the "decimal" rule, -?[0-9]+(\.[0-9]+)?, without captures: they
# make a match several times slower
my $decimal-re = rx/^ '-'? <[0..9]>+ [ '.' <[0..9]>+ ]? $/;

our sub max_decimals(@args, %builders) {
    my $max-decimals = integer-argument(@args[0]);
    die "LIVR: rule [max_decimals] takes a non-negative integer\n" unless $max-decimals.defined && $max-decimals >= 0;

    return sub ($value, $all-values, $output is rw) {
        return unless $value.defined;

        if $value ~~ Str {
            return if $value eq '';

            # Counted as written, without the trailing zeros: "1.230" has 2 decimals
            return 'NOT_NUMBER' unless $value ~~ $decimal-re;

            my $decimals = 0;
            with $value.index('.') -> $dot-index {
                my $fraction = $value.substr($dot-index + 1);
                $decimals = $fraction.chars;
                $decimals-- while $decimals && $fraction.substr($decimals - 1, 1) eq '0';
            }
            return 'TOO_MANY_DECIMALS' if $decimals > $max-decimals;

            # The output is a number: a value beyond a finite double, a "1" with 400 zeros, is
            # not one in JSON (section 2.4)
            my $number = $value.Numeric;
            return 'NOT_NUMBER' if $number.Num == Inf || $number.Num == -Inf;

            $output = $number;
            return;
        }

        return 'NOT_NUMBER' if $value ~~ Bool;
        return 'FORMAT_ERROR' unless $value ~~ Real;

        # In the string form: 1.230 has 2 decimals, 1e-7 has 7
        my $string = string-form($value);
        my $dot-index = $string.index('.');
        my $decimals = $dot-index.defined ?? $string.chars - $dot-index - 1 !! 0;
        return 'TOO_MANY_DECIMALS' if $decimals > $max-decimals;

        return;
    };
}
