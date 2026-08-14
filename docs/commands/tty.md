# tty

## Name

tty - write the terminal name connected to standard input

## Synopsis

`tty [-s]`

## Description

`tty` reports whether standard input is a terminal.

## Operands

None.

## Options

`-s`

Silent mode. Suppress output and use only the exit status.

## Standard Input

Inspected to determine whether it is a terminal.

## Standard Output

The terminal name followed by a newline, or `not a tty` followed by a newline when standard input is not a
terminal. Silent mode writes nothing.

## Standard Error

Diagnostics are written to standard error.

## Exit Status

`0` when standard input is a terminal. `1` when it is not. `2` for invalid usage.

## Behavioral Details

V1 reports `/dev/tty` for terminal standard input through the portable host adapter.

## Locale Behavior

Help and diagnostics are locale-dependent through `messages`. Command data output is not localized.

## Implementation-Defined Choices

The terminal pathname is the V1 portable adapter name `/dev/tty`.

## Extensions

`--help`, `--version`, and `--posix-tools-identify` are project extensions.

## Examples

`tty`

## Conformance Status

Conforming with extensions for the implemented POSIX.1-2024 surface.

## Known Limitations

V1 does not query a platform-specific controlling terminal device pathname beyond the portable `/dev/tty`
adapter name.
