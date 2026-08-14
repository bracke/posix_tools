# seq

## Name

seq - write a finite integer sequence.

## Synopsis

`seq last`

`seq first last`

`seq first increment last`

## Description

`seq` writes a finite sequence of signed decimal integers, one per line. It is a project extension and is not part of the
POSIX.1-2024 utility baseline.

## Operands

`first`: first value. Defaults to 1.

`increment`: sequence increment. Defaults to 1 and must not be zero.

`last`: final bound.

## Options

No command-specific options are supported. Project extensions `--help`, `--version`, and `--posix-tools-identify` are
recognized.

## Standard Input

Not read.

## Standard Output

Each generated integer is written as ASCII decimal followed by LF.

## Standard Error

Diagnostics are written for invalid operand counts, invalid integers, zero increment, and output failures.

## Exit Status

0 success, 1 output failed, 2 invalid usage, 125 internal failure.

## Behavioral Details

Positive increments stop after the next value would exceed `last`. Negative increments stop after the next value would be
less than `last`. Arithmetic is checked and overflow stops after the last representable value.

## Locale Behavior

Help and diagnostics are localized. Generated numeric data is not localized.

## Implementation-Defined Choices

Only signed integer sequences are implemented in V1.

## Extensions

The entire command is a project extension. `--help`, `--version`, and `--posix-tools-identify` are also extensions.

## Examples

`seq 3`

`seq 5 -2 1`

## Conformance Status

Non-POSIX extension tracked by SEQ-EXT-001.

## Known Limitations

Floating-point operands, custom separators, equal-width output, and printf-style formatting are not implemented in V1.
