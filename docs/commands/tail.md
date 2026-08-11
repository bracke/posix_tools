# tail

## Name
`tail` - copy the last part of files.

## Synopsis
`tail [file...]`

`tail -n number [file...]`

`tail -c number [file...]`

`tail -f [file...]`

## Description
Copies a suffix of each input in line or byte mode. The default is ten lines
from the end.

## Operands
`file`: input file path or `-` for standard input.

## Options
- `-n number`: line count.
- `-c number`: byte count.
- `-f`: continue copying bytes appended to followed file operands after the
  selected initial suffix.

## Standard Input
Used when no files are present or when an operand is `-`.

## Standard Output
Selected bytes, with deterministic multi-file headers when required.

## Standard Error
Diagnostics for invalid counts, unreadable inputs, and resource failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Plus-prefixed counts are preserved as from-start requests. Compact forms such
as `-n+2` and `-c2` are recognized. LF (`0A`) is the line delimiter.

Accepted count forms are `-n number`, `-c number`, and V1 compact forms
`-nnumber` and `-cnumber`. A plus prefix selects origin from start; otherwise
the count is from the end. Repeated count options are accepted before the first
file operand; the last mode, origin, and count in that option prefix are used.
Zero is accepted. Empty counts, a lone plus, negative counts, non-decimal
syntax, embedded whitespace, and numeric overflow are rejected before file
processing. `--` ends option processing when it appears where the next file
operand would be.

## Locale Behavior
Copied data and headers are not localized in V1.

## Implementation-Defined Choices
Suffix retention uses a 16 MiB in-memory threshold. Larger byte and line suffix
processing spills to host-backed temporary storage using hostkit descriptors up
to the configured 1 GiB spill limit; requests or inputs that exceed that limit
fail with a resource diagnostic and no partial suffix output.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`tail -f -n 10 file`

`tail -n +2 file`

## Conformance Status
Conforming with extensions.

## Known Limitations
No `-F` or `--follow` support in V1.
