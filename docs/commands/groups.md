# groups

## Name

groups - write current process group names

## Synopsis

`groups`

## Description

`groups` writes the primary and supplementary groups visible to the current process through the posix_tools host
adapter.

## Operands

No operands are accepted.

## Options

Only common project options such as `--help`, `--version`, and the internal identity option are recognized by the
process wrapper.

## Standard Input

Not used.

## Standard Output

Group names or numeric group identifiers separated by spaces, followed by a newline.

## Standard Error

Diagnostics are localized through messages.

## Exit Status

`0` on success, `1` when group information is unavailable, `2` for invalid operands, and `125` for unexpected internal
failures at the command boundary.

## Behavioral Details

The command reports the current process group set only. Duplicate group identifiers are suppressed while preserving
the order reported by the host adapter.

## Locale Behavior

Command data output is locale-invariant. Help and diagnostics are locale-dependent.

## Implementation-Defined Choices

Group-name lookup is hostkit-defined. Numeric identifiers are used when a group name is unavailable.

## Extensions

`groups` is a project extension command. The command supports project-wide help, version, and identity operations.

## Examples

`groups`

## Conformance Status

Project extension.

## Known Limitations

User-name operands are not implemented.
