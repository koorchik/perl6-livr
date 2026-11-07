# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Raku implementation of the LIVR spec (Language Independent Validation Rules, http://livr-spec.org). The distribution is named `LIVR` and has no runtime dependencies. `JSON::Tiny` is needed only by the tests.

## Commands

Run all commands from the repository root: `t/01-livr-test-suite.t` finds its data through `$*CWD/t`.

```sh
zef install --deps-only .        # install test-depends (JSON::Tiny)
prove -e 'raku -Ilib' t          # run all tests
raku -Ilib t/09-like-string-regexes.t   # run one test file
zef test .                       # what CI runs
mi6 test                         # runs `mi6 build` first, which can rewrite META6.json
```

CI (`.github/workflows/test.yml`) tests on Rakudo 2024.02 (the old compiler) and the latest Rakudo (the RakuAST compiler). Code has to work on both. For example, RakuAST does not support Perl 5 regexes (`:P5`).

## Architecture

- **Rule registry.** `lib/LIVR.rakumod` only maps rule names to builder subs from `LIVR::Rules::*` and registers them with `LIVR::Validator.register-default-rules`. Code that does `use LIVR::Validator` without `use LIVR` gets no built-in rules. Default rules are class-level; a registration replaces the default rules hash, so existing validators keep the rules they were created with. A validator shares the default rules, and a nested validator shares the rules of its parent (`register-rules` with the parent's `%builders` does not copy them); the rules are copied only when `register-rules`, `register-aliased-rule` or `get-rules` is called on the validator, so these change only that instance. The LIVR 2.5 rules of `LIVR::Rules::Dates`, `List`, `Format` and `Checksum` are loaded on first use (`lazy-rule` in `lib/LIVR.rakumod`), to keep `use LIVR` fast.
- **Rule contract.** A rule builder is `sub (@args, %builders)` and returns a closure `sub ($value, $all-values, $output is rw)`. The closure returns an error code string (or a nested errors structure), or nothing on success. It can change the value by assigning `$output`. Rules other than `required`/`not_empty*` (and `required_if`, `when`, `any`) return early for empty values (`is-no-value` in `LIVR::Utils`), so a field is optional unless it has `required`. `$all-values` is the containing object of the field. LIVR 2.0 rules ignore extra arguments (sub-signatures like `[Int $max-length, *@]` or `@`) and keep their own argument types. LIVR 2.5 rules die on wrong arguments (schema errors), ignore the arguments after the ones they take, and accept a number for a string argument and a string with a number for a number argument (`string-argument`, `number-argument`) and use the `:internal` helpers of `LIVR::Utils` (`string-form`, `parse-reference`...). A Bool is an Int in Raku: check `Bool` before `Real`. The engine passes `{ rule => Any }` (JSON `null`) as `[Any]`, as in 2.0: one argument, so the 2.5 rules die on it (`no-arguments` too), the 2.0 rules and custom rules handle it as in 2.0, and `{ iso_date => Any }` is the plain `iso_date` (2.0 ignored its arguments). Raku strings are NFG, so the spec's comparison without Unicode normalization (2.3) does not hold: `"e\x[301]" eq "\x[e9]"` is true, and a JSON decoder already composes them.
- **Validation flow.** `prepare` (called lazily by `validate`) builds every field's validators once. `validate` runs a field's rules in order: each rule receives the previous rule's output, and the first error stops that field. Fields without rules are left out of the result. On failure `validate` returns nothing, and `.errors` holds `field => code`, or `'FORMAT_ERROR'` if the input is not a Hash.
- **Meta rules and aliases** (`LIVR::Rules::Meta`, `!build-aliased-rule`) build nested `LIVR::Validator` instances and pass on `%builders`, so custom rules also work inside `nested_object`, `list_of`, `or`, aliases and the other meta rules. `field-rule` returns the rules of one field as one rule closure. Aliases, `or` and `when` pass the containing object to it (they are transparent), `list_of`, `values` and `keys` pass an empty `Map`.
- **The clock** (LIVR 2.5): the relative bounds `today`, `yesterday`, `tomorrow` of `LIVR::Rules::Dates` read `time` on every check, in UTC (`now` costs 10 times more). There is no clock option: tests fix the time by wrapping `&term:<time>` (`t/01-livr-test-suite.t` does it for `options.json`, `t/10-livr-2.5.t` for its own tests).
- **`like` regexes.** `LIVR::Regex::translate-regex` translates JavaScript/PCRE-style regex strings, as the spec requires, into Raku regex source. Every literal character is escaped, so a pattern can't inject Raku code. Unsupported syntax dies when the rule is built. `LIVR::Rules::String` caches the compiled regexes behind a lock, capped at 1000 entries. A native Raku `Regex` is used as is.

## Tests

`t/test_suite/` and `t/test_suite_2.5/` are copied from the upstream LIVR spec repository (linked under "BUGS" in `README.md`). They contain the language-independent JSON cases (`positive`, `negative`, `aliases_positive`, `aliases_negative`); each case is a directory with `rules.json`, `input.json`, and `output.json` or `errors.json`, and in 2.5 `options.json` with `now`, the current time. `test_suite_2.5/schema_errors/` has schemas that must not build. `t/01-livr-test-suite.t` runs both; it compares 2.5 results as JSON values (numbers by value; plain `eqv` passes too now that the suite writes numbers as they come in the input). To update them, copy them again from upstream. When a case fails, change the rules, not the suite.

## Releasing

Releases go to the Zef ecosystem through fez, using `mi6 release` (`dist.ini` has `[UploadToZef]`). Earlier versions were released to CPAN.

- `auth` in `META6.json` has to match the fez login.
- `mi6 build` regenerates `provides` in `META6.json` from `lib/`, so run it after adding or renaming a module.
- `README.md` is written by hand: `ReadmeFromPod` is disabled in `dist.ini`.
- Put new entries in `Changes` under `{{$NEXT}}`, indented. `mi6 release` replaces that line with the version and the date.
- `mi6 release` runs the tests, uploads, commits, and creates and pushes the version tag (for example `2.2.0`).
