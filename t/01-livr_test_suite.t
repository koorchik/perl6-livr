use lib 'lib';

use Test;
use JSON::Tiny;
use Terminal::ANSIColor;

use LIVR;

iterate-test-data('test_suite/positive', sub (%data) {
    return if %data<testname>.match('like');
    return if %data<testname>.match('iso_date');

    my $validator = LIVR::Validator.new( livr-rules => %data<rules> );
    my $output = $validator.validate( %data<input> );

    ok(! $validator.errors, 'Validator should contain no errors' ) or diag $validator.errors;
    is-deeply( $output, %data<output>, 'Validator should return validated data' ) 
        or die { got_error => $validator.errors(), test_data => %data.gist }.gist;
});


iterate-test-data('test_suite/negative', sub (%data) {
    return if %data<testname>.match('like');
    return if %data<testname>.match('iso_date');
    # return if %data<testname>.match('url');


    my $validator = LIVR::Validator.new( livr-rules => %data<rules> );
    my $output = $validator.validate( %data<input> );

    ok(!$output, 'Validator should return false');

    is-deeply( $validator.errors, %data<errors>, 'Validator should contain valid errors' )
        or die { got_errors => $validator.errors(), test_data => %data }.gist;
});



# iterate-test-data('test_suite/aliases_positive', sub (%data) {
#     my $validator = LIVR::Validator.new( livr-rules => %data<rules> );
#     for %data<aliases> { $validator.register-aliased-rule($_) };
#     my $output = $validator.validate( %data<input> );
#
#     ok(! $validator.errors, 'Validator should contain no errors' ) or diag $validator.errors;
#     is-deeply( $output, %data<output>, 'Validator should return validated data' );
# });
#
#
# iterate-test-data('test_suite/aliases_negative', sub (%data) {
#     my $validator = LIVR::Validator.new( livr-rules => %data<rules> );
#     for %data<aliases> { $validator.register-aliased-rule($_) };
#     my $output = $validator.validate( %data<input> );
#
#
#     ok(!$output, 'Validator should return false');
#
#     is-deeply( $validator.errors, %data<errors>, 'Validator should contain valid errors' )
#         or diag { got_errors => $validator.errors(), test_data => %data };
# });

done-testing;

sub iterate-test-data($dir-basename, $cb) {
    my $Bin = "$*CWD/t"; # TODO use something like FindBin
    my $dir-fullname = "$Bin/$dir-basename";
    note( colored($dir-fullname, 'yellow bold') );

    for dir $dir-fullname -> $testdir {
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
            $cb( %data );
        }, "Test $testdir";
    }
}
