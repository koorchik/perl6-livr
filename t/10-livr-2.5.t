use lib 'lib';

use Test;
use LIVR;

# The current date is read from the system clock with "time". Tests fix it by wrapping "time"
sub with-now(Str $time, &code) {
    my $posix = DateTime.new($time).posix;
    my $handle = &term:<time>.wrap({ $posix });
    LEAVE $handle.restore;

    code();
}

subtest 'Wrapping "time" fixes the current date' => sub {
    my $validator = LIVR::Validator.new(livr-rules => {
        date     => { iso_date => { max => 'today' } },
        datetime => { iso_datetime => { min => 'yesterday', max => 'tomorrow' } },
    });

    for '2026-10-18T12:00:00Z', '2026-10-18T23:30:00+05:00', '2026-10-18T00:00:00Z', '2026-10-18T23:59:59.999Z' -> $now {
        with-now $now, {
            is-deeply $validator.validate({ date => '2026-10-18', datetime => '2026-10-17T00:00:00Z' }),
                { date => '2026-10-18', datetime => '2026-10-17T00:00:00.000Z' }, "Should accept the bounds at $now";

            ok !$validator.validate({ date => '2026-10-19', datetime => '2026-10-20T00:00Z' }),
                "Should reject values after the bounds at $now";
            is-deeply $validator.errors, { date => 'DATE_TOO_LATE', datetime => 'DATETIME_TOO_LATE' }, 'Should return the errors';
        };
    }
};

subtest 'The clock is read for every check' => sub {
    my $validator = LIVR::Validator.new(livr-rules => { date => { iso_date => { min => 'today' } } }).prepare;

    with-now '2026-10-18T23:59:59Z', { ok $validator.validate({ date => '2026-10-18' }), 'Should accept the current date' };
    with-now '2026-10-19T00:00:00Z', { ok !$validator.validate({ date => '2026-10-18' }), 'Should reject it on the next day' };
};

subtest 'Without a wrapped "time" the current date in UTC is used' => sub {
    my $today = DateTime.now.utc.Date;
    my $validator = LIVR::Validator.new(livr-rules => { date => { iso_date => { min => 'today', max => 'today' } } });

    ok $validator.validate({ date => ~$today }) || $today ne DateTime.now.utc.Date, 'Should accept the current date';
    ok !$validator.validate({ date => ~($today + 2) }), 'Should reject another date';
};

subtest 'Meta rules and aliases use the same clock' => sub {
    LIVR::Validator.register-aliased-default-rule({ name => 'past_date_25', rules => { iso_date => { max => 'today' } } });

    my $validator = LIVR::Validator.new(livr-rules => {
        nested  => { nested_object => { date => { iso_date => { max => 'today' } } } },
        list    => { list_of => { iso_date => { max => 'today' } } },
        either  => { or => [ { iso_date => { max => 'today' } }, 'positive_integer' ] },
        branch  => { when => ['kind', { past => { iso_date => { max => 'today' } } }] },
        aliased => 'past_date_25',
        local   => 'local_past_date',
        kind    => 'string',
    });
    $validator.register-aliased-rule({ name => 'local_past_date', rules => { iso_date => { max => 'today' } } });

    my %input = nested => { date => '2026-10-19' }, list => ['2026-10-19'], either => '2026-10-19',
        branch => '2026-10-19', aliased => '2026-10-19', local => '2026-10-19', kind => 'past';

    with-now '2026-10-18T12:00:00Z', {
        ok !$validator.validate(%input), 'Should reject dates after the fixed date';
        is-deeply $validator.errors, {
            nested => { date => 'DATE_TOO_LATE' }, list => ['DATE_TOO_LATE'], either => 'NOT_POSITIVE_INTEGER',
            branch => 'DATE_TOO_LATE', aliased => 'DATE_TOO_LATE', local => 'DATE_TOO_LATE',
        }, 'Should return the errors of the nested rules';
    };

    with-now '2026-10-19T12:00:00Z', {
        ok $validator.validate(%input), 'Should accept them a day later';
    };
};

subtest 'LIVR 2.0 rules ignore extra arguments' => sub {
    LIVR::Validator.register-aliased-default-rule({ name => 'short_string_25', rules => ['string', { max_length => 3 }] });

    my %rules = (
        required       => { required => 1 },
        email          => { email => [1] },
        max_length     => { max_length => [5, 1] },
        length_between => { length_between => [1, 3, 'x'] },
        number_between => { number_between => [1, 10, 100] },
        one_of         => { one_of => ['a', 'b'] },
        like           => { like => ['^a', 'i', 'extra'] },
        remove         => { remove => ['-', 'x'] },
        default        => { default => ['x', 'y'] },
        eq             => { eq => ['a', 'b'] },
        equal          => { equal_to_field => ['eq', 'x'] },
        nested         => { nested_object => [{ value => 'short_string_25' }, 'x'] },
        objects        => { list_of_objects => [{ value => 'short_string_25' }, 'x'] },
        variable       => { variable_object => ['type', { a => { type => 'string', value => 'short_string_25' } }, 'x'] },
        different      => { list_of_different_objects => ['type', { a => { type => 'string', value => 'short_string_25' } }, 'x'] },
        aliased        => { short_string_25 => 1 },
        iso_date       => { iso_date => [{ max => '2026-12-31' }, 'x'] },
    );
    my %input = (
        required => 'x', email => 'user@example.com', max_length => 'abcde', length_between => 'abc',
        number_between => 10, one_of => 'b', like => 'Abc', remove => 'a-b', eq => 'a', equal => 'a',
        nested => { value => 'abc' }, objects => [{ value => 'abc' },], variable => { type => 'a', value => 'abc' },
        different => [{ type => 'a', value => 'abc' },], aliased => 'abc', iso_date => '2026-10-18',
    );

    my $validator = LIVR::Validator.new(livr-rules => %rules);
    is-deeply $validator.validate(%input), { %input, remove => 'ab', number_between => 10, default => 'x' },
        'Should build the rules and use the arguments they take';

    ok !$validator.validate({ %input, nested => { value => 'abcd' }, aliased => 'abcd' }), 'Should keep the custom rules of meta rules';
    is-deeply $validator.errors, { nested => { value => 'TOO_LONG' }, aliased => 'TOO_LONG' }, 'Should return their errors';
};

subtest 'eq and one_of compare booleans as strings' => sub {
    my $validator = LIVR::Validator.new(livr-rules => {
        eq-true => { eq => True }, one_of => { one_of => [True, 'x'] }, eq-string => { eq => 'true' },
    });

    ok $validator.validate({ eq-true => 'true', one_of => 'true', eq-string => True }), 'Should accept "true" for true and true for "true"';
    ok $validator.validate({ eq-true => True, one_of => True, eq-string => 'true' }), 'Should accept the same type';

    for '1', 'TRUE', 'yes', 1 -> $value {
        ok !$validator.validate({ eq-true => $value, one_of => $value }), "Should reject {$value.raku} for true";
        is-deeply $validator.errors, { eq-true => 'NOT_ALLOWED_VALUE', one_of => 'NOT_ALLOWED_VALUE' }, 'Should return NOT_ALLOWED_VALUE';
    }

    ok !$validator.validate({ eq-string => False }), 'Should reject false for "true"';
};

subtest 'eq and one_of keep accepting the LIVR 2.0 form of a boolean, "True" and "False"' => sub {
    my $validator = LIVR::Validator.new(livr-rules => {
        eq-true    => { eq => True },
        eq-false   => { eq => False },
        one_of     => { one_of => [True, False] },
        eq-string  => { eq => 'True' },
        one_of-str => { one_of => ['False', 'x'] },
        one_of-false => { one_of => [False, 'x'] },
    });

    my $output = $validator.validate({
        eq-true => 'True', eq-false => 'False', one_of => 'False', eq-string => True, one_of-str => False,
        one_of-false => 'False',
    });
    ok $output, 'Should accept "True" for true, "False" for false and the reverse';
    ok $output<eq-true> === True && $output<one_of> === False && $output<eq-string> eq 'True',
        'Should return the value of the rule, as in LIVR 2.0';

    ok $validator.validate({ eq-true => 'true', eq-false => 'false', one_of => 'false' }),
        'Should accept "true" and "false" too';

    ok !$validator.validate({ eq-true => 'False', eq-false => 'True', eq-string => False, one_of-str => True }),
        'Should reject the other boolean';
    is-deeply $validator.errors, {
        eq-true => 'NOT_ALLOWED_VALUE', eq-false => 'NOT_ALLOWED_VALUE',
        eq-string => 'NOT_ALLOWED_VALUE', one_of-str => 'NOT_ALLOWED_VALUE',
    }, 'Should return NOT_ALLOWED_VALUE';
};

subtest '{ rule => Any } (null) is one argument: a schema error for the LIVR 2.5 rules' => sub {
    for <boolean any unique uuid ip base64 hex mac iso_time iso_datetime hostname list_length split
         not_one_of starts_with max_decimals when values keys digest luhn> -> $rule {
        dies-ok { LIVR::Validator.new(livr-rules => { field => { $rule => Any } }).prepare },
            "Should reject \{ $rule => Any \}";
    }

    dies-ok { LIVR::Validator.new(livr-rules => { list => { not_one_of => [Any] } }).prepare },
        'Should reject null in a list of arguments';
    dies-ok { LIVR::Validator.new(livr-rules => { list => { list_length => { min => Any } } }).prepare },
        'Should reject null as a bound of list_length';
    dies-ok { LIVR::Validator.new(livr-rules => { date => { iso_date => [Any, { min => 'today' }] } }).prepare },
        'Should reject null before the options of iso_date';
};

subtest '{ iso_date => Any } (null) is the plain iso_date: LIVR 2.0 ignored its arguments' => sub {
    my $validator = LIVR::Validator.new(livr-rules => { date => { iso_date => Any } });
    ok $validator.validate({ date => '2024-02-29' }), 'Should build the rule';
    ok !$validator.validate({ date => '2024-02-30' }), 'Should check the value';
    is-deeply $validator.errors, { date => 'WRONG_DATE' }, 'Should return WRONG_DATE';
};

subtest 'The LIVR 2.0 rules and custom rules get Any (null) as their argument' => sub {
    my $validator = LIVR::Validator.new(livr-rules => { a => { default => Any }, b => { default => Any } });
    my $output = $validator.validate({ a => '' });
    ok $output, '{ default => Any } should build';
    ok ($output<a>:exists) && !$output<a>.defined, 'Should set an empty value to Any (null)';
    ok !($output<b>:exists), 'Should keep a missing field missing';

    my @got;
    LIVR::Validator.new(livr-rules => { a => { my_rule => Any } })
        .register-rules(%( my_rule => sub (@args, %builders) {
            @got = @args;
            return sub ($value, $all-values, $output is rw) { return };
        }))
        .prepare;
    ok @got == 1 && !@got[0].defined, 'A custom rule should get one argument, Any';
};

subtest 'Booleans in the output are real booleans' => sub {
    my $validator = LIVR::Validator.new(livr-rules => { a => 'boolean', b => 'boolean' });
    my $output = $validator.validate({ a => '1', b => 0 });

    ok $output<a> === True && $output<b> === False, 'Should return True and False';
};

subtest 'Validators keep their own rules' => sub {
    my $first = LIVR::Validator.new(livr-rules => { name => 'my_rule_25' });
    my $second = LIVR::Validator.new(livr-rules => { name => 'my_rule_25' });

    $first.get-rules<my_rule_25> = sub (@args, %builders) { sub ($value, $all-values, $output is rw) { return } };
    lives-ok { $first.prepare }, 'Should use the rule added through get-rules';
    dies-ok { $second.prepare }, 'Should not add it to other validators';

    my $validator = LIVR::Validator.new(livr-rules => { name => 'my_rule_25' });
    LIVR::Validator.register-default-rules('my_rule_25' => sub (@args, %builders) {
        sub ($value, $all-values, $output is rw) { return }
    });
    dies-ok { $validator.prepare }, 'Should not get default rules registered after it was created';
    lives-ok { LIVR::Validator.new(livr-rules => { name => 'my_rule_25', list => { list_of => 'my_rule_25' } }).prepare },
        'Should give them to validators created after the registration';
};

done-testing;
