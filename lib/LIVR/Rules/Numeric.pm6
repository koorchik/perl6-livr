unit package LIVR::Rules::Numeric;
use LIVR::Utils;

# use Scalar::Util qw/looks_like_number/;

our sub integer([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value ~~ Hash || $value ~~ Array;

        # return 'NOT_INTEGER' unless $value =~ /^\-?\d+$/ && looks_like_number($value);
        $output = $value.Int;
        return;
    };
}

our sub positive_integer([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value ~~ Hash || $value ~~ Array;


        # return 'NOT_POSITIVE_INTEGER' unless $value =~ /^\d+$/
        #                               && looks_like_number($value)
        #                               && $value > 0;

        $output = $value.Int;
        return;
    };
}

our sub decimal([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value ~~ Hash || $value ~~ Array;

        # return 'NOT_DECIMAL' unless $value =~ /^\-?[\d.]+$/
        #                      && looks_like_number($value);

        $output = $value.Rat;
        return;
    };
}

our sub positive_decimal([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value ~~ Hash || $value ~~ Array;


        # return 'NOT_POSITIVE_DECIMAL' unless $value =~ /^\-?[\d.]+$/
        #                               && looks_like_number($value)
        #                               && $value > 0;
        $output = $value.Rat;
        return;
    };
}

our sub max_number([$max_number], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value ~~ Hash || $value ~~ Array;

        #
        # return 'TOO_HIGH' if $value > $max_number;

        $output = $value.Rat;
        return;
    };
}

our sub min_number([$min_number], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value ~~ Hash || $value ~~ Array;

        # return 'TOO_LOW' if $value < $min_number;
        
        $output = $value.Rat;
        return;
    };
}

our sub number_between([$min_number, $max_number], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value ~~ Hash || $value ~~ Array;

        # return 'TOO_LOW' if $value < $min_number;
        # return 'TOO_HIGH' if $value > $max_number;
        
        $output = $value.Rat;
        return;
    };
}
