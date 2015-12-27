use lib 'lib';

use Test;
use JSON::Tiny;
use Terminal::ANSIColor;

use LIVR;

iterate-test-data('test_suite/positive', sub (%data) {
    my $validator = LIVR::Validator.new( livr-rules => %data<rules> );
    my $output = $validator.validate( %data<input> );

    ok(! $validator.errors, 'Validator should contain no errors' ) or diag $validator.errors;
    is-deeply( $output, %data<output>, 'Validator should return validated data' );
});


# iterate_test_data('test_suite/negative' => sub {
#     my $data = shift;
#
#     my $validator = Validator::LIVR->new( $data->{rules} );
#     my $output = $validator->validate( $data->{input} );
#
#     ok(!$output, 'Validator should return false');
#
#     is_deeply( $validator->get_errors(), $data->{errors}, 'Validator should contain valid errors' )
#         or diag explain { got_errors => $validator->get_errors(), test_data => $data };
# });
#
#
# iterate_test_data('test_suite/aliases_positive' => sub {
#     my $data = shift;
#
#     my $validator = Validator::LIVR->new( $data->{rules} );
#     $validator->register_aliased_rule($_) for @{ $data->{aliases} };
#     my $output = $validator->validate( $data->{input} );
#
#     ok(! $validator->get_errors(), 'Validator should contain no errors' ) or diag explain $validator->get_errors();
#     is_deeply( $output, $data->{output}, 'Validator should return validated data' );
# });
#
#
# iterate_test_data('test_suite/aliases_negative' => sub {
#     my $data = shift;
#
#     my $validator = Validator::LIVR->new( $data->{rules} );
#     $validator->register_aliased_rule($_) for @{ $data->{aliases} };
#
#     my $output = $validator->validate( $data->{input} );
#
#     ok(!$output, 'Validator should return false');
#
#     is_deeply( $validator->get_errors(), $data->{errors}, 'Validator should contain valid errors' );
# });
#
# done_testing;

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
            my @parts = split( '/', $testfile-rel).grep( *.chars );
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
