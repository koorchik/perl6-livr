use lib 'lib';

use Test;
use LIVR;

LIVR::Validator.register-default-rules({
    'my_ucfirst' => sub ([], %builders) {
         return sub ($value, %all-values, $output is rw) {
            return if LIVR::Utils::is-no-value($value);

            $output = $value.tc;
            return;
        }
    },
    'my_lc' => sub ([], %builders) {
         return sub ($value, %all-values, $output is rw) {
            return if LIVR::Utils::is-no-value($value);

            $output = $value.lc;
            return;
        }
    },
    'my_trim' => sub ([], %builders) {
         return sub ($value, %all-values, $output is rw) {
            return if LIVR::Utils::is-no-value($value);

            $output = $value.trim;
            return;
        }
    }
});

subtest 'Validate data with registered rules' => sub {
    my $validator = LIVR::Validator.new(livr-rules => {
        word1 => ['my_trim', 'my_lc', 'my_ucfirst'],
        word2 => ['my_trim', 'my_lc'],
        word3 => ['my_ucfirst'],
    });

    my $output = $validator.validate({
        word1 => ' wordOne ',
        word2 => ' wordTwo ',
        word3 => 'wordThree ',
    });

    is-deeply $output, {
        word1 => 'Wordone',
        word2 => 'wordtwo',
        word3 => 'WordThree ',
    }, 'Should appluy changes to values';
};

subtest 'list_of, or and aliases pass the same arguments to rules as validate()' => sub {
    my @calls;
    my $validator = LIVR::Validator.new(livr-rules => {
        list    => { list_of => ['my_spy', 'my_spy'] },
        any     => { or => [ ['my_spy', { eq => 'nope' }], ['my_spy'] ] },
        aliased => 'my_spied_alias',
        empty   => { list_of => [] },
    });

    $validator.register-rules('my_spy' => sub ([], %builders) {
        return sub ($value, $all-values, $output is rw) {
            @calls.push: [$value, $all-values.clone];

            $output = $value ~ '!';
            return;
        }
    });
    $validator.register-aliased-rule({ name => 'my_spied_alias', rules => ['my_spy'] });

    my $output = $validator.validate({ list => ['a'], any => 'b', aliased => 'c', empty => [1, 2] });

    is-deeply $output, { list => ['a!!'], any => 'b!', aliased => 'c!', empty => [Any, Any] }, 'Should apply rules';

    # Fields are validated in hash order, so the calls are sorted
    is-deeply [@calls.sort(*[0])], [
        ['a',  { field => 'a' }],
        ['a!', { field => 'a' }],
        ['b',  { field => 'b' }],
        ['b',  { field => 'b' }],
        ['c',  { value => 'c' }],
    ], 'Should pass the value and all values to each rule';
};

# The test suite has the other edge cases of these rules
subtest 'Rules edge cases out of the test suite' => sub {
    my $validator = LIVR::Validator.new(livr-rules => { email => 'email', date => 'iso_date' });

    is-deeply $validator.validate({ email => '"q"@b.com', date => '0000-01-31' }),
        { email => '"q"@b.com', date => '0000-01-31' },
        'Should accept a quoted local part and the year 0000';
};

done-testing;

