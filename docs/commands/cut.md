# cut

## Name
`cut` - select bytes, characters, or fields from lines.

## Synopsis
`cut -b list [-n] [--] [file...]`
`cut -c list [--] [file...]`
`cut -f list [-d char] [-s] [--] [file...]`

## Description
Writes selected portions of each input line.

## Operands
`file`: input file path. `-` reads standard input.

## Options
`-b list` selects byte positions. `-n` with `-b` does not split characters: as POSIX specifies, the low end of each
range moves back to the first byte of its character, the high end moves back to the last byte of the character before
one it would split, and a range left empty is dropped. `-c list` selects character positions. `-f list` selects delimiter-separated
fields. `-d char` selects the field delimiter. `-s` suppresses lines without delimiters in field mode. Project
extensions `--help`, `--version`, and `--posix-tools-identify` are recognized. The end-of-options marker `--` is
accepted.

## Standard Input
Used when no files are supplied or when an operand is `-`.

## Standard Output
Selected line portions, preserving line delimiters.

## Standard Error
Diagnostics for invalid usage and input failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Lists accept one-based numbers, open-ended ranges, and closed ranges separated by commas, blanks, or tabs.
Exactly one of `-b`, `-c`, or `-f` may be selected. Supplying more than one list mode is invalid usage.
The delimiter option `-d` and suppression option `-s` are valid only with field mode `-f`.

## Locale Behavior
The character-classification locale (`LC_ALL`, then `LC_CTYPE`, then `LANG`) selects whether `-c` and `-n` see
UTF-8 characters or bytes.
Data output is not localized. Help and diagnostics are localized.

## Implementation-Defined Choices
Characters are UTF-8 in every locale except `C` and `POSIX` without a UTF-8 codeset, where each byte is a character, so
`-c` equals `-b` and `-n` has no effect there. A byte that does not start a valid UTF-8 sequence counts as one
character. Selected bytes are written unchanged.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`cut -f 2 -d , data.csv`

## Conformance Status
Conforming with extensions. Requirement coverage is tracked by `CUT-POSIX-001` and `CUT-POSIX-002`.

## Known Limitations
None for the implemented V1 supported surface.
