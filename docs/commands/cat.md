# cat

## Name
`cat` - concatenate files to standard output.

## Synopsis
`cat [file...]`

## Description
Copies each operand to standard output in order. With no operands, or with an
operand exactly equal to `-`, standard input is copied.

## Operands
`file`: input file path or `-` for standard input.

## Options
No POSIX formatting options are implemented in V1. Project extensions
`--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Used when no operands are present or when an operand is `-`.

## Standard Output
Input bytes copied unchanged.

## Standard Error
Diagnostics for files that cannot be read.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Binary data and invalid UTF-8 are preserved. Repeated `-` operands read the same
standard input stream without rewinding it.

## Locale Behavior
Copied data is not localized.

## Implementation-Defined Choices
Same-file output safety is not claimed for shell truncation before startup.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`cat file1 file2`

## Conformance Status
Partially conforming pending complete adapter/error tests.

## Known Limitations
File operands still use direct Ada stream files in the common library. Standard
input is read through the command context boundary.
