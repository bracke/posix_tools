# chgrp

## Name
`chgrp` - change file group ownership.

## Synopsis
`chgrp [-R] [--] group file...`

## Description
Changes the group ownership of each named file.

## Operands
`group`: group name or numeric group identifier. `file`: file or directory path.

## Options
`-R` applies the change recursively to directory operands. `--` ends option recognition. Project extensions `--help`,
`--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
No data output on success.

## Standard Error
Diagnostics for invalid usage and ownership failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Ownership changes are performed through hostkit metadata services. Recursive traversal processes child entries before
the directory itself.

## Locale Behavior
Help and diagnostics are localized.

## Implementation-Defined Choices
Unsupported ownership metadata is reported as an operational failure.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`chgrp staff file`

## Conformance Status
Conforming with extensions tracked by `CHGRP-POSIX-001`.

## Known Limitations
Symbolic-link traversal details follow the hostkit file-system adapter.
