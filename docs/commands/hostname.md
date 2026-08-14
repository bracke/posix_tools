# hostname

## Name

hostname - write the current host node name

## Synopsis

`hostname`

## Description

`hostname` writes the host node name reported by the posix_tools host adapter.

## Operands

No operands are accepted.

## Options

Only common project options such as `--help`, `--version`, and the internal identity option are recognized by the
process wrapper.

## Standard Input

Not used.

## Standard Output

The node name followed by a newline.

## Standard Error

Diagnostics are localized through messages.

## Exit Status

`0` on success, `1` when the platform cannot provide a node name, `2` for invalid operands, and `125` for unexpected
internal failures at the command boundary.

## Behavioral Details

The command does not change the host name. It only reports the current name.

## Locale Behavior

Command data output is locale-invariant. Help and diagnostics are locale-dependent.

## Implementation-Defined Choices

The value is the hostkit node-name result for the active platform.

## Extensions

The command supports project-wide help, version, and identity operations.

## Examples

`hostname`

## Conformance Status

Project extension.

## Known Limitations

Setting host names is intentionally not implemented.
