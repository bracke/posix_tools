# which

## Name

which - locate executable operands

## Synopsis

`which command...`

## Description

`which` writes the executable path located for each operand through the posix_tools executable-search adapter.

## Operands

Each operand is a command name to locate.

## Options

`--` may be used to end option recognition. Common project options such as `--help`, `--version`, and the internal
identity option are recognized by the process wrapper.

## Standard Input

Not used.

## Standard Output

Located executable paths, one per line.

## Standard Error

Diagnostics are localized through messages.

## Exit Status

`0` when every requested command is located and output succeeds, `1` when any requested command is missing or output
fails, `2` for invalid usage, and `125` for unexpected internal failures at the command boundary.

## Behavioral Details

Search behavior follows hostkit executable discovery. The command does not invoke located programs.

## Locale Behavior

Located path output is locale-invariant. Help and diagnostics are locale-dependent.

## Implementation-Defined Choices

Path search and executable-suffix handling are hostkit-defined for the active platform.

## Extensions

`which` is a project extension command. The command supports project-wide help, version, and identity operations.

## Examples

`which posix-tools`

## Conformance Status

Project extension.

## Known Limitations

Shell functions, aliases, and shell built-ins are outside this command's search model.
