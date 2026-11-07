unit module LIVR::Rules::Meta;
use LIVR::Validator;
use LIVR::Utils :DEFAULT, :internal;

our sub nested_object([Hash $livr-rules, *@], %builders) {
    my $validator = LIVR::Validator.new(livr-rules => $livr-rules)
        .register-rules(%builders)
        .prepare();

    return sub ($nested-object, %all-values, $output is rw) {
        return if is-no-value($nested-object);
        return 'FORMAT_ERROR' unless $nested-object ~~ Hash;

        my $result = $validator.validate( $nested-object );

        if $result.defined {
            $output = $result;
            return;
        } else {
            return $validator.errors;
        }
    }
}

# Items of list_of, values of "values" and keys of "keys" have no containing object: a field
# that their rules refer to is missing
my constant NO-FIELDS = Map.new;

# The rules of list_of, "values" and "keys": list_of('string'), list_of('required', 'string')
# or list_of(['required', 'string'])
sub item-rules(@args) {
    return @args[0] ~~ Array ?? @args[0].list !! @args;
}

our sub list_of(@args is copy, %builders) {
    my @rules = item-rules(@args);

    my &item-rule = LIVR::Validator.new(livr-rules => { field => @rules })
        .register-rules(%builders)
        .field-rule('field');

    return sub ($values, $all-values, $output is rw) {
        return if is-no-value($values);
        return 'FORMAT_ERROR' unless $values ~~ Array;

        my ( @results, @errors );
        my $has-errors = False;

        for @$values -> $value {
            my $result = $value;
            my $error = &item-rule ?? item-rule($value, NO-FIELDS, $result) !! Nil;

            if $error {
                @errors.push($error);
                @results.push(Any);
                $has-errors = True;
            } else {
                # A list without rules gives undefined items, as a field without rules
                @results.push(&item-rule ?? $result !! Any);
                @errors.push(Any);
            }
        }

        return @errors if $has-errors;

        $output = @results;
        return;
    }
}

our sub list_of_objects([Hash $livr-rules, *@], %builders) {
    my $validator = LIVR::Validator.new(livr-rules => $livr-rules)
        .register-rules(%builders)
        .prepare();

    return sub ($objects, %all-values, $output is rw) {
        return if is-no-value($objects);
        return 'FORMAT_ERROR' unless $objects ~~ Array;

        my ( @results, @errors );

        for @$objects -> $object {
            my $result = $validator.validate($object);
            
            if $result.defined {
                @results.push( $result );
                @errors.push(Any);
            } else {
                 @errors.push( $validator.errors() );
                 @results.push(Any);
            }
        }

        if @errors.grep(!!*) {
            return @errors;
        } else {
            $output = @results;
            return;
        }
    }
}

# The selector value must be a string or a number. A list or a hash
# would make a hash slice of %validators instead of a key lookup.
sub select-validator(%validators, $object, $selector-field) {
    return Nil if $object !~~ Hash;

    my $selector-value = $object{$selector-field};
    return Nil if ($selector-value !~~ Str && $selector-value !~~ Numeric) || !$selector-value;

    return %validators{ $selector-value.Str };
}

our sub list_of_different_objects([Str $selector-field, Hash $livrs, *@], %builders) {
    my %validators;
    
    for %$livrs.kv -> $selector-value, $livr-rules {
        my $validator = LIVR::Validator.new(livr-rules => $livr-rules)
            .register-rules(%builders)
            .prepare();

        %validators{$selector-value} = $validator;
    }

    return sub ($objects, %all-values, $output is rw) {
        return if is-no-value($objects);
        return 'FORMAT_ERROR' unless $objects ~~ Array;

        my ( @results, @errors );

        for @$objects -> $object {
            my $validator = select-validator(%validators, $object, $selector-field);

            unless $validator {
                @errors.push('FORMAT_ERROR');
                next;
            }

            my $result = $validator.validate($object);
            
            if $result.defined {
                @results.push( $result );
                @errors.push(Any);
            } else {
                 @errors.push( $validator.errors() );
                 @results.push(Any);
            }
        }

        if @errors.grep(!!*) {
            return @errors;
        } else {
            $output = @results;
            return;
        }
    }
}

our sub variable_object([Str $selector-field, Hash $livrs, *@], %builders) {
    my %validators;
    
    for %$livrs.kv -> $selector-value, $livr-rules {
        my $validator = LIVR::Validator.new(livr-rules => $livr-rules)
            .register-rules(%builders)
            .prepare();

        %validators{$selector-value} = $validator;
    }

    return sub ($object, %all-values, $output is rw) {
        return if is-no-value($object);

        my $validator = select-validator(%validators, $object, $selector-field);
        return 'FORMAT_ERROR' unless $validator;

        my $result = $validator.validate( $object );

        if $result.defined {
            $output = $result;
            return;
        } else {
            return $validator.errors;
        }
    }
}

our sub livr_or(@rule-sets, %builders) {
    # One validator for all rule sets. Rule sets are transparent: their rules see the
    # containing object of the field
    my %livr-rules = @rule-sets.kv.map(-> $index, $rules { $index => $rules });
    my $validator = LIVR::Validator.new(livr-rules => %livr-rules)
        .register-rules(%builders)
        .prepare();
    my @rules = @rule-sets.keys.map({ $validator.field-rule($_) });

    return sub ($value, $all-values, $output is rw) {
        # Empty values go to the rule sets too, so "required" and "not_empty" in them work
        my $last-error;

        for @rules -> $rule {
            # A rule set without rules gives an undefined value, as a field without rules
            unless $rule {
                $output = Any;
                return;
            }

            my $result = $value;
            my $error = $rule($value, $all-values, $result);
            unless $error {
                $output = $result;
                return;
            }

            $last-error = $error;
        }

        return $last-error if $last-error;
        return;
    }
}

# LIVR 2.5

# Rule sets in any form that a field accepts, as rules of one validator. An empty list of rules
# is a schema error (LIVR 2.5, section 2.6): "any" is a rule set without rules
sub build-rule-sets(@rule-sets, %builders) {
    my %livr-rules;
    for @rule-sets.kv -> $index, $rules {
        die "LIVR: rule [when] got an empty list of rules, use \"any\" for no rules\n"
            if $rules ~~ Array && !$rules.elems;
        %livr-rules{$index} = $rules;
    }

    my $validator = LIVR::Validator.new(livr-rules => %livr-rules)
        .register-rules(%builders)
        .prepare();

    return @rule-sets.keys.map({ $validator.field-rule($_) }).list;
}

#   { when => [REFERENCE, CONDITION, RULES_IF_TRUE, RULES_IF_FALSE] }, RULES_IF_FALSE is optional
#   { when => [REFERENCE, CASES] }
# Without RULES_IF_FALSE a false condition keeps the value as it is. Arguments after the 4th are
# ignored
our sub livr_when(@args, %builders) {
    die "LIVR: rule [when] takes a reference and cases, or a reference, a condition, rules if "
        ~ "true and optional rules if false, got {+@args} argument{@args == 1 ?? "" !! "s"}\n"
        if @args < 2;

    return build-switch(@args[0], @args[1], %builders) if @args == 2;

    my @path = parse-reference(@args[0], 'when');
    my ($condition-rule, $true-rule, $false-rule) = build-rule-sets(@args[1 .. min(3, @args.end)], %builders);

    return sub ($value, $all-values, $output is rw) {
        my $referenced = resolve-reference($all-values, @path);

        # The condition rules run on the referenced value, their output is discarded
        my $is-true = !is-empty($referenced);
        if $is-true {
            my $condition-output = $referenced;
            $is-true = !$condition-rule($referenced, $all-values, $condition-output);
        }

        my $branch-rule = $is-true ?? $true-rule !! $false-rule;
        return unless $branch-rule;

        return $branch-rule($value, $all-values, $output);
    };
}

sub build-switch($reference, $cases, %builders) {
    my @path = parse-reference($reference, 'when');

    die "LIVR: the cases of rule [when] must be an object of values to rules\n" unless $cases ~~ Hash;
    die "LIVR: the cases of rule [when] must not be empty\n" unless $cases.elems;

    my @case-values = $cases.keys;
    my @case-rules = build-rule-sets($cases{@case-values}, %builders);
    my %case-rules = @case-values Z=> @case-rules;

    return sub ($value, $all-values, $output is rw) {
        my $referenced = resolve-reference($all-values, @path);

        if is-primitive($referenced) && !($referenced ~~ Str && $referenced eq '') {
            my $case-value = string-form($referenced);

            with %case-rules{$case-value} -> &case-rule {
                return case-rule($value, $all-values, $output);
            }
        }

        # No case is chosen. An empty value passes (the referenced field reports its own
        # errors), any other value would pass unchecked
        return is-empty($value) ?? Nil !! 'NOT_ALLOWED_VALUE';
    };
}

#   { values => 'string' }, { values => ['required', 'string'] } or { values => [['required', 'string']] }
our sub livr_values(@args, %builders) {
    my @rules = item-rules(@args);
    die "LIVR: rule [values] needs rules\n" unless @rules;

    my &value-rule = LIVR::Validator.new(livr-rules => { field => @rules })
        .register-rules(%builders)
        .field-rule('field');

    return sub ($object, $all-values, $output is rw) {
        return if is-empty($object);
        return 'FORMAT_ERROR' unless $object ~~ Hash;

        my ( %results, %errors );

        for $object.kv -> $key, $value {
            my $result = $value;
            my $error = &value-rule ?? value-rule($value, NO-FIELDS, $result) !! Nil;

            if $error {
                %errors{$key} = $error;
            } else {
                %results{$key} = $result;
            }
        }

        return %errors if %errors;

        $output = %results;
        return;
    }
}

#   { keys => { one_of => ['uk', 'en'] } }, the same arguments as "values"
our sub livr_keys(@args, %builders) {
    my @rules = item-rules(@args);
    die "LIVR: rule [keys] needs rules\n" unless @rules;

    # Keys are checked as they are, without auto trim
    my &key-rule = LIVR::Validator.new(livr-rules => { field => @rules }, :!is-auto-trim)
        .register-rules(%builders)
        .field-rule('field');

    return sub ($object, $all-values, $output is rw) {
        return if is-empty($object);
        return 'FORMAT_ERROR' unless $object ~~ Hash;
        return unless &key-rule;

        # The rules only check the keys, their output is ignored
        my %errors;
        for $object.keys -> $key {
            my $result = $key;
            %errors{$key} = 'WRONG_KEY' if key-rule($key, NO-FIELDS, $result);
        }

        return %errors if %errors;
        return;
    }
}
