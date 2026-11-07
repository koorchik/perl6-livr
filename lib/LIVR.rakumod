unit module LIVR;

use LIVR::Validator;
use LIVR::Rules::Common;
use LIVR::Rules::Numeric;
use LIVR::Rules::String;
use LIVR::Rules::Special;
use LIVR::Rules::Modifiers;
use LIVR::Rules::Meta;

# Rules of LIVR 2.5 in modules that are loaded on first use: a schema uses few of them, and
# loading them all would make "use LIVR" slower
sub lazy-rule(Str $module, Str $name) {
    my $rule-builder;

    return sub (@args, %builders) {
        $rule-builder //= do {
            require ::($module);
            ::("&{$module}::{$name}");
        };

        return $rule-builder(@args, %builders);
    };
}

my %DEFAULT_RULES = (
    required         => &LIVR::Rules::Common::required,
    not_empty        => &LIVR::Rules::Common::not_empty,
    not_empty_list   => &LIVR::Rules::Common::not_empty_list,
    any_object       => &LIVR::Rules::Common::any_object,

    integer          => &LIVR::Rules::Numeric::integer,
    positive_integer => &LIVR::Rules::Numeric::positive_integer,
    decimal          => &LIVR::Rules::Numeric::decimal,
    positive_decimal => &LIVR::Rules::Numeric::positive_decimal,
    min_number       => &LIVR::Rules::Numeric::min_number,
    max_number       => &LIVR::Rules::Numeric::max_number,
    number_between   => &LIVR::Rules::Numeric::number_between,

    one_of           => &LIVR::Rules::String::one_of,
    min_length       => &LIVR::Rules::String::min_length,
    max_length       => &LIVR::Rules::String::max_length,
    length_between   => &LIVR::Rules::String::length_between,
    length_equal     => &LIVR::Rules::String::length_equal,
    like             => &LIVR::Rules::String::like,
    string           => &LIVR::Rules::String::string,
    eq               => &LIVR::Rules::String::equal,

    email            => &LIVR::Rules::Special::email,
    url              => &LIVR::Rules::Special::url,
    iso_date         => &LIVR::Rules::Special::iso_date,
    equal_to_field   => &LIVR::Rules::Special::equal_to_field,

    trim             => &LIVR::Rules::Modifiers::trim,
    to_lc            => &LIVR::Rules::Modifiers::to_lc,
    to_uc            => &LIVR::Rules::Modifiers::to_uc,
    remove           => &LIVR::Rules::Modifiers::remove,
    leave_only       => &LIVR::Rules::Modifiers::leave_only,
    default          => &LIVR::Rules::Modifiers::default,

    nested_object    => &LIVR::Rules::Meta::nested_object,
    variable_object  => &LIVR::Rules::Meta::variable_object,
    or               => &LIVR::Rules::Meta::livr_or,
    list_of          => &LIVR::Rules::Meta::list_of,
    list_of_objects  => &LIVR::Rules::Meta::list_of_objects,
    list_of_different_objects  => &LIVR::Rules::Meta::list_of_different_objects,

    # LIVR 2.5
    boolean          => &LIVR::Rules::Common::boolean,
    any              => &LIVR::Rules::Common::livr_any,
    required_if      => &LIVR::Rules::Common::required_if,

    not_one_of       => &LIVR::Rules::String::not_one_of,
    digits           => &LIVR::Rules::String::digits,
    starts_with      => &LIVR::Rules::String::starts_with,
    ends_with        => &LIVR::Rules::String::ends_with,
    contains         => &LIVR::Rules::String::contains,

    max_decimals     => &LIVR::Rules::Numeric::max_decimals,

    iso_datetime     => lazy-rule('LIVR::Rules::Dates', 'iso_datetime'),
    iso_time         => lazy-rule('LIVR::Rules::Dates', 'iso_time'),

    split            => &LIVR::Rules::Modifiers::livr_split,

    when             => &LIVR::Rules::Meta::livr_when,
    values           => &LIVR::Rules::Meta::livr_values,
    keys             => &LIVR::Rules::Meta::livr_keys,

    list_length      => lazy-rule('LIVR::Rules::List', 'list_length'),
    unique           => lazy-rule('LIVR::Rules::List', 'livr_unique'),

    uuid             => lazy-rule('LIVR::Rules::Format', 'uuid'),
    ip               => lazy-rule('LIVR::Rules::Format', 'ip'),
    cidr             => lazy-rule('LIVR::Rules::Format', 'cidr'),
    hostname         => lazy-rule('LIVR::Rules::Format', 'hostname'),
    base64           => lazy-rule('LIVR::Rules::Format', 'base64'),
    hex              => lazy-rule('LIVR::Rules::Format', 'hex'),
    digest           => lazy-rule('LIVR::Rules::Format', 'digest'),
    mongo_id         => lazy-rule('LIVR::Rules::Format', 'mongo_id'),
    hex_color        => lazy-rule('LIVR::Rules::Format', 'hex_color'),
    mac              => lazy-rule('LIVR::Rules::Format', 'mac'),
    e164             => lazy-rule('LIVR::Rules::Format', 'e164'),
    semver           => lazy-rule('LIVR::Rules::Format', 'semver'),
    jwt              => lazy-rule('LIVR::Rules::Format', 'jwt'),

    luhn             => lazy-rule('LIVR::Rules::Checksum', 'luhn'),
    credit_card      => lazy-rule('LIVR::Rules::Checksum', 'credit_card'),
    iban             => lazy-rule('LIVR::Rules::Checksum', 'iban'),
);

LIVR::Validator.register-default-rules(%DEFAULT_RULES);
