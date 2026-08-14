# sleep

## Name
`sleep` - suspend execution for an interval.

## Synopsis
`sleep time...`

## Description
Suspends execution for the sum of the supplied non-negative decimal time operands.

## Operands
`time`: non-negative decimal number of seconds with optional suffix `s`, `m`, `h`, or `d`.

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
Fractional values are accepted. Unsuffixed values and `s` are seconds, `m` is minutes, `h` is hours, and `d` is days.
Excessively large durations are rejected.

## Locale Behavior
Help and diagnostics are localized; duration syntax is not localized.

## Implementation-Defined Choices
Durations are parsed with `.` as the decimal separator.

## Extensions
Fractional operands, multiple operands, suffix units, `--help`, `--version`, `--posix-tools-identify`.

## Examples
`sleep 0.5`

`sleep 1m`

## Conformance Status
Conforming with extensions tracked by `SLEEP-POSIX-001`.

## Known Limitations
None known for the implemented V1 surface.
