unit module LIVR::Rules::String;
use LIVR::Utils;
use LIVR::Regex;

our sub one_of(@args is copy, %builders) {
    my @allowed-values;
    if (@args[0] ~~ Array) {
        @allowed-values = |@args[0];
    } else {
        @allowed-values = @args;
    }

    return sub ($value, %all-values, $output is rw) {
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


our sub max_length([Int $max-length], %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'TOO_LONG' if $value.chars > $max-length;
        
        $output = $value.Str;
        return;
    };
}

our sub min_length([Int $min-length], %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'TOO_SHORT' if $value.chars < $min-length;
        
        $output = $value.Str;
        return;
    };
}

our sub length_equal([Int $length], %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'TOO_SHORT' if $value.chars < $length;
        return 'TOO_LONG'  if $value.chars > $length;
        
        $output = $value.Str;
        return;
    };
}

our sub length_between([Int $min-length, $max-length], %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'TOO_SHORT' if $value.chars < $min-length;
        return 'TOO_LONG'  if $value.chars > $max-length;
        
        $output = $value.Str;
        return;
    };
}

# Compiling a regex takes milliseconds, so the regexes of "like" rules are compiled once
my %LIKE-REGEXES;
my $LIKE-REGEXES-LOCK = Lock.new;

sub compile-like-regex(Str $re, Bool $is-ignore-case --> Regex) {
    my $key = ($is-ignore-case ?? 'i/' !! '/') ~ $re;

    return $LIKE-REGEXES-LOCK.protect: {
        %LIKE-REGEXES = () if %LIKE-REGEXES.elems >= 1000;

        %LIKE-REGEXES{$key} //= do {
            my $raku-re = translate-regex($re);
            my $flagged-re = $is-ignore-case ?? rx:i/<$raku-re>/ !! rx/<$raku-re>/;

            # The interpolated regex is compiled on the first match. Match now, so that
            # a wrong regex fails when the rule is built, not on validation.
            '' ~~ $flagged-re;
            $flagged-re;
        }
    };
}

our sub like([$re, $flags = ''], %builders) {
    my $flagged-re;

    if $re ~~ Regex {
        # By livr-spec we expect  regex string (compatible cross languages). 
        # But if you want to use perl6 Regex than it will work too. 
        $flagged-re = $re;
    } else {
        $flagged-re = compile-like-regex(~$re, so $flags.match('i'));
    }

    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'WRONG_FORMAT' unless $value.match($flagged-re);
        
        $output = $value.Str;
        return;
    };
}

our sub string([], %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;
        
        $output = $value.Str;
        return;
    };
}

our sub equal([Cool $allowed-value], %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;
        

        if $value eq $allowed-value {
            $output = $allowed-value;
            return;
        }
        
        return 'NOT_ALLOWED_VALUE';
    };
}
