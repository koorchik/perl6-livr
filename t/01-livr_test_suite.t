use LIVR;

my $validator = LIVR::Validator.new( livr-rules => {
    name   => ['required'],
    email  => { 'required' => [] }
});

my $validated = $validator.validate({
    name => '',
    email => 'koorchik@gmail.com'
});

if $validated {
    say 'SUCCESS';
    say $validated;
} else {
    say 'ERRORS';
    say $validator.errors;
}
