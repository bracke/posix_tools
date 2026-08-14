# paste

## Name
`paste` - merge corresponding lines of files.

## Synopsis
`paste [-s] [-d list] [--] [file...]`

## Description
Writes corresponding input lines from each file on one output line separated by delimiter bytes. Serial mode writes one
combined output line per input file.

## Operands
`file`: input file path. `-` reads standard input.

## Options
`-d list` supplies the delimiter list. `-s` selects serial mode. Project extensions `--help`, `--version`, and
`--posix-tools-identify` are recognized. The end-of-options marker `--` is accepted.

## Standard Input
Used when no files are supplied or when an operand is `-`.

## Standard Output
Merged lines separated by the selected delimiter bytes. The default delimiter is tab.

## Standard Error
Diagnostics for invalid usage and input failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
The command preserves input bytes except for inserted delimiter and LF separators.

## Locale Behavior
Data output is not localized. Help and diagnostics are localized.

## Implementation-Defined Choices
Missing rows in shorter inputs contribute empty fields. An empty delimiter list inserts no delimiter bytes.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`paste names values`
`paste -d, names values`
`paste -s names values`

## Conformance Status
Conforming with extensions. Requirement coverage is tracked by `PASTE-POSIX-001`.

## Known Limitations
None for the implemented V1 supported surface.
