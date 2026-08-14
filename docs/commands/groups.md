# groups

## Name

groups - write process or user group names

## Synopsis

`groups`

`groups user...`

## Description

`groups` writes the primary and supplementary groups visible to the current process through the posix_tools host
adapter. With user operands, it writes the group list reported for each named user.

## Operands

Each `user` operand names a user whose primary and supplementary groups should be reported.

## Options

Only common project options such as `--help`, `--version`, and the internal identity option are recognized by the
process wrapper.

## Standard Input

Not used.

## Standard Output

Without operands, group names or numeric group identifiers separated by spaces, followed by a newline. With user
operands, one line is written per user in the form `user : group...`.

## Standard Error

Diagnostics are localized through messages.

## Exit Status

`0` on success, `1` when group information is unavailable for the process or any requested user, `2` for invalid
usage, and `125` for unexpected internal failures at the command boundary.

## Behavioral Details

Duplicate group identifiers are suppressed while preserving the order reported by the host adapter.

## Locale Behavior

Command data output is locale-invariant. Help and diagnostics are locale-dependent.

## Implementation-Defined Choices

Group-name lookup and named-user group lookup are hostkit-defined. Numeric identifiers are used when a group name is
unavailable.

## Extensions

`groups` is a project extension command. The command supports project-wide help, version, and identity operations.

## Examples

`groups`

`groups builduser`

## Conformance Status

Project extension.

## Known Limitations

No known V1 limitation for the documented group reporting surface beyond host identity database capability limits.
