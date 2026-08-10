# head

## Name
`head` - copy the first part of files.

## Synopsis
`head [file...]`

`head -n number [file...]`

## Description
Copies the first `number` LF-delimited lines from each input. The default is
ten lines.

## Operands
`file`: input file path or `-` for standard input.

## Options
`-n number`: number of lines to copy.

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

Accepted count forms are `-n number` and the V1 compact form `-nnumber`, where
`number` is a non-negative decimal count. Zero is accepted and produces no input
data. Empty counts, negative counts, leading-plus counts, non-decimal syntax,
embedded whitespace, and numeric overflow are rejected before file processing.
`--` ends option processing when it appears where the next file operand would be.

## Locale Behavior
Copied data and headers are not localized in V1.

## Implementation-Defined Choices
The compact `-nnumber` form is accepted for compatibility and recorded in the
project conformance registry.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`head -n 5 file`

## Conformance Status
Partially conforming pending full cross-platform validation.

## Known Limitations
Only mandatory line-count behavior is implemented.
