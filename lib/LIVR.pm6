unit package LIVR;

use LIVR::Validator;
use LIVR::Rules::Common;
use LIVR::Rules::Numeric;
use LIVR::Rules::String;
use LIVR::Rules::Special;
use LIVR::Rules::Meta;

my %DEFAULT_RULES = (
    required         => &LIVR::Rules::Common::required,
    not_empty        => &LIVR::Rules::Common::not_empty,
    not_empty_list   => &LIVR::Rules::Common::not_empty_list,

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

    email            => &LIVR::Rules::Special::email,
    url              => &LIVR::Rules::Special::url,
    equal_to_field   => &LIVR::Rules::Special::equal_to_field,

    nested_object    => &LIVR::Rules::Meta::nested_object,
    list_of          => &LIVR::Rules::Meta::list_of,
    list_of_objects  => &LIVR::Rules::Meta::list_of_objects,
    list_of_different_objects  => &LIVR::Rules::Meta::list_of_different_objects,
);

LIVR::Validator.register-default-rules(%DEFAULT_RULES);
