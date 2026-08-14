# head

## Name
`head` - copy the first part of files.

## Synopsis
`head [file...]`

`head -n number [file...]`

`head -c number [file...]`

## Description
Copies the first `number` LF-delimited lines or bytes from each input. The
default is ten lines.

## Operands
`file`: input file path or `-` for standard input.

## Options
`-n number`: number of lines to copy.

`-c number`: number of bytes to copy.

## Standard Input
Used when no files are present or when an operand is `-`.

## Standard Output
Selected input bytes, with deterministic multi-file headers when required.

## Standard Error
Diagnostics for invalid counts or unreadable inputs.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
LF (`0A`) is the line delimiter. Final partial lines are preserved without
adding LF.

Accepted count forms are `-n number`, `-c number`, and the V1 compact forms
`-nnumber` and `-cnumber`, where `number` is a non-negative decimal count.
Repeated count options are accepted before the first file operand; the last
count in that option prefix is used. Zero is accepted and produces no input
data. Empty counts, negative counts, leading-plus counts, non-decimal syntax,
embedded whitespace, and numeric overflow are rejected before file processing.
`--` ends option processing when it appears where the next file operand would be.

## Locale Behavior
Copied data and headers are not localized in V1.

## Implementation-Defined Choices
The compact `-nnumber` and `-cnumber` forms are accepted for compatibility and
recorded in the project conformance registry.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`head -n 5 file`

`head -c 80 file`

## Conformance Status
Conforming with extensions for V1 behavior tracked in `generated/requirements.csv`.

## Known Limitations
No known limitation for the documented V1 count modes.
