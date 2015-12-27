unit package LIVR::Rules::String;

our sub one_of(@args is copy, $builders) {
    my @allowed-values;
    if (@args[0] ~~ Array) {
        @allowed-values = |@args[0];
    } else {
        @allowed-values = @args;
    }

    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;

        return 'NOT_ALLOWED_VALUE' unless @allowed-values.grep(* eq $value);
        return;
    }
}

our sub max_length([$max-length], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;

        return 'TOO_LONG' if $value.chars > $max-length;
        return;
    };
}

our sub min_length([$min-length], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;

        return 'TOO_SHORT' if $value.chars < $min-length;
        return;
    };
}

our sub length_equal([$length], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;

        return 'TOO_SHORT' if $value.chars < $length;
        return 'TOO_LONG'  if $value.chars > $length;
        return;
    };
}

our sub length_between([$min-length, $max-length], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;

        return 'TOO_SHORT' if $value.chars < $min-length;
        return 'TOO_LONG'  if $value.chars > $max-length;
        return;
    };
}

our sub like([$re, $flags = ''], $builders) {
    my $is-ignore-case = index( $flags, 'i' ) >= 0;
    my $flagged-re = $is-ignore-case ?? rx:i/$re/ !! rx/$re/;

    return sub ($value, $all-values, $output is rw) {
        return if !$value.defined || $value eq '';
        return 'FORMAT_ERROR' unless $value ~~ Cool;

        return 'WRONG_FORMAT' unless $value ~~ m/$flagged-re/;
        return;
    };
}
