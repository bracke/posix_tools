# rm

## Name
`rm` - remove directory entries.

## Synopsis
`rm [-fidv] [-r|-R] [--] file...`

## Description
Removes files, empty directories with `-d`, and directory trees with recursive mode.

## Operands
`file`: path to remove.

## Options
`-f` suppresses missing-file failures and disables interactive prompting. `-i` prompts before each removal and disables
force mode. When `-f` and `-i` are grouped or repeated, the last option wins. `-d` removes empty directories. `-r` and
`-R` remove directory trees. `-v` writes a deterministic removal line after each successful operand removal. Project
extensions are recognized. Options are recognized before the first file operand; later option-like words are file
operands. The end-of-options marker `--` is accepted.

## Standard Input
Used for interactive responses when `-i` is selected.

## Standard Output
No data output on success unless `-v` is selected.

## Standard Error
Diagnostics for invalid usage and removal failures. Interactive prompts are written to standard error.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Operands are processed in order. In interactive mode, a response whose first byte is `y` or `Y` confirms removal; any
other response, including end of input, skips that operand without treating it as a failure.

## Locale Behavior
Help and diagnostics are localized.

## Implementation-Defined Choices
Recursive removal uses the host Ada directory tree deletion operation after the interactive decision for the top-level
operand has been accepted.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`rm -f file`

## Conformance Status
Conforming with extensions tracked by `RM-POSIX-001`.

## Known Limitations
None for the V1 supported surface.
