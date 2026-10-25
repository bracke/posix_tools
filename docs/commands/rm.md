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
`-f` suppresses diagnostics and failure status for operands that do not exist, and disables interactive prompting;
every other failure is still diagnosed and makes the status 1. `-i` prompts before removing each file, before
descending into each directory that holds entries, and before removing each directory once emptied, and disables force
mode. When `-f` and `-i` are grouped or repeated, the last option wins. `-d` removes empty directories. `-r` and
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
Operands are processed in order. An operand whose last pathname component is `.` or `..`, or one that is the root
directory, is diagnosed and nothing of it is removed, as POSIX requires. In interactive mode, an answer line whose first
byte is `y` or `Y` confirms; any other answer, including end of input, keeps that entry without treating it as a
failure, and a directory with a kept entry is kept without being asked about. Prompts are localized through `messages`
and escape untrusted path text.
Removal is done by the shared `Posix_Tools.File_Operations.Removing`. A symbolic link is always removed itself, never
what it points to, including a link to a directory under `-r`, and a tree is walked without following links, so that
nothing outside it is removed. Each entry that could not be removed gets its own diagnostic with the reason, such as
`is a directory`, `directory not empty`, or `no such file or directory`.

## Locale Behavior
Help and diagnostics are localized.

## Implementation-Defined Choices
Recursive removal walks the tree entry by entry, so that each entry can be asked about under `-i`. Whether an operand
names the root directory is decided by resolving it, a symbolic link itself excepted.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`rm -f file`

## Conformance Status
Conforming with extensions tracked by `RM-POSIX-001`.

## Known Limitations
None for the V1 supported surface.
