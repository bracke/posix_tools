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
for merge-mode use and emits the sorted merge result through the same in-memory ordering path. `-r` reverses the comparison. `-t char` selects a single-byte field separator for `-k`. `-u` keeps only the first of each set of lines whose keys compare equal, using the same comparison as the ordering
(so `sort -nu` treats `1` and `01` as duplicates), and makes check mode reject adjacent equal sort keys. `-s` preserves
input order for lines whose keys compare equal. `-o output` writes results to a file and reports a file it cannot
write. Project extensions `--help`, `--version`, and
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
The current implementation performs an in-memory, stable merge sort in O(n log n) comparisons; each line's comparison
keys are built once before sorting. `-b` removes leading spaces and horizontal tabs from comparison
keys without changing emitted line bytes. Check mode uses the same comparison rules as output mode. `-d` drops
nonblank, nonalphanumeric ASCII bytes from comparison keys without changing emitted line bytes. `-f` applies
deterministic UTF-8 Unicode case folding, including compatibility mappings such as Kelvin sign, Angstrom sign, sharp-s,
final sigma, and Latin ligatures, before comparisons. `-i` drops bytes outside ASCII `0x20`
through `0x7e` from
comparison keys without changing emitted line bytes. `-n` implements signed decimal integer, fractional, and exponent
comparison for the selected key, canonicalizing localized numeric signs, decimal separators, and digit glyphs through
the shared `i18n` CLDR data before comparison. Numerically equal keys compare equal. Without `-t`, a sort field is a
maximal run of non-blanks together with the blanks before it, so leading blanks belong to the field and count toward
its character positions unless `-b` or a key's `b` modifier skips them; with `-t`, consecutive separators create empty
fields. Multiple `-k` operands are
applied as priority keys in command-line order. Per-key modifiers map to the same deterministic comparison policies as
the corresponding global options. As POSIX specifies, global ordering options apply to every key that has none of its
own, and a key with any modifier (`b`, `d`, `f`, `i`, `n`, or `r`) uses only its own, so `sort -r -k2n` does not
reverse that key. When all keys compare equal, lines are ordered as if no `-d`, `-f`, `-i`, `-n`, or `-k` were given,
with all bytes significant and `-r` still in effect: first by the locale collation of the whole line, then by bytes.
`-s` and `-u` disable that last-resort comparison. `-r` is part of the comparison rather than a reversal of the sorted
output, so lines with equal keys keep their input order under `-s -r`. An operand exactly equal to `-` reads standard input.

## Locale Behavior
Sorted data uses deterministic `i18n` collation keys for supported non-default locales, with project release-locale
tailoring preserved where the command conformance data defines it. `C` and `POSIX`, in any letter case and with any codeset, and unknown locales use bytewise ordering. Help and diagnostics are localized.

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
