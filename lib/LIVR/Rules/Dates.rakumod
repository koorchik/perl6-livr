unit module LIVR::Rules::Dates;

# LIVR 2.5: iso_datetime, iso_time and iso_date with bounds

# Dates and times. Dates are compared as days since 1970-01-01, datetimes as milliseconds since
# 1970-01-01T00:00:00Z, times as nanoseconds since midnight. ASCII digits only.

# Without captures: they make a match several times slower. The parts are read with substr
my $date-re = rx/^ <[0..9]> ** 4 '-' <[0..9]> ** 2 '-' <[0..9]> ** 2 $/;

my $datetime-re = rx/^
    <[0..9]> ** 4 '-' <[0..9]> ** 2 '-' <[0..9]> ** 2
    'T' <[0..9]> ** 2 ':' <[0..9]> ** 2 [ ':' <[0..9]> ** 2 [ '.' <[0..9]> ** 1..9 ]? ]?
    [ 'Z' | <[+-]> <[0..9]> ** 2 ':' <[0..9]> ** 2 ]
$/;

my $time-re = rx/^ <[0..9]> ** 2 ':' <[0..9]> ** 2 [ ':' <[0..9]> ** 2 [ '.' <[0..9]> ** 1..9 ]? ]? $/;

my constant DAY-MS = 86400000;

# Bounds relative to the current date in UTC
my %RELATIVE-DAYS = yesterday => -1, today => 0, tomorrow => 1;

sub days-in-month(Int $year, Int $month --> Int) {
    return 31 - ($month - 1) % 7 % 2 unless $month == 2;
    return ($year %% 4 && ($year !%% 100 || $year %% 400)) ?? 29 !! 28;
}

# Days since 1970-01-01 of a date of the proleptic Gregorian calendar, "days_from_civil" of
# Howard Hinnant
sub days-from-civil(Int $year is copy, Int $month, Int $day --> Int) {
    $year-- if $month <= 2;
    my $era = $year div 400;
    my $year-of-era = $year - $era * 400;
    my $day-of-year = (153 * ($month > 2 ?? $month - 3 !! $month + 9) + 2) div 5 + $day - 1;
    my $day-of-era = $year-of-era * 365 + $year-of-era div 4 - $year-of-era div 100 + $day-of-year;
    return $era * 146097 + $day-of-era - 719468;
}

# The date of a day number, "civil_from_days" of Howard Hinnant
sub civil-from-days(Int $days) {
    my $z = $days + 719468;
    my $era = $z div 146097;
    my $day-of-era = $z - $era * 146097;
    my $year-of-era = ($day-of-era - $day-of-era div 1460 + $day-of-era div 36524 - $day-of-era div 146096) div 365;
    my $day-of-year = $day-of-era - (365 * $year-of-era + $year-of-era div 4 - $year-of-era div 100);
    my $shifted-month = (5 * $day-of-year + 2) div 153; # March is 0
    my $day = $day-of-year - (153 * $shifted-month + 2) div 5 + 1;
    my $month = $shifted-month < 10 ?? $shifted-month + 3 !! $shifted-month - 9;
    return $year-of-era + $era * 400 + ($month <= 2 ?? 1 !! 0), $month, $day;
}

sub is-valid-date(Int $year, Int $month, Int $day --> Bool:D) {
    1 <= $month <= 12 && 1 <= $day && ($day <= 28 || $day <= days-in-month($year, $month))
}

# The day number of a date YYYY-MM-DD, Nil when it is not a valid date
sub date-to-day(Str $string) {
    return Nil unless $string ~~ $date-re;

    my ($year, $month, $day) = $string.substr(0, 4).Int, $string.substr(5, 2).Int, $string.substr(8, 2).Int;
    return Nil unless is-valid-date($year, $month, $day);

    return days-from-civil($year, $month, $day);
}

# The milliseconds of a datetime with an offset, cut to milliseconds, Nil when it is not one
sub datetime-to-ms(Str $string) {
    return Nil unless $string ~~ $datetime-re;

    my ($year, $month, $day) = $string.substr(0, 4).Int, $string.substr(5, 2).Int, $string.substr(8, 2).Int;
    my ($hours, $minutes) = $string.substr(11, 2).Int, $string.substr(14, 2).Int;

    # The offset is "Z" or the last 6 characters
    my $is-utc = $string.ends-with('Z');
    my $end = $string.chars - ($is-utc ?? 1 !! 6);

    my $seconds = $end > 16 ?? $string.substr(17, 2).Int !! 0;
    return Nil unless is-valid-date($year, $month, $day) && $hours <= 23 && $minutes <= 59 && $seconds <= 59;

    # The first three fraction digits, the others are cut off
    my $ms = $end > 19 ?? ($string.substr(20, $end - 20) ~ '00').substr(0, 3).Int !! 0;

    my $offset = 0; # minutes east of UTC
    unless $is-utc {
        my ($offset-hours, $offset-minutes) = $string.substr($end + 1, 2).Int, $string.substr($end + 4, 2).Int;
        return Nil if $offset-hours > 23 || $offset-minutes > 59;

        $offset = $offset-hours * 60 + $offset-minutes;
        $offset = -$offset if $string.substr($end, 1) eq '-';
    }

    return ((days-from-civil($year, $month, $day) * 1440 + $hours * 60 + $minutes - $offset) * 60 + $seconds) * 1000 + $ms;
}

# YYYY-MM-DDTHH:MM:SS.sssZ, Nil outside the years 0000-9999
sub ms-to-utc(Int $ms) {
    my $days = $ms div DAY-MS;
    my $ms-of-day = $ms - $days * DAY-MS;
    my ($year, $month, $day) = civil-from-days($days);
    return Nil unless 0 <= $year <= 9999;

    return sprintf '%04d-%02d-%02dT%02d:%02d:%02d.%03dZ', $year, $month, $day,
        $ms-of-day div 3600000, $ms-of-day div 60000 % 60, $ms-of-day div 1000 % 60, $ms-of-day % 1000;
}

# The nanoseconds since midnight of HH:MM, HH:MM:SS or HH:MM:SS.fraction, Nil when it is not a time
sub time-to-ns(Str $string) {
    return Nil unless $string ~~ $time-re;

    my ($hours, $minutes) = $string.substr(0, 2).Int, $string.substr(3, 2).Int;
    my $seconds = $string.chars > 5 ?? $string.substr(6, 2).Int !! 0;
    return Nil if $hours > 23 || $minutes > 59 || $seconds > 59;

    my $ns = $string.chars > 8 ?? ($string.substr(9) ~ '00000000').substr(0, 9).Int !! 0;
    return (($hours * 60 + $minutes) * 60 + $seconds) * 1_000_000_000 + $ns;
}

# The current date in UTC as days since 1970-01-01, read from the system clock with "time" (POSIX
# seconds, 10 times cheaper than "now"). Tests fix the clock by wrapping it:
#   &term:<time>.wrap({ DateTime.new('2026-10-18T12:00:00Z').posix })
sub today(--> Int:D) {
    time div 86400
}

# The options object of a date or time rule: the first argument, if any. The arguments after it
# are ignored. Nil without arguments
sub options-argument(Str $rule-name, @args) {
    # { rule => Any } (null) is one argument, not an object: a schema error. LIVR::Rules::Special
    # keeps { iso_date => Any } the plain iso_date
    return Nil unless @args;
    return @args[0] if @args[0] ~~ Hash;

    my $hint = $rule-name eq 'iso_date' ?? ', LIVR 2.0 ignored other arguments' !! '';
    die "LIVR: rule [$rule-name] takes no arguments or an object with \"min\" and \"max\", got {@args[0].raku}$hint\n";
}

sub check-options(Str $rule-name, $options) {
    for $options.keys -> $key {
        next if $key eq 'min' || $key eq 'max';

        my $hint = $key eq 'format' && $rule-name eq 'iso_date' ?? ', use "iso_datetime" for datetimes' !! '';
        die "LIVR: rule [$rule-name] got an unknown option [$key]$hint\n";
    }
}

sub wrong-bound(Str $rule-name, Str $option, $bound) {
    my $hint = $bound ~~ Str && $bound eq 'current' ?? ', use "today" instead of "current"' !! '';
    die "LIVR: rule [$rule-name] got a wrong bound in [$option]: {$bound.raku}$hint\n";
}

# "min" later than "max" when both are fixed or both are relative: no value could pass. A fixed
# and a relative bound are not checked, the result depends on the day
sub check-bound-order(Str $rule-name, $min, $max) {
    return unless $min.defined && $max.defined;

    my $is-later = $min ~~ Pair && $max ~~ Pair ?? $min.value > $max.value
        !! $min !~~ Pair && $max !~~ Pair && $min > $max;
    die "LIVR: rule [$rule-name] got \"min\" later than \"max\"\n" if $is-later;
}

# The LIVR 2.0 form: YYYY-MM-DD, a valid date, the value is not changed
sub check-iso-date($value, $all-values, $output is rw) {
    return unless $value.defined;
    return 'FORMAT_ERROR' unless $value ~~ Str || $value ~~ Real;
    return 'WRONG_DATE' unless $value ~~ Str;
    return if $value eq '';

    return 'WRONG_DATE' unless date-to-day($value).defined;
    return;
}

#   { iso_date => { min => ..., max => ... } }: YYYY-MM-DD with bounds, a date or "today",
#   "yesterday", "tomorrow". LIVR::Rules::Special builds the other forms of iso_date
our sub iso_date(@args, %builders) {
    my $options = options-argument('iso_date', @args) // return &check-iso-date;
    check-options('iso_date', $options);

    # A day number, or a day relative to the current date as a Pair
    my sub parse-bound(Str $option) {
        my $bound = $options{$option};
        return Nil unless $options{$option}:exists;

        if $bound ~~ Str:D {
            return 'relative' => %RELATIVE-DAYS{$bound} if %RELATIVE-DAYS{$bound}:exists;
            with date-to-day($bound) { return $_ }
        }

        wrong-bound('iso_date', $option, $bound);
    }

    my $min = parse-bound('min');
    my $max = parse-bound('max');
    return &check-iso-date unless $min.defined || $max.defined;

    check-bound-order('iso_date', $min, $max);
    my $is-relative = $min ~~ Pair || $max ~~ Pair;

    return sub ($value, $all-values, $output is rw) {
        return unless $value.defined;
        return 'FORMAT_ERROR' unless $value ~~ Str || $value ~~ Real;
        return 'WRONG_DATE' unless $value ~~ Str;
        return if $value eq '';

        my $day = date-to-day($value) // return 'WRONG_DATE';

        # One clock read per value
        my $today = $is-relative ?? today() !! 0;
        my $min-day = $min ~~ Pair ?? $today + $min.value !! $min;
        my $max-day = $max ~~ Pair ?? $today + $max.value !! $max;

        return 'DATE_TOO_EARLY' if $min-day.defined && $day < $min-day;
        return 'DATE_TOO_LATE' if $max-day.defined && $day > $max-day;
        return;
    };
}

#   iso_datetime: a datetime with an offset, the output is the instant in UTC with milliseconds
#   { iso_datetime => { min => ..., max => ... } }: a datetime, a date or "today", "yesterday",
#   "tomorrow". A date is its first millisecond as "min" and its last one as "max"
our sub iso_datetime(@args, %builders) {
    my ($min, $max);

    with options-argument('iso_datetime', @args) -> $options {
        check-options('iso_datetime', $options);

        # Milliseconds, or a day relative to the current date as a Pair
        my sub parse-bound(Str $option) {
            my $bound = $options{$option};
            return Nil unless $options{$option}:exists;

            if $bound ~~ Str:D {
                my $end-of-day = $option eq 'max' ?? DAY-MS - 1 !! 0;
                return 'relative' => %RELATIVE-DAYS{$bound} if %RELATIVE-DAYS{$bound}:exists;
                with date-to-day($bound) { return $_ * DAY-MS + $end-of-day }

                # Any year: a bound is only compared, never written out
                with datetime-to-ms($bound) { return $_ }
            }

            wrong-bound('iso_datetime', $option, $bound);
        }

        $min = parse-bound('min');
        $max = parse-bound('max');

        # Fixed bounds are cut to milliseconds already
        check-bound-order('iso_datetime', $min, $max);
    }

    my $is-relative = $min ~~ Pair || $max ~~ Pair;

    return sub ($value, $all-values, $output is rw) {
        return unless $value.defined;
        return 'FORMAT_ERROR' unless $value ~~ Str || $value ~~ Real;
        return 'WRONG_DATETIME' unless $value ~~ Str;
        return if $value eq '';

        my $ms = datetime-to-ms($value) // return 'WRONG_DATETIME';
        my $utc = ms-to-utc($ms) // return 'WRONG_DATETIME';

        if $min.defined || $max.defined {
            # One clock read per value
            my $today = $is-relative ?? today() !! 0;
            my $min-ms = $min ~~ Pair ?? ($today + $min.value) * DAY-MS !! $min;
            my $max-ms = $max ~~ Pair ?? ($today + $max.value + 1) * DAY-MS - 1 !! $max;

            return 'DATETIME_TOO_EARLY' if $min-ms.defined && $ms < $min-ms;
            return 'DATETIME_TOO_LATE' if $max-ms.defined && $ms > $max-ms;
        }

        $output = $utc;
        return;
    };
}

# "iso_time", or { iso_time => { min => ..., max => ... } }. With min greater than max the
# range goes over midnight: { min => "22:00", max => "06:00" } accepts 23:00 and 05:00
our sub iso_time(@args, %builders) {
    my ($min, $max);

    with options-argument('iso_time', @args) -> $options {
        check-options('iso_time', $options);

        my sub parse-bound(Str $option) {
            my $bound = $options{$option};
            return Nil unless $options{$option}:exists;

            if $bound ~~ Str:D {
                with time-to-ns($bound) { return $_ }
            }

            wrong-bound('iso_time', $option, $bound);
        }

        $min = parse-bound('min');
        $max = parse-bound('max');
    }

    my $is-over-midnight = $min.defined && $max.defined && $min > $max;

    return sub ($value, $all-values, $output is rw) {
        return unless $value.defined;
        return 'FORMAT_ERROR' unless $value ~~ Str || $value ~~ Real;
        return 'WRONG_TIME' unless $value ~~ Str;
        return if $value eq '';

        my $time = time-to-ns($value) // return 'WRONG_TIME';

        if $is-over-midnight {
            return if $time >= $min || $time <= $max;

            # In the gap between max and min: the error of the nearer bound,
            # TIME_TOO_EARLY exactly in the middle
            return $time - $max < $min - $time ?? 'TIME_TOO_LATE' !! 'TIME_TOO_EARLY';
        }

        return 'TIME_TOO_EARLY' if $min.defined && $time < $min;
        return 'TIME_TOO_LATE' if $max.defined && $time > $max;
        return;
    };
}
