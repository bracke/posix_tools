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
`-b list` selects byte positions. `-n` is accepted with byte mode and is a no-op under the V1 byte-preserving policy.
`-c list` selects character positions under the byte-preserving V1 policy. `-f list` selects delimiter-separated
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

## Locale Behavior
Data output is not localized. Help and diagnostics are localized.

## Implementation-Defined Choices
Character mode currently selects byte positions to preserve deterministic behavior for arbitrary input bytes. `-n`
therefore has no additional effect when used with `-b`.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`cut -f 2 -d , data.csv`

## Conformance Status
Conforming with extensions. Requirement coverage is tracked by `CUT-POSIX-001`.

## Known Limitations
None for the implemented V1 supported surface.
