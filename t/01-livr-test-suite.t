use lib 'lib';

use Test;
use JSON::Tiny;

use LIVR;

for 'test_suite', 'test_suite_2.5' -> $suite {
    # LIVR 2.0 cases are compared with is-deeply. LIVR 2.5 cases are compared as JSON values:
    # their numbers are equal by value, as JSON has one number type. JSON::Tiny reads 10 as an
    # Int and 10.0 and -0.0 as Rats, and a 2.5 case expects 10 for 10.0, but -0.0 for -0.0.
    my &is-same = $suite eq 'test_suite' ?? &is-deeply !! &is-json;

    iterate-test-data("$suite/positive", sub (%data) {
        my $validator = build-validator(%data);
        my $output = $validator.validate( %data<input> );

        ok(! $validator.errors, 'Validator should contain no errors' ) or diag $validator.errors;
        is-same( $output, %data<output>, 'Validator should return validated data' )
            or die { got_error => $validator.errors(), test_data => %data.gist }.gist;
    });

    iterate-test-data("$suite/negative", sub (%data) {
        my $validator = build-validator(%data);
        my $output = $validator.validate( %data<input> );

        ok(!$output, 'Validator should return false');

        is-same( $validator.errors, %data<errors>, 'Validator should contain valid errors' )
            or die { got_errors => $validator.errors(), test_data => %data }.gist;
    });

    iterate-test-data("$suite/aliases_positive", sub (%data) {
        my $validator = build-validator(%data);
        my $output = $validator.validate( %data<input> );

        ok(! $validator.errors, 'Validator should contain no errors' ) or diag $validator.errors;
        is-same( $output, %data<output>, 'Validator should return validated data' )
            or die { got_error => $validator.errors(), test_data => %data.gist }.gist;
    });

    iterate-test-data("$suite/aliases_negative", sub (%data) {
        my $validator = build-validator(%data);
        my $output = $validator.validate( %data<input> );

        ok(!$output, 'Validator should return false');

        is-same( $validator.errors, %data<errors>, 'Validator should contain valid errors' )
            or die { got_errors => $validator.errors(), test_data => %data }.gist;
    });

    # Schemas that must not build: building the validator, with the aliases registered, fails
    iterate-test-data("$suite/schema_errors", sub (%data) {
        dies-ok { build-validator(%data).prepare() }, 'Building the validator should fail';
    }) if "$*CWD/t/$suite/schema_errors".IO.d;
}

done-testing;

# A validator for the rules of a case, with its aliases
sub build-validator(%data) {
    my $validator = LIVR::Validator.new( livr-rules => %data<rules> );
    for @(%data<aliases> // []) { $validator.register-aliased-rule($_) }

    return $validator;
}

sub is-json($got, $expected, $description) {
    my $is-ok = ok(json-eqv($got, $expected), $description);
    diag "expected: {$expected.raku}\n     got: {$got.raku}" unless $is-ok;

    return $is-ok;
}

# Equal as JSON values: numbers by value, but a boolean is never a number
sub json-eqv($got, $expected --> Bool:D) {
    return !$got.defined if !$expected.defined;
    return False unless $got.defined;

    return $got ~~ Bool && $got === $expected if $expected ~~ Bool;
    return $got ~~ Str && $got eq $expected if $expected ~~ Str;
    return $got ~~ Real && $got !~~ Bool && $got !~~ Str && $got == $expected if $expected ~~ Real;

    if $expected ~~ Hash {
        return False unless $got ~~ Hash && $got.keys.sort eqv $expected.keys.sort;
        return so $expected.keys.map({ json-eqv($got{$_}, $expected{$_}) }).all;
    }

    if $expected ~~ Array {
        return False unless $got ~~ Array && $got.elems == $expected.elems;
        return so (^$expected.elems).map({ json-eqv($got[$_], $expected[$_]) }).all;
    }

    return False;
}

# options.json fixes the current time of a case, {"now": "2026-10-18T12:00:00Z"}: "time" is
# wrapped while the case runs, as an application would fix the clock in its tests
sub with-clock($now, &code) {
    return code() without $now;
    return fixed-clock($now, &code);
}

sub fixed-clock($now, &code) {
    my $posix = DateTime.new($now).posix;
    my $handle = &term:<time>.wrap({ $posix });
    LEAVE $handle.restore;

    return code();
}

sub iterate-test-data($dir-basename, $cb) {
    my $Bin = "$*CWD/t"; # TODO use something like FindBin
    my $dir-fullname = "$Bin/$dir-basename";
    note( "PROCESSING: $dir-fullname" );

    # Cases are directories, README.md is not a case
    for dir($dir-fullname).grep(*.d).sort -> $testdir {
        my %data = testname => $testdir;

        for dir $testdir, test => /json/ -> $testfile {
            my $content = from-json( slurp $testfile );

            # Prepare key
            my $testfile-rel = $testfile.subst($testdir, '');
            my @parts = split( /\/|\\/, $testfile-rel).grep( *.chars );
            my $key = @parts.pop.subst('.json', '');

            # Go deep and set content
            my $hash = %data;
            for @parts -> $part {
                $hash = $hash{$part} || {};
            }
            $hash{$key} = $content;
        }

        subtest sub {
            with-clock(%data<options><now>, { $cb( %data ) });
        }, "Test $testdir";
    }
}
