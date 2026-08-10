# true

## Name
`true` - return a successful status.

## Synopsis
`true [operand...]`

## Description
Ignores ordinary operands, writes no ordinary output, and returns status `0`.

## Operands
Ignored.

## Options
`--help`, `--version`, and `--posix-tools-identify` are recognized only as the
sole argument.

## Standard Input
Not used.

## Standard Output
No ordinary output.

## Standard Error
No ordinary diagnostic for operands.

## Exit Status
`0` success, `125` internal failure.

## Behavioral Details
Option-like operands are ignored unless one recognized extension is the sole
argument.

## Locale Behavior
Only help text is localizable.

## Implementation-Defined Choices
None for normal behavior.

## Extensions
Sole-argument `--help`, `--version`, `--posix-tools-identify`.

## Examples
`true ignored`

## Conformance Status
Partially conforming pending full platform validation.

## Known Limitations
None for V1 normal behavior.
