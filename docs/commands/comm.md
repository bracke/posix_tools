# comm

## Name
`comm` - compare two sorted files line by line.

## Synopsis
`comm [-123] [--] file1 file2`

## Description
Reads two sorted text files and writes three logical columns for lines unique to the first file, unique to the second
file, and common to both files.

## Operands
`file1`, `file2`: sorted input paths. `-` reads standard input.

## Options
`-1`, `-2`, and `-3` suppress the corresponding columns. Project extensions `--help`, `--version`, and
`--posix-tools-identify` are recognized. The end-of-options marker `--` is accepted.

## Standard Input
Used for an operand exactly equal to `-`.

## Standard Output
Merged lines with tab-prefixed columns.

## Standard Error
Diagnostics for invalid usage and input failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Input is compared using deterministic lexical string ordering.

## Locale Behavior
Data output is not localized. Help and diagnostics are localized.

## Implementation-Defined Choices
The current comparison order is bytewise Ada string ordering for this command.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`comm old.sorted new.sorted`

## Conformance Status
Conforming with extensions. Requirement coverage is tracked by `COMM-POSIX-001`.

## Known Limitations
None for the implemented V1 supported surface.
