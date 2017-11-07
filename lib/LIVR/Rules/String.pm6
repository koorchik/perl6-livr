unit package LIVR::Rules::String;
use LIVR::Utils;

our sub one_of(@args is copy, $builders) {
    my @allowed-values;
    if (@args[0] ~~ Array) {
        @allowed-values = |@args[0];
    } else {
        @allowed-values = @args;
    }

    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        for @allowed-values -> $allowed-value {
            if $value eq $allowed-value {
                $output = $allowed-value;
                return;
            }
        }

        return 'NOT_ALLOWED_VALUE';
    }
}


our sub max_length([$max-length], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'TOO_LONG' if $value.chars > $max-length;
        
        $output = $value.Str;
        return;
    };
}

our sub min_length([$min-length], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'TOO_SHORT' if $value.chars < $min-length;
        
        $output = $value.Str;
        return;
    };
}

our sub length_equal([$length], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'TOO_SHORT' if $value.chars < $length;
        return 'TOO_LONG'  if $value.chars > $length;
        
        $output = $value.Str;
        return;
    };
}

our sub length_between([$min-length, $max-length], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'TOO_SHORT' if $value.chars < $min-length;
        return 'TOO_LONG'  if $value.chars > $max-length;
        
        $output = $value.Str;
        return;
    };
}

our sub like([$re, $flags = ''], $builders) {
    my $is-ignore-case = $flags.match('i');
    
    # my $flagged-re = do {
    #     my $m = $re;
    #     $is-ignore-case ?? rx:P5:i/( <$m> )/ !! rx:P5/( <$m> )/;
    # };

    # dd $flagged-re;
    my $flagged-re = $is-ignore-case ?? rx:i:P5/$re/ !! rx:P5/$re/;
    dd $flagged-re;
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'WRONG_FORMAT' unless $value.match($flagged-re);
        
        $output = $value.Str;
        return;
    };
}

our sub string([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;
        
        $output = $value.Str;
        return;
    };
}

our sub equal([$allowed-value], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;
        

        if $value eq $allowed-value {
            $output = $allowed-value;
            return;
        }
        
        return 'NOT_ALLOWED_VALUE';
    };
}
