# arch

## Name

arch - write the machine hardware name

## Synopsis

`arch`

## Description

`arch` writes the host machine class reported by the posix_tools host adapter.

## Operands

No operands are accepted.

## Options

Only common project options such as `--help`, `--version`, and the internal identity option are recognized by the
process wrapper.

## Standard Input

Not used.

## Standard Output

The machine class followed by a newline.

## Standard Error

Diagnostics are localized through messages.

## Exit Status

`0` on success, `2` for invalid operands, and `125` for unexpected internal failures at the command boundary.

## Behavioral Details

The value is obtained from hostkit through the posix_tools host adapter. It is not localized.

## Locale Behavior

Command data output is locale-invariant. Help and diagnostics are locale-dependent.

## Implementation-Defined Choices

This is a project extension command and follows the hostkit machine-name mapping for each supported platform.

## Extensions

The command supports project-wide help, version, and identity operations.

## Examples

`arch`

## Conformance Status

Project extension.

## Known Limitations

The exact machine class spelling is hostkit-defined.
