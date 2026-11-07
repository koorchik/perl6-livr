unit module LIVR::Rules::Checksum;
use LIVR::Utils :DEFAULT, :internal;

# The string form is checked as it is: no spaces, dashes or lowercase letters are removed.
# A boolean gets the error code of the rule, an object or a list FORMAT_ERROR.
sub checksum-rule(Str $error-code, &is-valid) {
    return sub ($value, $all-values, $output is rw) {
        return unless $value.defined;

        my $string;
        if $value ~~ Str {
            return if $value eq '';
            $string = $value;
        } elsif $value ~~ Real && $value !~~ Bool {
            $string = string-form($value);
        } else {
            return format-error($value, $error-code);
        }

        return $error-code unless is-valid($string);

        $output = $string;
        return;
    };
}

# Luhn mod 10: every second digit from the right is doubled (minus 9 when above 9)
sub has-luhn-checksum(Str $digits --> Bool:D) {
    my $sum = 0;
    my $is-doubled = False;

    for $digits.ords.reverse -> $code {
        my $digit = $code - 48;
        if $is-doubled {
            $digit *= 2;
            $digit -= 9 if $digit > 9;
        }
        $sum += $digit;
        $is-doubled = !$is-doubled;
    }

    return $sum %% 10;
}

my $luhn-re = rx/^ <[0..9]> ** 2..* $/;
my $card-number-re = rx/^ <[0..9]> ** 12..19 $/;

our sub luhn(@args, %builders) {
    no-arguments('luhn', @args);
    return checksum-rule('WRONG_CHECKSUM', -> $string { $string ~~ $luhn-re && has-luhn-checksum($string) });
}

# ISO/IEC 7812 card numbers have 12-19 digits. No card network detection
our sub credit_card(@args, %builders) {
    no-arguments('credit_card', @args);
    return checksum-rule('WRONG_CREDIT_CARD_NUMBER', -> $string { $string ~~ $card-number-re && has-luhn-checksum($string) });
}

# ISO 13616: a country code, two check digits, 11-30 characters. No per-country length table
my $iban-re = rx/^ <[A..Z]> ** 2 <[0..9]> ** 2 <[A..Z0..9]> ** 11..30 $/;

# The first four characters moved to the end, letters replaced by two digits (A = 10 ... Z = 35):
# the number modulo 97 is 1. Computed a character at a time
sub has-iban-checksum(Str $iban --> Bool:D) {
    my @codes = $iban.ords;
    my $length = @codes.elems;
    my $remainder = 0;

    for ^$length -> $i {
        my $code = @codes[($i + 4) % $length];
        $remainder = $code <= 57
            ?? ($remainder * 10 + $code - 48) % 97
            !! ($remainder * 100 + $code - 55) % 97;
    }

    return $remainder == 1;
}

our sub iban(@args, %builders) {
    no-arguments('iban', @args);
    return checksum-rule('WRONG_IBAN', -> $string { $string ~~ $iban-re && has-iban-checksum($string) });
}
