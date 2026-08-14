# seq

## Name

seq - write a finite numeric sequence.

## Synopsis

`seq last`

`seq first last`

`seq first increment last`

`seq [-w] [-s separator] [-f format] last`

## Description

`seq` writes a finite sequence of signed decimal numbers. Decimal operands may use exponent notation. It is a project
extension and is not part of the POSIX.1-2024 utility baseline.

## Operands

`first`: first value. Defaults to 1.

`increment`: sequence increment. Defaults to 1 and must not be zero.

`last`: final bound.

## Options

`-f format`: format each generated value using a bounded printf-style decimal conversion. Supported conversions are
`%f`, `%F`, `%g`, and `%G` with optional zero-padded field width and precision.

`-s separator`: write `separator` between generated values. The default separator is LF.

`-w`: equalize generated value width with leading zeroes when no explicit format is supplied.

Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input

Not read.

## Standard Output

Generated values are written as ASCII decimal data. A final LF is always written after the sequence.

## Standard Error

Diagnostics are written for invalid operand counts, invalid numbers, zero increment, invalid options, and output failures.

## Exit Status

0 success, 1 output failed, 2 invalid usage, 125 internal failure.

## Behavioral Details

Positive increments stop after the next value would exceed `last`. Negative increments stop after the next value would be
less than `last`. Decimal operands are represented with fixed-scale integer arithmetic derived from the supplied
operands, so simple decimal sequences such as `0.1 0.1 0.3` and `1e-1 1e-1 3e-1` are deterministic. Arithmetic is
checked and overflow stops after the last representable value.

## Locale Behavior

Help and diagnostics are localized. Generated numeric data is not localized.

## Implementation-Defined Choices

Supported decimal precision is bounded by the project wide integer range after exponent normalization and scaling.

## Extensions

The entire command is a project extension. `--help`, `--version`, and `--posix-tools-identify` are also extensions.

## Examples

`seq 3`

`seq 5 -2 1`

`seq 0.1 0.1 0.3`

`seq 1e1 5e0 2e1`

`seq -s , 1 3`

`seq -w 8 10`

`seq -f 'n=%04.1f' 1 1 3`

## Conformance Status

Non-POSIX extension tracked by SEQ-EXT-001.

## Known Limitations

Arbitrary locale-dependent numeric formatting is not implemented.
