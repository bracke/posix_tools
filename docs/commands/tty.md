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

V1 asks hostkit for the terminal name of standard input. POSIX hosts use a ttyname-style pathname when the host returns
one. Windows console handles report the stable conventional name `CON`. If the host confirms that standard input is a
terminal but cannot provide a name, the adapter falls back to `/dev/tty`.

## Locale Behavior

Help and diagnostics are locale-dependent through `messages`. Command data output is not localized.

## Implementation-Defined Choices

Terminal naming follows the hostkit descriptor adapter for the selected platform.

## Extensions

`--help`, `--version`, and `--posix-tools-identify` are project extensions.

## Examples

`tty`

## Conformance Status

Conforming with extensions for the implemented POSIX.1-2024 surface.

## Known Limitations

No known V1 limitation for the documented terminal-name surface beyond host capability reporting.
