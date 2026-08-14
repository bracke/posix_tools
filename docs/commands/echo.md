# echo

## Name
`echo` - write arguments separated by spaces.

## Synopsis
`echo [string...]`

## Description
Writes operands separated by exactly one space and followed by one LF.

## Operands
`string`: text written as data.

## Options
`-n` is ordinary data. `--help`, `--version`, and
`--posix-tools-identify` are recognized only as the sole argument.

## Standard Input
Not used.

## Standard Output
Operand data and final LF.

## Standard Error
Only unexpected boundary diagnostics.

## Exit Status
`0` success, `1` output failure, `125` internal failure.

## Behavioral Details
Backslashes and `-n` are ordinary operand data. This deterministic behavior is the project policy for the POSIX.1-2024
implementation-defined echo cases.

## Locale Behavior
Command data output is not localized.

## Implementation-Defined Choices
The project deliberately chooses deterministic no-escape behavior instead of selecting GNU, BSD, shell-builtin, or XSI
compatibility modes.

## Extensions
Sole-argument `--help`, `--version`, `--posix-tools-identify`.

## Examples
`echo hello world`

## Conformance Status
Conforming with extensions for V1 behavior tracked in `generated/requirements.csv`.

## Known Limitations
No separate GNU, BSD, shell-builtin, or XSI compatibility mode is provided; those implementation-defined cases use the
deterministic project behavior described above.
