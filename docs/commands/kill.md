# kill

## Name
`kill` - send a signal to processes.

## Synopsis
`kill [-s signal_name] pid...`

## Description
Sends the selected signal to each process identifier.

## Operands
`pid`: decimal process identifier.

## Options
`-s signal_name` selects a signal. `-l` lists supported signal names. `-signal` selects a signal by name or number.
Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
Signal names when `-l` is selected.

## Standard Error
Diagnostics for invalid usage and failed signal delivery.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Signals are resolved and delivered through hostkit. No shell is invoked.

## Locale Behavior
Help and diagnostics are localized; signal names are stable host/project data.

## Implementation-Defined Choices
The supported signal set is the portable set exposed by hostkit.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`kill -s TERM 12345`

## Conformance Status
Conforming with extensions tracked by `KILL-POSIX-001`.

## Known Limitations
Signal availability is platform dependent.
