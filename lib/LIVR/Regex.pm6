unit module LIVR::Regex;

# The "like" rule gets regexes in the common syntax of JavaScript, Perl and PCRE. They are
# translated to Raku syntax, to be interpolated into a Raku regex. Every literal character
# is escaped, so a pattern cannot add Raku code (closures, method calls) to the regex.

# Like in JavaScript, \d and \w match ASCII characters only
my %CLASS-ESCAPES = d => '<[0..9]>', D => '<-[0..9]>', w => '<[a..zA..Z0..9_]>', W => '<-[a..zA..Z0..9_]>',
    s => '\s', S => '\S';
my %CLASS-ESCAPES-IN-CLASS = d => '0..9', D => '\D', w => 'a..z A..Z 0..9 _', W => '\W', s => '\s', S => '\S';

# Control characters and spaces as codes, other characters quoted: :i works for quoted
# characters, but not for codes
sub literal(Str $char --> Str) {
    return '\x[' ~ $char.ord.base(16) ~ ']' if $char ~~ /^ <:Cc + :Z + :Cf> $/;
    return "'" ~ $char.subst('\\', '\\\\', :g).subst("'", "\\'", :g) ~ "'";
}

our sub translate-regex(Str $re --> Str) is export {
    my @chars = $re.comb;
    my $pos = 0;

    my sub unsupported($message) { die "Unsupported regex [$re] in \"like\" rule: $message\n" }
    my sub next-is(Str $char) { $pos < @chars && @chars[$pos] eq $char }

    my sub class-literal(Str $char --> Str) {
        unsupported 'a character class with a multi-codepoint character' if $char.ords.elems > 1;
        return $char ~~ /^ <:L + :N> $/ ?? $char !! '\x[' ~ $char.ord.base(16) ~ ']';
    }

    # Returns { char => ... } for a character, { class => ... } for \d, \w, \s
    # and their negations, { raku => ... } for an assertion
    my sub read-escape(Bool :$in-class = False) {
        unsupported 'a trailing backslash' if $pos >= @chars;
        my $c = @chars[$pos++];

        return { class => $c } if $c eq any(<d D w W s S>);

        given $c {
            when 'b' { return $in-class ?? { char => "\x08" } !! { raku => '<|w>' } }
            when 'B' { unsupported '\B in a character class' if $in-class; return { raku => '<!|w>' } }
            when 'n' { return { char => "\n" } }
            when 'r' { return { char => "\r" } }
            when 't' { return { char => "\t" } }
            when 'f' { return { char => "\f" } }
            when 'v' { return { char => "\x0B" } }
            when '0' { return { char => "\x00" } }
            when 'x' {
                # \xHH, or \x{HHHH} as in Perl and PCRE
                my $hex = $re.substr($pos) ~~ /^ [ '{' (<xdigit> ** 1..6) '}' || (<xdigit> ** 2) ] /;
                return { char => 'x' } unless $hex;
                $pos += $hex.chars;
                return { char => :16(~$hex[0]).chr };
            }
            when 'u' {
                my $hex = $re.substr($pos) ~~ /^ (<xdigit> ** 4) /;
                return { char => 'u' } unless $hex;
                $pos += $hex.chars;
                return { char => :16(~$hex[0]).chr };
            }
            when 'c' {
                return { char => 'c' } unless $pos < @chars && @chars[$pos] ~~ /^ <[a..zA..Z]> $/;
                return { char => (@chars[$pos++].uc.ord % 32).chr };
            }
            when /^ <[1..9]> $/ { unsupported 'backreferences are not supported' }
            when 'k' | 'p' | 'P' { unsupported "\\$c is not supported" }
            default { return { char => $c } }
        }
    }

    my sub read-class(--> Str) {
        my $is-negated = next-is('^');
        $pos++ if $is-negated;

        my @items;
        loop {
            unsupported 'an unterminated character class' if $pos >= @chars;
            my $c = @chars[$pos++];
            last if $c eq ']';

            my %item = $c eq '\\' ?? read-escape(:in-class) !! (char => $c);

            if %item<char>:exists && next-is('-') && $pos + 1 < @chars && @chars[$pos + 1] ne ']' {
                $pos++;
                my $end-char = @chars[$pos++];
                my %end = $end-char eq '\\' ?? read-escape(:in-class) !! (char => $end-char);

                if %end<char>:exists {
                    unsupported 'a character class range out of order' if %end<char>.ord < %item<char>.ord;
                    @items.push: class-literal(%item<char>) ~ '..' ~ class-literal(%end<char>);
                } else {
                    @items.push: class-literal(%item<char>), class-literal('-'), %CLASS-ESCAPES-IN-CLASS{%end<class>};
                }
                next;
            }

            @items.push: %item<char>:exists ?? class-literal(%item<char>) !! %CLASS-ESCAPES-IN-CLASS{%item<class>};
        }

        # Like in JavaScript, [] matches nothing and [^] matches any character
        return $is-negated ?? '.' !! '<!>' unless @items;
        return ($is-negated ?? '<-[' !! '<[') ~ @items.join(' ') ~ ']>';
    }

    my sub read-group-start() {
        return '(', ')' unless next-is('?');

        my $rest = $re.substr($pos);
        given $rest {
            when .starts-with('?:')  { $pos += 2; return '[', ']' }
            when .starts-with('?=')  { $pos += 2; return '<?before', '>' }
            when .starts-with('?!')  { $pos += 2; return '<!before', '>' }
            when .starts-with('?<=') { $pos += 3; return '<?after', '>' }
            when .starts-with('?<!') { $pos += 3; return '<!after', '>' }
        }

        my $named = $rest ~~ /^ '?<' (<[a..zA..Z_]> <[a..zA..Z0..9_]>*) '>' /;
        unsupported 'an unsupported group' unless $named;
        $pos += $named.chars;

        return '$<' ~ $named[0] ~ '>=(', ')';
    }

    my sub read-lazy(--> Str) {
        return '' unless next-is('?');
        $pos++;
        return '?';
    }

    my sub read-braces-quantifier() {
        my $braces = $re.substr($pos) ~~ /^ (<[0..9]>+) (','?) (<[0..9]>*) '}' /;
        return Nil unless $braces;
        $pos += $braces.chars;

        my ($min, $comma, $max) = $braces.list.map(~*);
        $max = $comma ?? ($max || '*') !! $min;
        unsupported 'numbers out of order in {} quantifier' if $max ne '*' && $max < $min;

        return '**' ~ read-lazy() ~ " $min..$max";
    }

    my @parts;
    my @closers;
    my $is-branch-empty = True;
    my $is-quantifiable = False;

    my sub add-atom(Str $raku, Bool :$quantifiable = True) {
        @parts.push($raku);
        $is-branch-empty = False;
        $is-quantifiable = $quantifiable;
    }

    my sub add-quantifier(Str $raku) {
        unsupported 'nothing to repeat' unless $is-quantifiable;
        @parts.push($raku);
        $is-quantifiable = False;
    }

    while $pos < @chars {
        my $c = @chars[$pos++];

        given $c {
            when '\\' {
                my %escape = read-escape();
                if %escape<raku>:exists {
                    add-atom(%escape<raku>, :!quantifiable);
                } else {
                    add-atom(%escape<char>:exists ?? literal(%escape<char>) !! %CLASS-ESCAPES{%escape<class>});
                }
            }
            when '[' { add-atom(read-class()) }
            when '(' {
                my ($opener, $closer) = read-group-start();
                @parts.push($opener);
                @closers.push($closer);
                $is-branch-empty = True;
                $is-quantifiable = False;
            }
            when ')' {
                unsupported 'an unmatched ")"' unless @closers;
                @parts.push('<?>') if $is-branch-empty;
                add-atom(@closers.pop);
            }
            when '|' {
                @parts.push('<?>') if $is-branch-empty;
                @parts.push('||');
                $is-branch-empty = True;
                $is-quantifiable = False;
            }
            when '*' | '+' | '?' { add-quantifier($c ~ read-lazy()) }
            when '{' {
                with read-braces-quantifier() -> $quantifier {
                    add-quantifier($quantifier);
                } else {
                    add-atom(literal('{'));
                }
            }
            when '.' { add-atom('\N') }
            when '^' | '$' { add-atom($c, :!quantifiable) }
            default { add-atom(literal($c)) }
        }
    }

    unsupported 'an unmatched "("' if @closers;
    @parts.push('<?>') if $is-branch-empty;

    return @parts.join(' ');
}
