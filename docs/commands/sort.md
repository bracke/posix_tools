# sort

## Name
`sort` - sort text lines.

## Synopsis
`sort [-bCcdfimnrsu] [-k keydef] [-o output] [-t char] [--] [file...]`

## Description
Reads input lines, sorts them with the selected locale's deterministic collation keys, and writes the sorted lines.

## Operands
`file`: input file path.

## Options
`-b` ignores leading blanks for comparisons. `-c` checks that input is already sorted and writes no sorted output. `-C`
performs the same sortedness check in silent mode. `-d` compares only blanks and ASCII alphanumeric bytes. `-f` folds
UTF-8 Unicode case mappings, including multi-code-point special mappings used by the release collation data, before
comparisons. `-i` ignores nonprinting bytes in comparison keys. `-k
keydef` selects a field range
for comparison; this increment accepts positive field numbers with optional one-based byte character offsets and
per-key `b`, `d`, `f`, `i`, `n`, and `r` modifiers as `start[.char][opts][,end[.char][opts]]`. `-n` compares the first signed decimal or exponent decimal field in the selected key after leading blanks, using the effective locale's decimal separator, signs, and digit glyphs where available through `i18n`. `-m` accepts presorted input
for merge-mode use and emits the sorted merge result through the same in-memory ordering path. `-r` reverses output
order. `-t char` selects a single-byte field separator for `-k`. `-u` suppresses duplicate sorted lines and makes check
mode reject adjacent equal sort keys. `-s` preserves input order for otherwise equal sort keys, including equal numeric
keys. `-o output` writes results to a file. Project extensions `--help`, `--version`, and
`--posix-tools-identify` are recognized. Options are recognized before the first file operand; later option-like words
are file operands. The end-of-options marker `--` is accepted.

## Standard Input
Used when no files are supplied.

## Standard Output
Sorted lines.

## Standard Error
Diagnostics for invalid usage and input failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
The current implementation performs an in-memory sort. `-b` removes leading spaces and horizontal tabs from comparison
keys without changing emitted line bytes. Check mode uses the same comparison rules as output mode. `-d` drops
nonblank, nonalphanumeric ASCII bytes from comparison keys without changing emitted line bytes. `-f` applies
deterministic UTF-8 Unicode case folding, including compatibility mappings such as Kelvin sign, Angstrom sign, sharp-s,
final sigma, and Latin ligatures, before comparisons. `-i` drops bytes outside ASCII `0x20`
through `0x7e` from
comparison keys without changing emitted line bytes. `-n` implements signed decimal integer, fractional, and exponent
comparison for the selected key, canonicalizing localized numeric signs, decimal separators, and digit glyphs through
the shared `i18n` CLDR data before comparison. It falls back to lexical order for equal numeric values. Without `-t`, sort fields are
blank-delimited after leading blanks; with `-t`, consecutive separators create empty fields. Multiple `-k` operands are
applied as priority keys in command-line order. Per-key modifiers map to the same deterministic comparison policies as
the corresponding global options. `-s` disables the lexical
fallback for equal numeric values and preserves their input order. An operand exactly equal to `-` reads standard input.

## Locale Behavior
Sorted data uses deterministic `i18n` collation keys for supported non-default locales, with project release-locale
tailoring preserved where the command conformance data defines it. `C`, `POSIX`, and unknown locales fall back to
bytewise Ada string ordering. Help and diagnostics are localized.

## Implementation-Defined Choices
Dictionary order and nonprinting classification are ASCII-only. Key definitions support field numbers, one-based byte
character offsets, multiple key priority levels, and per-key comparison modifiers. Numeric sorting accepts signed
decimal integer, fractional, and exponent prefixes using ASCII numeric syntax plus locale numeric syntax exposed by the
shared `i18n` CLDR data. Locale collation metadata is deterministic project data from `i18n`, not a runtime import of
the host locale database.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`sort names.txt`

## Conformance Status
Conforming with extensions. Requirement coverage is tracked by `POSIX-SORT-001`.

## Known Limitations
None for the implemented V1 supported surface.
