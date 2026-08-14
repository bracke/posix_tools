# cksum

## Name
`cksum` - write CRC checksums and byte counts.

## Synopsis
`cksum [--] [file...]`

## Description
Computes the POSIX CRC checksum and byte length for each input.

## Operands
`file`: input file path. `-` reads standard input.

## Options
Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized. The end-of-options marker `--`
is accepted.

## Standard Input
Used when no files are supplied or when an operand is `-`.

## Standard Output
One checksum line per input.

## Standard Error
Diagnostics for invalid usage and input failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
The checksum is calculated over bytes without decoding text.

## Locale Behavior
Data output is not localized. Help and diagnostics are localized.

## Implementation-Defined Choices
Repeated standard-input operands consume the stream in order without rewind.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`cksum file.bin`

## Conformance Status
Conforming with extensions. Requirement coverage is tracked by `CKSUM-POSIX-001`.

## Known Limitations
None for the implemented V1 supported surface.
