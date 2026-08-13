# ln

## Name
`ln` - create a link.

## Synopsis
`ln [-fsv] [--] source... target`

## Description
Creates a hard link by default or a symbolic link with `-s`.

## Operands
`source`: source path. `target`: target path or existing directory.

## Options
`-f` removes an existing non-directory target before creating the replacement. `-s` creates a symbolic link. `-v`
writes one deterministic source-to-target line after each successful link. `--` ends option recognition. Options are
recognized before the first source operand; later option-like words are source or target operands. Project
extensions `--help`, `--version`, and
`--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
No data output on success unless `-v` is selected.

## Standard Error
Diagnostics for invalid usage and link failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Hard links are created through hostkit. If the target operand names an existing directory, each source is linked inside
that directory using its lexical basename. Symbolic links are attempted through hostkit and may fail as an ordinary
operational failure on hosts that deny the required capability.

## Locale Behavior
Help and diagnostics are localized.

## Implementation-Defined Choices
Directory target forms use the project POSIX lexical basename policy for the created link name. Link failures are
reported through the project portable diagnostic categories.

## Extensions
`-v`, `--help`, `--version`, `--posix-tools-identify`.

## Examples
`ln source target`

## Conformance Status
Conforming with extensions tracked by `LN-POSIX-001`.

## Known Limitations
None for the V1 supported surface.
