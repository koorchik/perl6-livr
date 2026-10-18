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
