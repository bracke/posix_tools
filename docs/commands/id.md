# id

## Name
`id` - write user and group identity.

## Synopsis
`id [-Ggnu]`

## Description
Writes identity information for the current process.

## Operands
No operands are accepted.

## Options
`-u` writes the current process user identifier. `-g` writes the current process group identifier. `-G` writes the
primary and supplementary group set available from hostkit. `-n` writes a name instead of a number where a name is
available.
Project extensions `--help`,
`--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
Identity data followed by a newline.

## Standard Error
Diagnostics for invalid usage or unsupported identity queries.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
The current user identifier, primary group identifier, and supplementary group identifiers are read through hostkit.
Names are resolved through hostkit metadata services. If supplementary groups are unavailable, the primary group is
still reported when the host exposes it.

## Locale Behavior
Help and diagnostics are localized; identity data is not localized.

## Implementation-Defined Choices
Group ordering starts with the primary group and then includes host-reported supplementary groups without duplicates.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`id -u`

## Conformance Status
Conforming with extensions tracked by `ID-POSIX-001`.

## Known Limitations
Hosts without POSIX-style numeric user and group identities report operational failure.
