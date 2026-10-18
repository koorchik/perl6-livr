use lib 'lib';

use Test;
use LIVR;

sub is-like($re, $value, $flags = '') {
    my $validator = LIVR::Validator.new(livr-rules => { field => { like => [$re, $flags] } });
    return so $validator.validate({ field => $value });
}

# Each case: regex, flags, values that match, values that do not match.
# The results are the same as of the JavaScript RegExp.test()
my @cases =
    ['^\d{3}-\d{2,4}$',                 '',  ['123-45', '123-4567'],      ['12-34', '123-4', '123-45678', '٣٣٣-٣٣']],
    ['^\w+?$',                          '',  ['abc_1'],                   ['ab c', 'абв']],
    ['^\s*\S+\s*$',                     '',  ["  ab  ", "\tq\n"],         ['a b']],
    ['^(foo|bar)+$',                    '',  ['foobar'],                  ['foob']],
    ['^(?:a|)b$',                       '',  ['ab', 'b'],                 ['cb']],
    ['^(a|b|)$',                        '',  ['a'],                       ['c']],
    ['^a.c$',                           '',  ['abc', 'a.c'],              ["a\nc", 'ac']],
    ['^a\.c$',                          '',  ['a.c'],                     ['abc']],
    ['^[^a-c]+$',                       '',  ['def'],                     ['dad']],
    ['^[\w.-]+@[\w-]+\.\w{2,}$',        '',  ['a.b-c@d-e.com'],           ['a@b.c', 'a b@c.de']],
    ['^a{2,3}?b',                       '',  ['aab', 'aaab'],             ['ab']],
    ['a{,3}',                           '',  ['a{,3}'],                   ['aaa']],
    ['^\bfoo\b',                        '',  ['foo bar'],                 ['foobar']],
    ['oo\B',                            '',  ['foox'],                    ['foo']],
    ['^(?=.*\d)(?=.*[a-z]).{6,}$',      '',  ['abc123'],                  ['abcdef', 'ab1']],
    ['^(?!admin$).+$',                  '',  ['admins', 'user'],          ['admin']],
    ['(?<=\$)\d+',                      '',  ['cost $42'],                ['cost 42']],
    ['(?<!\$)\b\d+',                    '',  ['42'],                      ['$42']],
    ['^(?<year>\d{4})-(?<month>\d{2})$', '', ['2024-01'],                 ['24-01']],
    ['^\x41B\x{43}$',              '',  ['ABC'],                     ['abc']],
    ['^[\x41-\x43]+$',                  '',  ['ABCA'],                    ['ABD']],
    ['^[\d\s]+$',                       '',  ['1 2 3'],                   ['1a']],
    ['^[^\W_]+$',                       '',  ['abc1'],                    ['ab_c', 'a-b']],
    ['^[a\-z]+$',                       '',  ['a-z'],                     ['b']],
    ['^[-a]+$',                         '',  ['-a'],                      ['b']],
    ['^[\]\[]+$',                       '',  ['[]]['],                    ['a']],
    ['^[.*+?()|{}^$]+$',                '',  ['.*+?()|{}^$'],             ['a']],
    ['^\.\*\+\?\(\)\|\{\}\^\$\/\\\\$',  '',  ['.*+?()|{}^$/\\'],          ['x']],
    ['^#\s#$',                          '',  ['# #'],                     ['##']],
    ["^it's \$",                        '',  ["it's "],                   ['its ']],
    ['^<{ die "pwned" }>$',             '',  ['<{ die "pwned" }>'],       ['pwned']],
    ['^[а-яіїє]+$',                     '',  ['привіт'],                  ['hello', 'ПРИВІТ']],
    ['^[а-яіїє]+$',                     'i', ['ПРИВІТ'],                  ['HELLO']],
    ['^Привіт$',                        'i', ['привіт', 'ПРИВІТ'],        ['привет']],
    ['colou?r',                         'i', ['COLOR', 'Colour'],         ['colr']],
    ['^\$\d+(\.\d\d)?$',                '',  ['$10', '$10.50'],           ['$10.5']],
    ['[^]',                             '',  ['a', "\n"],                 []],
    ['^\cJ\t\0$',                       '',  ["\n\t\x00"],                ['cJt0']],
    ['',                                '',  ['anything'],                []];

for @cases -> [$re, $flags, @matching, @not-matching] {
    subtest "like [$re] {$flags}" => sub {
        ok  is-like($re, $_, $flags), "should match {$_.raku}"     for @matching;
        nok is-like($re, $_, $flags), "should not match {$_.raku}" for @not-matching;
    };
}

subtest 'Unsupported regexes fail when the rule is built' => sub {
    for '(a)\1', '(?i)a', 'a**', '*a', '(a', 'a)', '[a', 'a\\', 'a{3,1}', '[z-a]', '\p{L}' -> $re {
        my $validator = LIVR::Validator.new(livr-rules => { field => { like => $re } });
        throws-like { $validator.prepare() }, Exception, message => /'Unsupported regex'/, "should not accept {$re.raku}";
    }
};

done-testing;
