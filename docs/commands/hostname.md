# hostname

## Name

hostname - write or set the current host node name

## Synopsis

`hostname`

`hostname name`

## Description

`hostname` writes the host node name reported by the posix_tools host adapter. With one operand it attempts to set
the host node name through the same adapter.

## Operands

`name` is the new host node name. Setting the node name is a privileged host operation and may be rejected by the
platform or by host policy.

## Options

Only common project options such as `--help`, `--version`, and the internal identity option are recognized by the
process wrapper.

## Standard Input

Not used.

## Standard Output

Without operands, the node name followed by a newline. With a `name` operand, no output is written on success.

## Standard Error

Diagnostics are localized through messages.

## Exit Status

`0` on success, `1` when the platform cannot provide or set a node name, `2` for invalid operands, and `125` for
unexpected internal failures at the command boundary.

## Behavioral Details

The no-operand form reports the current name. The one-operand form attempts to change the node name and reports failure
when the host operation is unsupported, invalid for the host, or refused.

## Locale Behavior

Command data output is locale-invariant. Help and diagnostics are locale-dependent.

## Implementation-Defined Choices

The reported value and setting operation are the hostkit node-name operations for the active platform.

## Extensions

The command supports project-wide help, version, and identity operations.

## Examples

`hostname`

`hostname build-node-01`

## Conformance Status

Project extension.

## Known Limitations

No known V1 limitation for the documented host-name surface beyond host permission and platform capability limits.
