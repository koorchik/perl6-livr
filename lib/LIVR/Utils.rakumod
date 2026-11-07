unit module LIVR::Utils;

our sub is-no-value($value --> Bool:D) is export {
    return False if $value ~~ Array;
    return False if $value ~~ Hash;
    return !$value.defined || $value eq '' 
}

my $number-re = rx/^ '-'? \d+ [ '.' \d* ]? $/;

our sub looks-like-number($value --> Bool:D) is export {
    return True if $value.WHAT =:= Int;
    return so $value ~~ $number-re;
}

# LIVR 2.5 helpers, exported with the :internal tag for the rule modules

# A primitive value: a string, a number or a boolean (a Bool is an Int in Raku)
our sub is-primitive($value --> Bool:D) is export(:internal) {
    $value.defined && ($value ~~ Str || $value ~~ Real)
}

# An empty value: a missing field, null or "". Lists and objects are never empty values
our sub is-empty($value --> Bool:D) is export(:internal) {
    !$value.defined || ($value ~~ Str && $value eq '')
}

# The shortest form of a double as Raku writes it, "1.5e-07", without the exponent
my $exponent-re = rx/^ ('-'?) (<[0..9]>+) [ '.' (<[0..9]>+) ]? 'e' (<[+-]> <[0..9]>+) $/;

sub num-string(Num $num --> Str:D) {
    my $str = $num.Str;
    return $str unless $str.contains('e');

    my $m = $str.match($exponent-re) or return $str;
    my $digits = $m[1] ~ ($m[2] // '');
    my $point = $m[1].chars + $m[3].Int;

    return $m[0] ~ '0.' ~ ('0' x -$point) ~ $digits if $point <= 0;
    return $m[0] ~ $digits ~ ('0' x ($point - $digits.chars)) if $point >= $digits.chars;
    return $m[0] ~ $digits.substr(0, $point) ~ '.' ~ $digits.substr($point);
}

# The string form of a primitive value (LIVR 2.5, section 2.2): a string as it is, a boolean
# is "true" or "false", an integral number has no decimal point (1.0 is "1", -0.0 is "0"), any
# other number is the shortest decimal that reads back as the same double, without an exponent
our sub string-form($value --> Str:D) is export(:internal) {
    return $value if $value ~~ Str;
    return $value ?? 'true' !! 'false' if $value ~~ Bool;
    return $value.Str if $value ~~ Int;
    return $value.numerator.Str if $value ~~ Rational && $value.denominator == 1;

    my $num = $value.Num;
    return $num.Str if $num.isNaN || $num == Inf || $num == -Inf;
    return $num.Int.Str if $num == $num.floor;
    return num-string($num);
}

# The error of a format or checksum rule for a defined value that is neither a string nor a
# number: a boolean gets the code of the rule (true is not a hostname), an object or a list
# gets FORMAT_ERROR
our sub format-error($value, Str $code --> Str:D) is export(:internal) {
    $value ~~ Bool ?? $code !! 'FORMAT_ERROR'
}

# LIVR 2.5 rules without arguments reject arguments. { rule => Any } (null) is one argument
our sub no-arguments(Str $rule-name, @args) is export(:internal) {
    die "LIVR: rule [$rule-name] takes no arguments\n" if @args;
}

# Numbers and strings are interchangeable in arguments (LIVR 2.5, section 2.6). A number
# argument is a number or a string with a number in the grammar of "decimal": "2" is 2. Nil for
# anything else, a boolean among them
my $number-argument-re = rx/^ '-'? <[0..9]>+ [ '.' <[0..9]>+ ]? $/;

our sub number-argument($argument) is export(:internal) {
    return Nil if !$argument.defined || $argument ~~ Bool;
    return $argument if $argument ~~ Real;
    return $argument.Numeric if $argument ~~ Str && $argument ~~ $number-argument-re;
    return Nil;
}

# An integer argument: a number argument without a fractional part, as an Int
our sub integer-argument($argument) is export(:internal) {
    my $number = number-argument($argument) // return Nil;
    return $number == $number.floor ?? $number.Int !! Nil;
}

# A string argument: a string, or a number in its string form: 1 is "1". Nil for anything else
our sub string-argument($argument) is export(:internal) {
    return Nil if !$argument.defined || $argument ~~ Bool;
    return $argument if $argument ~~ Str;
    return string-form($argument) if $argument ~~ Real;
    return Nil;
}

# A reference of "required_if" or "when" (LIVR 2.5, section 2.5): "a/b/0", "~1" stands for "/"
# and "~0" for "~". Parsed when the rule is built into a list of [key, index]: the index is an
# Int when the segment can be a list index ("0" or a number without leading zeros)
my $index-re = rx/^ [ '0' | <[1..9]> <[0..9]>* ] $/;
my $wrong-escape-re = rx/ '~' [ <-[01]> | $ ] /;

our sub parse-reference($reference, Str $rule-name) is export(:internal) {
    die "LIVR: a reference of [$rule-name] must be a non-empty string\n"
        unless $reference ~~ Str:D && $reference ne '';
    die "LIVR: the reference [$reference] of [$rule-name] starts with \"/\", which is reserved for references from the root\n"
        if $reference.starts-with('/');

    my @path;
    for $reference.split('/') -> $segment is copy {
        die "LIVR: the reference [$reference] of [$rule-name] has an empty segment\n" if $segment eq '';

        if $segment.contains('~') {
            die "LIVR: the reference [$reference] of [$rule-name] has a wrong escape\n"
                if $segment ~~ $wrong-escape-re;
            $segment = $segment.subst('~1', '/', :g).subst('~0', '~', :g);
        }

        @path.push: [$segment, ($segment ~~ $index-re ?? $segment.Int !! Nil)];
    }

    return @path;
}

# The input value at a parsed reference from the containing object, Nil when a segment is
# missing or a value on the way is not an object (or a list for an index segment)
our sub resolve-reference($data, @path) is export(:internal) {
    my $value = $data;

    for @path -> @segment {
        if $value ~~ Associative:D {
            return Nil unless $value{@segment[0]}:exists;
            $value = $value{@segment[0]};
        }
        elsif $value ~~ Positional:D {
            my $index = @segment[1];
            return Nil unless $index.defined && $index < $value.elems;
            $value = $value[$index];
        }
        else {
            return Nil;
        }
    }

    return $value;
}
