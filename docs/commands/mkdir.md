# mkdir

## Name
`mkdir` - create directories.

## Synopsis
`mkdir [-p] [-m mode] [--] directory...`

## Description
Creates each named directory.

## Operands
`directory`: directory path to create.

## Options
`-p` creates parent directories as needed. `-m mode` and attached forms such as
`-m755` accept numeric octal mode operands and symbolic `u`, `g`, `o`, `a`
clauses using `+`, `-`, `=` with `r`, `w`, `x`, `X`, `s`, `t`, and `u`, `g`,
`o` permission-copy operands; grouped forms such as `-pm755` are recognized.
Parsed modes are applied through hostkit where the host supports them. Options are recognized before the first
directory operand; later option-like words are directory operands. The end-of-options marker `--` is accepted.
Project extensions `--help`, `--version`, and `--posix-tools-identify` are
recognized.

## Standard Input
Not used.

## Standard Output
No data output on success.

## Standard Error
Diagnostics for invalid usage and creation failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Operands are processed in order and recoverable failures are diagnosed.

## Locale Behavior
Help and diagnostics are localized.

## Implementation-Defined Choices
Modes are applied after creation through hostkit. Symbolic relative modes are evaluated from the created directory mode
where permission bits are available. Host-specific permission models may render these bits rather than store POSIX mode
bits natively.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`mkdir -p a/b`

## Conformance Status
Conforming with extensions tracked by `MKDIR-POSIX-001`.

## Known Limitations
Host-specific permission models may not store every POSIX mode bit natively.
