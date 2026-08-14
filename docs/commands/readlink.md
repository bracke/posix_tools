# readlink

## Name
`readlink` - write a symbolic link target.

## Synopsis
`readlink [--] file`

## Description
Writes the target stored in a symbolic link.

## Operands
`file`: symbolic link path.

## Options
`--` ends option recognition. Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
The link target followed by a newline.

## Standard Error
Diagnostics for invalid usage and readlink failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
The link target is read through hostkit without shelling out.

## Locale Behavior
Help and diagnostics are localized; path data is not localized.

## Implementation-Defined Choices
The command supports the POSIX-style single operand surface in V1.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`readlink shortcut`

## Conformance Status
Conforming with extensions tracked by `READLINK-POSIX-001`.

## Known Limitations
Host platforms without symbolic-link support report operational failure.
