unit package LIVR::Rules::Numeric;

# use Scalar::Util qw/looks_like_number/;

our sub integer([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;

        # return 'NOT_INTEGER' unless $value =~ /^\-?\d+$/ && looks_like_number($value);
        return;
    };
}

our sub positive_integer([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;


        # return 'NOT_POSITIVE_INTEGER' unless $value =~ /^\d+$/
        #                               && looks_like_number($value)
        #                               && $value > 0;
        return;
    };
}

our sub decimal([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;

        # return 'NOT_DECIMAL' unless $value =~ /^\-?[\d.]+$/
        #                      && looks_like_number($value);

        return;
    };
}

our sub positive_decimal([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;


        # return 'NOT_POSITIVE_DECIMAL' unless $value =~ /^\-?[\d.]+$/
        #                               && looks_like_number($value)
        #                               && $value > 0;

        return;
    };
}

our sub max_number([$max_number], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;

        #
        # return 'TOO_HIGH' if $value > $max_number;
        # return;
    };
}

our sub min_number([$min_number], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;

        # return 'TOO_LOW' if $value < $min_number;
        # return;
    };
}

our sub number_between([$min_number, $max_number], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;

        # return 'TOO_LOW' if $value < $min_number;
        # return 'TOO_HIGH' if $value > $max_number;
        return;
    };
}
