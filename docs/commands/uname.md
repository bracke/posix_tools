# uname

## Name
`uname` - write system information.

## Synopsis
`uname [-amnrsv]`

## Description
Writes selected system identification fields.

## Operands
No operands are accepted.

## Options
`-a` writes all V1 fields. `-s` writes system name. `-n` writes node name. `-r` writes release. `-v` writes version.
`-m` writes machine name. Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
Selected fields separated by one space and followed by a newline.

## Standard Error
Diagnostics for invalid usage.

## Exit Status
`0` success, `2` invalid usage, `125` internal failure.

## Behavioral Details
System, node, release, version, and machine fields come from hostkit. Missing fields are written as `unknown`.

## Locale Behavior
Help and diagnostics are localized; system fields are not localized.

## Implementation-Defined Choices
Linux and macOS use the host `uname` data exposed through hostkit. Windows reports the fields that the hostkit
Windows adapter exposes and writes `unknown` for unavailable fields.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`uname -a`

## Conformance Status
Conforming with extensions tracked by `UNAME-POSIX-001`.

## Known Limitations
Some Windows release and version fields remain unavailable until hostkit defines a stable Windows version-reporting
policy.
