unit module LIVR::Rules::String;
use LIVR::Utils :DEFAULT, :internal;
use LIVR::Regex;

# one_of and eq compare a boolean as a string (LIVR 2.5, section 2.3): true equals "true". They
# keep the LIVR 2.0 comparison too, of Raku strings, where true is "True": so true equals "True"
# and "true", and false equals "False" and "false". Other values are compared as in LIVR 2.0
sub comparable($value) {
    $value ~~ Bool ?? string-form($value) !! $value
}

our sub one_of(@args is copy, %builders) {
    my @allowed-values;
    if (@args[0] ~~ Array) {
        @allowed-values = |@args[0];
    } else {
        @allowed-values = @args;
    }

    my @comparable-values = @allowed-values.map(&comparable);
    my $has-bool = so @allowed-values.grep(Bool);
    my int $count = @allowed-values.elems;

    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        my $is-bool = $value ~~ Bool;
        my $comparable-value = $is-bool ?? string-form($value) !! $value;
        loop (my int $i = 0; $i < $count; $i++) {
            if $comparable-value eq @comparable-values[$i] {
                $output = @allowed-values[$i];
                return;
            }
        }

        # The LIVR 2.0 comparison: "True" equals true
        if $is-bool || $has-bool {
            loop (my int $i = 0; $i < $count; $i++) {
                if $value eq @allowed-values[$i] {
                    $output = @allowed-values[$i];
                    return;
                }
            }
        }

        return 'NOT_ALLOWED_VALUE';
    }
}


# The LIVR 2.0 rules ignore extra arguments

our sub max_length([Int $max-length, *@], %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'TOO_LONG' if $value.chars > $max-length;
        
        $output = $value.Str;
        return;
    };
}

our sub min_length([Int $min-length, *@], %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'TOO_SHORT' if $value.chars < $min-length;
        
        $output = $value.Str;
        return;
    };
}

our sub length_equal([Int $length, *@], %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        return 'TOO_SHORT' if $value.chars < $length;
        return 'TOO_LONG'  if $value.chars > $length;
        
        $output = $value.Str;
        return;
    };
}

our sub length_between([Int $min-length, $max-length, *@], %builders) {
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

our sub like([$re, $flags = '', *@], %builders) {
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

our sub string(@, %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;
        
        $output = $value.Str;
        return;
    };
}

our sub equal([Cool $allowed-value, *@], %builders) {
    my $comparable-allowed-value = comparable($allowed-value);
    my $is-bool-allowed = $allowed-value ~~ Bool;

    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' if $value !~~ Str && $value !~~ Numeric;

        my $is-bool = $value ~~ Bool;
        # The LIVR 2.5 comparison, then the LIVR 2.0 one: "True" equals true
        if ($is-bool ?? string-form($value) !! $value) eq $comparable-allowed-value
            || ($is-bool || $is-bool-allowed) && $value eq $allowed-value {
            $output = $allowed-value;
            return;
        }
        
        return 'NOT_ALLOWED_VALUE';
    };
}


# LIVR 2.5

our sub not_one_of(@args, %builders) {
    die "LIVR: rule [not_one_of] takes one or more strings, numbers or booleans\n"
        unless @args && @args.all ~~ &is-primitive;

    # The forbidden values as strings, so 1 matches "1" and true matches "true"
    my %forbidden-values = @args.map({ string-form($_) => True });

    return sub ($value, $all-values, $output is rw) {
        return if is-empty($value);
        return 'FORMAT_ERROR' unless is-primitive($value);

        return 'NOT_ALLOWED_VALUE' if %forbidden-values{string-form($value)};
        return;
    };
}

my $digits-re = rx/^ <[0..9]>+ $/;

our sub digits(@args, %builders) {
    no-arguments('digits', @args);

    # The output is a string with the leading zeros: "007" stays "007", 7 becomes "7"
    return sub ($value, $all-values, $output is rw) {
        return unless $value.defined;

        if $value ~~ Str {
            return if $value eq '';
            return 'NOT_DIGITS' unless $value ~~ $digits-re;
            return;
        }

        return 'NOT_DIGITS' if $value ~~ Bool;
        return 'FORMAT_ERROR' unless $value ~~ Real;

        my $string = string-form($value);
        return 'NOT_DIGITS' unless $string ~~ $digits-re;

        $output = $string;
        return;
    };
}

# The string form must start with, end with or contain one of the strings, case-sensitive
sub build-substring-rule(Str $rule-name, @strings, &is-match) {
    # A number is its string form: { starts_with => 1 } is "1"
    my @substrings = @strings.map(&string-argument);
    die "LIVR: rule [$rule-name] takes one or more non-empty strings\n"
        unless @substrings && @substrings.all.defined && @substrings.none eq '';

    return sub ($value, $all-values, $output is rw) {
        return if is-empty($value);
        return 'FORMAT_ERROR' unless is-primitive($value);

        my $string = string-form($value);
        for @substrings -> $substring {
            if is-match($string, $substring) {
                $output = $string;
                return;
            }
        }

        return 'WRONG_FORMAT';
    };
}

our sub starts_with(@args, %builders) {
    build-substring-rule('starts_with', @args, -> $string, $substring { $string.starts-with($substring) });
}

our sub ends_with(@args, %builders) {
    build-substring-rule('ends_with', @args, -> $string, $substring { $string.ends-with($substring) });
}

our sub contains(@args, %builders) {
    build-substring-rule('contains', @args, -> $string, $substring { $string.contains($substring) });
}
