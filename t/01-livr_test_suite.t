use Test;
use LIVR;

my $validator = LIVR::Validator.new( livr-rules => {
    name   => ['required'],
    email  => { 'required' => [] }
});

my $validated = $validator.validate({
    name => '',
    email => 'koorchik@gmail.com'
});

ok !$validated, 'Should return false on failed validation';
is $validator.errors<name>, 'REQUIRED', 'Name should be REQUIRED';

done-testing;
