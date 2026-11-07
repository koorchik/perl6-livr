unit module LIVR::Rules::List;
use LIVR::Utils :DEFAULT, :internal;

# A length: a non-negative integer, or a string with one. Nil otherwise
sub length-of($value) {
    my $length = integer-argument($value);
    return $length.defined && $length >= 0 ?? $length !! Nil;
}

#   { list_length => 2 }, { list_length => [1, 10] } or { list_length => { min => 1, max => 10 } }.
#   An object first is the options form, otherwise two or more arguments are min and max. The
#   arguments after them are ignored
our sub list_length(@args, %builders) {
    my ($min, $max);

    if @args[0] ~~ Hash {
        my $options = @args[0];

        for $options.keys -> $key {
            die "LIVR: rule [list_length] got an unknown option [$key]\n" unless $key eq 'min' || $key eq 'max';
        }

        $min = ($options<min>:exists) ?? length-of($options<min>) !! 0;
        $max = ($options<max>:exists) ?? length-of($options<max>) !! Inf;

        die "LIVR: rule [list_length] takes non-negative integers as \"min\" and \"max\"\n"
            unless $options.elems && $min.defined && $max.defined;
    }
    elsif @args >= 2 {
        ($min, $max) = length-of(@args[0]), length-of(@args[1]);
        die "LIVR: rule [list_length] takes non-negative integers as min and max\n" unless $min.defined && $max.defined;
    }
    else {
        $min = $max = length-of(@args[0]);
        die "LIVR: rule [list_length] takes a length, min and max, or an object with \"min\" and \"max\"\n"
            unless $min.defined;
    }

    die "LIVR: rule [list_length] got \"min\" greater than \"max\"\n" if $min > $max;

    return sub ($list, $all-values, $output is rw) {
        # An empty list is a value: { min => 1 } rejects it
        return if is-empty($list);
        return 'FORMAT_ERROR' unless $list ~~ Array;

        return 'TOO_FEW_ITEMS' if $list.elems < $min;
        return 'TOO_MANY_ITEMS' if $list.elems > $max;
        return;
    };
}

#   "unique": primitive items, { unique => 'id' } or { unique => ['country', 'zip'] }: objects
#   with unique values of the keys. Values are compared by their string forms, so 1 and "1" are
#   duplicates. A wrong type gives FORMAT_ERROR wherever it is in the list
our sub livr_unique(@keys, %builders) {
    # A number is its string form
    my @key-names = @keys.map(&string-argument);
    die "LIVR: rule [unique] takes key names as strings\n" unless @key-names.all.defined;

    unless @key-names {
        return sub ($list, $all-values, $output is rw) {
            return if is-empty($list);
            return 'FORMAT_ERROR' unless $list ~~ Array;

            my %seen;
            my $has-duplicates = False;

            for @$list -> $item {
                next if is-empty($item);
                return 'FORMAT_ERROR' unless is-primitive($item);

                my $string = string-form($item);
                if %seen{$string}:exists { $has-duplicates = True } else { %seen{$string} = True }
            }

            return 'NOT_UNIQUE_ITEMS' if $has-duplicates;
            return;
        };
    }

    return sub ($list, $all-values, $output is rw) {
        return if is-empty($list);
        return 'FORMAT_ERROR' unless $list ~~ Array;

        my %seen;
        my $has-duplicates = False;

        ITEM: for @$list -> $item {
            next if is-empty($item);
            return 'FORMAT_ERROR' unless $item ~~ Hash;

            # An item with an empty key value is not compared, a key value of a wrong type is an error
            my $has-empty-key-value = False;
            my $key = '';

            for @key-names -> $key-name {
                my $key-value = $item{$key-name};

                if is-empty($key-value) {
                    $has-empty-key-value = True;
                } elsif !is-primitive($key-value) {
                    return 'FORMAT_ERROR';
                } else {
                    # With lengths, so ["a,b"] and ["a", "b"] differ
                    my $string = string-form($key-value);
                    $key ~= $string.chars ~ ':' ~ $string;
                }
            }

            next ITEM if $has-empty-key-value;
            if %seen{$key}:exists { $has-duplicates = True } else { %seen{$key} = True }
        }

        return 'NOT_UNIQUE_ITEMS' if $has-duplicates;
        return;
    };
}
