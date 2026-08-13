# tee

## Name
`tee` - duplicate standard input.

## Synopsis
`tee [-ai] [--] [file...]`

## Description
Copies standard input to standard output and each named file.

## Operands
`file`: output file path.

## Options
`-a` appends to files. `-i` ignores interrupt signals while `tee` is running on hosts that provide interrupt signal
disposition through hostkit. `--` ends option recognition. Options are recognized before the first file operand; later
option-like words are file operands. Project extensions `--help`, `--version`, and `--posix-tools-identify` are
recognized.

## Standard Input
Input bytes to duplicate.

## Standard Output
Copied input bytes.

## Standard Error
Diagnostics for invalid usage and output failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Options are validated before standard input is read. Input is copied in bounded chunks to standard output and each
active file operand. File-output failures are reported once per failed operand while standard output still receives
readable input data when it can be written. A standard-input read failure returns operational failure after any readable
prefix has been copied.

## Locale Behavior
Copied data is not localized. Help and diagnostics are localized.

## Implementation-Defined Choices
On hosts without POSIX interrupt signals, `-i` has no signal disposition to change.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`tee copy.txt`

## Conformance Status
Conforming with extensions tracked by `TEE-POSIX-001`.

## Known Limitations
No known V1 limitations beyond host I/O behavior exposed through the shared command context.
