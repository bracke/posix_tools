# sleep

## Name
`sleep` - suspend execution for an interval.

## Synopsis
`sleep time...`

## Description
Suspends execution for the sum of the supplied non-negative decimal time operands.

## Operands
`time`: non-negative decimal number of seconds.

## Options
Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
No data output on success.

## Standard Error
Diagnostics for invalid usage.

## Exit Status
`0` success, `2` invalid usage, `125` internal failure.

## Behavioral Details
Fractional seconds are accepted. Excessively large durations are rejected.

## Locale Behavior
Help and diagnostics are localized; duration syntax is not localized.

## Implementation-Defined Choices
Durations are parsed with `.` as the decimal separator.

## Extensions
Fractional operands, multiple operands, `--help`, `--version`, `--posix-tools-identify`.

## Examples
`sleep 0.5`

## Conformance Status
Conforming with extensions tracked by `SLEEP-POSIX-001`.

## Known Limitations
No suffix units are implemented in V1.
