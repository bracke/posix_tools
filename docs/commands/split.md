# split

## Name
`split` - split a file into pieces.

## Synopsis
`split [-a suffix_length] [-l line_count] [-b byte_count] [--] [file [name]]`

## Description
Splits input into files with alphabetic suffixes.

## Operands
`file`: input file path. `-` reads standard input. `name`: output prefix, defaulting to `x`.

## Options
`-a suffix_length` selects the generated suffix width. `-l line_count` selects lines per output file. `-b byte_count`
selects bytes per output file. Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.
The end-of-options marker `--` is accepted.

## Standard Input
Used when no input file is supplied or when the input operand is `-`.

## Standard Output
Not used for normal data output.

## Standard Error
Diagnostics for invalid usage and input or output failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Output files use lowercase alphabetic suffixes beginning at `aa`, or at the equivalent all-`a` value for a selected
suffix length. Suffix exhaustion is diagnosed before an output filename can wrap and overwrite an earlier part.

## Locale Behavior
Data output is not localized. Help and diagnostics are localized.

## Implementation-Defined Choices
`-b` takes precedence over `-l` when both are supplied. Suffix lengths above 12 are rejected as resource-impractical.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`split -l 100 input part-`
`split -a 3 -l 100 input part-`

## Conformance Status
Conforming with extensions. Requirement coverage is tracked by `SPLIT-POSIX-001`.

## Known Limitations
None for the implemented V1 supported surface.
