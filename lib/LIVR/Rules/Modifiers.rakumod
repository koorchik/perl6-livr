unit module LIVR::Rules::Modifiers;
use LIVR::Utils :DEFAULT, :internal;

# The LIVR 2.0 rules ignore extra arguments

our sub trim(@, %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value) || ($value !~~ Str && $value !~~ Numeric);
        
        $output = $value.trim;
        return;
    };
}

our sub to_lc(@, %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value) || ($value !~~ Str && $value !~~ Numeric);
        
        $output = $value.lc;
        return;
    };
}

our sub to_uc(@, %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value) || ($value !~~ Str && $value !~~ Numeric);
        
        $output = $value.uc;
        return;
    };
}

our sub remove([Str $chars, *@], %builders) {
    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value) || ($value !~~ Str && $value !~~ Numeric);
        
        $output = $value.trans( $chars.Str => '', :delete );
        return;
    };
}

our sub leave_only([Str $chars, *@], %builders) {
    my $chars-set = set($chars.comb);

    return sub ($value, %all-values, $output is rw) {
        return if is-no-value($value) || ($value !~~ Str && $value !~~ Numeric);
        
        $output= $value.comb.grep(-> $c { $chars-set{$c} }).join('');

        # Does not work. Bug in Perl6 https://github.com/rakudo/rakudo/issues/1227
        # $output = $value.trans( $chars.Str => '',   :complement, :delete ); 
        
        return;
    };
}

# { default => Any } (null) sets null, as in the specification: an empty value becomes null, a
# missing field stays missing
our sub default([$default-value where Cool | Any:U, *@], %builders) {
    return sub ($value, %all-values, $output is rw) {
        
        if is-no-value($value) {
            $output = $default-value;
        }
        
        return;
    };
}

# LIVR 2.5

our sub livr_split(@args, %builders) {
    my $separator = string-argument(@args[0]);
    die "LIVR: rule [split] takes a non-empty separator string\n" unless $separator.defined && $separator ne '';

    # A modifier: lists, empty values and objects stay as they are, the next rule reports them
    return sub ($value, %all-values, $output is rw) {
        return unless $value.defined;

        # At every separator, not a regex. Empty parts are kept: "a,,b" is ["a", "", "b"]. A
        # number or a boolean is split in its string form: true is ["true"]
        if $value ~~ Str {
            $output = [$value.split($separator)] if $value ne '';
        } elsif $value ~~ Real {
            $output = [string-form($value).split($separator)];
        }

        return;
    };
}
