unit module LIVR::Rules::Format;
use LIVR::Utils :DEFAULT, :internal;

# Format rules check the string form of a value and output it. A boolean gets the error code
# of the rule (true is not a hostname, "true" is), an object or a list FORMAT_ERROR.
# $check is a regex or a code block that takes the string.
sub format-rule(Str $error-code, $check) {
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

        return $error-code unless $string ~~ $check;

        $output = $string;
        return;
    };
}

# The versions of uuid, ip and cidr are strings: "v4"
sub versions(Str $rule-name, @args, @allowed) {
    for @args -> $version {
        die "LIVR: rule [$rule-name] takes versions {@allowed.map({ "\"$_\"" }).join(', ')}, got {$version.raku}\n"
            unless $version ~~ Str:D && $version eq @allowed.any;
    }

    return @args.map(*.Str);
}

# RFC 9562. The version digit (the first of the third group) is 1-8, the variant digit (the
# first of the fourth group) is 8, 9, a or b
my $uuid-re = rx/^
    <[0..9a..fA..F]> ** 8 '-' <[0..9a..fA..F]> ** 4 '-' <[1..8]> <[0..9a..fA..F]> ** 3 '-'
    <[89abAB]> <[0..9a..fA..F]> ** 3 '-' <[0..9a..fA..F]> ** 12
$/;

# The nil and the max UUID have no version and variant
my $nil-or-max-uuid-re = rx/^ [
    '00000000-0000-0000-0000-000000000000'
    || <[fF]> ** 8 '-' <[fF]> ** 4 '-' <[fF]> ** 4 '-' <[fF]> ** 4 '-' <[fF]> ** 12
] $/;

our sub uuid(@args, %builders) {
    return format-rule('WRONG_UUID', -> $string { $string ~~ $uuid-re || $string ~~ $nil-or-max-uuid-re })
        unless @args;

    my %versions = versions('uuid', @args, (1..8).map({ "v$_" })).map({ .substr(1) => True });

    return format-rule('WRONG_UUID', -> $string { $string ~~ $uuid-re && %versions{$string.substr(14, 1)} });
}

# Four numbers 0-255 without leading zeros: some systems read "010" as octal
my $ipv4-re = rx/^
    [ '25' <[0..5]> || '2' <[0..4]> <[0..9]> || '1' <[0..9]> ** 2 || <[1..9]> <[0..9]> || <[0..9]> ] ** 4 % '.'
$/;

my $hex-group-re = rx/^ <[0..9a..fA..F]> ** 1..4 $/;

# The number of 16-bit groups of a part of an IPv6 address: hex groups separated by ":", the
# last one may be an IPv4 address (two groups) at the end of the address. -1 for a wrong group
sub count-groups(Str $part, Bool $is-address-end --> Int:D) {
    return 0 if $part eq '';

    my @groups = $part.split(':');
    my $count = 0;

    for @groups.kv -> $index, $group {
        if $group ~~ $hex-group-re {
            $count++;
        } elsif $is-address-end && $index == @groups.end && $group ~~ $ipv4-re {
            $count += 2;
        } else {
            return -1;
        }
    }

    return $count;
}

# RFC 4291, section 2.2: eight groups, or fewer with one "::" for one or more groups of zeros
sub is-ipv6(Str $string --> Bool:D) {
    my $gap-index = $string.index('::');
    return count-groups($string, True) == 8 without $gap-index;

    # A second "::" (":::" too) is ambiguous
    return False if $string.index('::', $gap-index + 1).defined;

    my $before = count-groups($string.substr(0, $gap-index), False);
    my $after = count-groups($string.substr($gap-index + 2), True);
    return $before >= 0 && $after >= 0 && $before + $after <= 7;
}

# The arguments after the version are ignored
sub ip-version(Str $rule-name, @args) {
    return @args ?? versions($rule-name, @args[0,], <v4 v6>)[0] !! '';
}

our sub ip(@args, %builders) {
    given ip-version('ip', @args) {
        when 'v4' { return format-rule('WRONG_IP', $ipv4-re) }
        when 'v6' { return format-rule('WRONG_IP', &is-ipv6) }
        default   { return format-rule('WRONG_IP', -> $string { $string ~~ $ipv4-re || is-ipv6($string) }) }
    }
}

# A prefix length: decimal without leading zeros
my $prefix-length-re = rx/^ [ '0' || <[1..9]> <[0..9]> ** 0..2 ] $/;

our sub cidr(@args, %builders) {
    my $version = ip-version('cidr', @args);

    # Host bits may be set: "10.0.0.1/8" passes
    return format-rule('WRONG_CIDR', -> $string {
        my $slash-index = $string.index('/');
        my $address = $slash-index.defined ?? $string.substr(0, $slash-index) !! '';
        my $prefix-length = $slash-index.defined ?? $string.substr($slash-index + 1) !! '';

        my $max-prefix-length = $version ne 'v6' && $address ~~ $ipv4-re ?? 32
            !! $version ne 'v4' && is-ipv6($address) ?? 128
            !! -1;

        $max-prefix-length >= 0 && $prefix-length ~~ $prefix-length-re && $prefix-length.Int <= $max-prefix-length;
    });
}

# RFC 1123 labels of 1-63 characters, not starting or ending with "-", no trailing dot
my $hostname-re = rx/^
    <[a..zA..Z0..9]> [ <[a..zA..Z0..9\-]> ** 0..61 <[a..zA..Z0..9]> ]?
    [ '.' <[a..zA..Z0..9]> [ <[a..zA..Z0..9\-]> ** 0..61 <[a..zA..Z0..9]> ]? ]*
$/;

my $digits-re = rx/^ <[0..9]>+ $/;

our sub hostname(@args, %builders) {
    no-arguments('hostname', @args);

    # Labels may be all digits, except the last one (RFC 1123, section 2.1): "192.0.2.1" and
    # "123" are not hostnames
    return format-rule('WRONG_HOSTNAME', -> $string {
        $string.chars <= 253 && $string ~~ $hostname-re
            && $string.substr(($string.rindex('.') // -1) + 1) !~~ $digits-re
    });
}

# RFC 4648. Groups of 4 characters, the padding "=" or "==" only at the end. The unused bits of
# the last character are not checked
my $base64-re = rx/^
    [ <[A..Za..z0..9+/]> ** 4 ]*
    [ <[A..Za..z0..9+/]> ** 2 '==' || <[A..Za..z0..9+/]> ** 3 '=' ]?
$/;

# The URL-safe alphabet, the padding is optional: complete or absent
my $base64-url-re = rx/^
    [ <[A..Za..z0..9_\-]> ** 4 ]*
    [ <[A..Za..z0..9_\-]> ** 2 [ '==' ]? || <[A..Za..z0..9_\-]> ** 3 '='? ]?
$/;

our sub base64(@args, %builders) {
    return format-rule('WRONG_BASE64', $base64-re) unless @args;

    die "LIVR: rule [base64] takes no arguments or \"url\"\n" unless @args[0] ~~ Str:D && @args[0] eq 'url';
    return format-rule('WRONG_BASE64', $base64-url-re);
}

my $hex-re = rx/^ <[0..9a..fA..F]>+ $/;

our sub hex(@args, %builders) {
    no-arguments('hex', @args);
    return format-rule('WRONG_HEX', $hex-re);
}

my %DIGEST-LENGTHS = md5 => 32, sha1 => 40, sha256 => 64, sha384 => 96, sha512 => 128;

our sub digest(@args, %builders) {
    die "LIVR: rule [digest] needs one or more algorithms: md5, sha1, sha256, sha384, sha512\n" unless @args;

    my %lengths;
    for @args -> $algorithm {
        die "LIVR: rule [digest] got an unknown algorithm {$algorithm.raku}\n"
            unless $algorithm ~~ Str:D && (%DIGEST-LENGTHS{$algorithm}:exists);
        %lengths{%DIGEST-LENGTHS{$algorithm}} = True;
    }

    return format-rule('WRONG_DIGEST', -> $string { %lengths{$string.chars} && $string ~~ $hex-re });
}

my $mongo-id-re = rx/^ <[0..9a..fA..F]> ** 24 $/;

our sub mongo_id(@args, %builders) {
    no-arguments('mongo_id', @args);
    return format-rule('WRONG_MONGO_ID', $mongo-id-re);
}

# #RGB, #RGBA, #RRGGBB or #RRGGBBAA
my $hex-color-re = rx/^ '#' [ <[0..9a..fA..F]> ** 8 || <[0..9a..fA..F]> ** 6 || <[0..9a..fA..F]> ** 3..4 ] $/;

our sub hex_color(@args, %builders) {
    no-arguments('hex_color', @args);
    return format-rule('WRONG_HEX_COLOR', $hex-color-re);
}

# Hex pairs separated by ":" or by "-", the same separator everywhere. 48 bits are six pairs
# (MAC-48, EUI-48), 64 bits are eight pairs (EUI-64)
my $mac48-re = rx/^ [
    <[0..9a..fA..F]> ** 2 [ ':' <[0..9a..fA..F]> ** 2 ] ** 5
    || <[0..9a..fA..F]> ** 2 [ '-' <[0..9a..fA..F]> ** 2 ] ** 5
] $/;

my $mac64-re = rx/^ [
    <[0..9a..fA..F]> ** 2 [ ':' <[0..9a..fA..F]> ** 2 ] ** 7
    || <[0..9a..fA..F]> ** 2 [ '-' <[0..9a..fA..F]> ** 2 ] ** 7
] $/;

our sub mac(@args, %builders) {
    return format-rule('WRONG_MAC', $mac48-re) unless @args;

    # A string with the number is the number: "64" is 64
    my $bits = number-argument(@args[0]);
    die "LIVR: rule [mac] takes no arguments, 48 or 64\n" unless $bits.defined && ($bits == 48 || $bits == 64);
    return format-rule('WRONG_MAC', $bits == 64 ?? $mac64-re !! $mac48-re);
}

# "+", then 7-15 digits, the first is not 0
my $e164-re = rx/^ '+' <[1..9]> <[0..9]> ** 6..14 $/;

our sub e164(@args, %builders) {
    no-arguments('e164', @args);
    return format-rule('WRONG_E164', $e164-re);
}

# The grammar of semver.org 2.0.0 with ASCII classes
my $semver-re = rx/^
    [ '0' || <[1..9]> <[0..9]>* ] '.' [ '0' || <[1..9]> <[0..9]>* ] '.' [ '0' || <[1..9]> <[0..9]>* ]
    [ '-' [ <[0..9]>* <[a..zA..Z\-]> <[0..9a..zA..Z\-]>* || '0' || <[1..9]> <[0..9]>* ]
      [ '.' [ <[0..9]>* <[a..zA..Z\-]> <[0..9a..zA..Z\-]>* || '0' || <[1..9]> <[0..9]>* ] ]* ]?
    [ '+' <[0..9a..zA..Z\-]>+ [ '.' <[0..9a..zA..Z\-]>+ ]* ]?
$/;

our sub semver(@args, %builders) {
    no-arguments('semver', @args);
    return format-rule('WRONG_SEMVER', $semver-re);
}

# The JWS compact serialization: header.payload.signature in base64url without padding, the
# signature is empty in an unsecured JWT. No segment has a length of 1 modulo 4, as no bytes
# give such a base64url length. The segments are not decoded
my $jwt-re = rx/^ <[A..Za..z0..9_\-]>+ '.' <[A..Za..z0..9_\-]>+ '.' <[A..Za..z0..9_\-]>* $/;

our sub jwt(@args, %builders) {
    no-arguments('jwt', @args);

    return format-rule('WRONG_JWT', -> $string {
        $string ~~ $jwt-re && !$string.split('.').first(*.chars % 4 == 1);
    });
}
