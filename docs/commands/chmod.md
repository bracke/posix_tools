# chmod

## Name
`chmod` - change file modes.

## Synopsis
`chmod [-R] [--] mode file...`

## Description
Changes permission bits on each named file.

## Operands
`mode`: octal or symbolic file mode. `file`: file or directory path.

## Options
`-R` applies the mode recursively to directory operands. `--` ends option recognition. Project extensions `--help`,
`--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
No data output on success.

## Standard Error
Diagnostics for invalid usage and permission failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
V1 accepts octal modes of one to four digits and symbolic mode clauses using `u`, `g`, `o`, `a`, `+`, `-`, `=`,
`r`, `w`, `x`, `X`, `s`, `t`, and permission-copy operands. Symbolic modes are evaluated from the current target
mode reported by hostkit.

## Locale Behavior
Help and diagnostics are localized.

## Implementation-Defined Choices
Hostkit supplies the existing mode bits and applies the selected final mode. Host platforms that cannot report or set
permission bits return operational failure for the affected path.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`chmod 644 file`

`chmod u=rw,go=r file`

## Conformance Status
Conforming with extensions tracked by `CHMOD-POSIX-001`.

## Known Limitations
Host-specific permission-bit availability is determined by hostkit.
