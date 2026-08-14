# realpath

## Name
`realpath` - write resolved pathnames.

## Synopsis
`realpath [--] file...`

## Description
Writes the resolved absolute pathname for each operand.

## Operands
`file`: path to resolve.

## Options
`--` ends option recognition. Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
One resolved pathname per operand.

## Standard Error
Diagnostics for invalid usage and resolution failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Path resolution is delegated to hostkit so platform-specific canonicalization remains outside command code.

## Locale Behavior
Help and diagnostics are localized; path data is not localized.

## Implementation-Defined Choices
Each operand must resolve successfully to produce a result line.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`realpath .`

## Conformance Status
Conforming with extensions tracked by `REALPATH-POSIX-001`.

## Known Limitations
Resolution behavior for inaccessible parent directories is host dependent.
