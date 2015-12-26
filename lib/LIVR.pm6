unit package LIVR;

use LIVR::Validator;
use LIVR::Rules::Common;
use LIVR::Rules::Numeric;

my %DEFAULT_RULES = (
    required       => &LIVR::Rules::Common::required,
    not_empty      => &LIVR::Rules::Common::not_empty,
    not_empty_list => &LIVR::Rules::Common::not_empty_list
);

LIVR::Validator.register-default-rules(%DEFAULT_RULES);
