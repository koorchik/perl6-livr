unit module LIVR::Rules::Common;
use LIVR::Utils :DEFAULT, :internal;

our sub required(@, %builders) {
    return sub ($value, $all-values, $output is rw) {
        return 'REQUIRED' if is-no-value($value);
    };
}

our sub not_empty(@, %builders) {
    return sub ($value, $all-values, $output is rw) {
        if $value.defined {
            return if $value ~~ Hash;
            return if $value ~~ Array;
            return "CANNOT_BE_EMPTY" if $value.defined && $value eq '';
        }
        
        return;
    };
}

our sub not_empty_list(@, %builders) {
    return sub ($list, $all-values, $output is rw) {
        return 'CANNOT_BE_EMPTY' if !$list.defined || ($list ~~ Str && $list eq '');
        return 'FORMAT_ERROR' unless $list ~~ Array;
        return 'CANNOT_BE_EMPTY' unless $list.elems;
        return;
    }
}

our sub any_object(@, %builders) {
    return sub ($value, $all-values, $output is rw) {
        return if is-no-value($value);
        return 'FORMAT_ERROR' unless $value ~~ Hash;
        return;
    }
}

# LIVR 2.5

our sub boolean(@args, %builders) {
    no-arguments('boolean', @args);

    return sub ($value, $all-values, $output is rw) {
        return unless $value.defined;

        # A Bool is an Int in Raku, so it is checked first
        if $value ~~ Bool {
            $output = $value;
            return;
        }

        if $value ~~ Str {
            return if $value eq '';

            # Case-sensitive: "True" is not a boolean
            if $value eq '1' || $value eq 'true' {
                $output = True;
                return;
            }

            if $value eq '0' || $value eq 'false' {
                $output = False;
                return;
            }

            return 'NOT_BOOLEAN';
        }

        if $value ~~ Real {
            # 1.0 is 1
            if $value == 1 {
                $output = True;
                return;
            }

            if $value == 0 {
                $output = False;
                return;
            }

            return 'NOT_BOOLEAN';
        }

        return 'FORMAT_ERROR';
    };
}

# Any value passes, including objects, lists and empty values, and stays unchanged in the
# output. Unlike a field without rules, the value is kept
our sub livr_any(@args, %builders) {
    no-arguments('any', @args);

    return sub ($value, $all-values, $output is rw) {
        return;
    };
}

our sub required_if(@args, %builders) {
    my $conditions = @args[0];
    die "LIVR: rule [required_if] takes an object of references to values\n"
        unless $conditions ~~ Hash && $conditions.elems;

    # [path, the expected values as strings]: 1 matches "1" and true matches "true"
    my @conditions;
    for $conditions.kv -> $reference, $expected {
        my @path = parse-reference($reference, 'required_if');
        my @values = $expected ~~ Array ?? @$expected !! [$expected];

        # An empty list would never match
        die "LIVR: rule [required_if] takes a primitive value or a non-empty list of them for [$reference]\n"
            unless @values;

        for @values -> $value {
            # An empty referenced value never matches, so "" would never match too
            die "LIVR: rule [required_if] takes a primitive value other than \"\" or a list of them for [$reference]\n"
                unless is-primitive($value) && !($value ~~ Str && $value eq '');
        }

        @conditions.push: [@path, @values.map(&string-form).Set];
    }

    return sub ($value, $all-values, $output is rw) {
        return unless is-empty($value);

        # Required when every condition matches a primitive non-empty input value
        for @conditions -> @condition {
            my $referenced = resolve-reference($all-values, @condition[0]);
            return if is-empty($referenced) || !is-primitive($referenced);
            return unless @condition[1]{string-form($referenced)};
        }

        return 'REQUIRED';
    };
}
