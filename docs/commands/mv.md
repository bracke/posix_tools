# mv

## Name
`mv` - rename a file.

## Synopsis
`mv [-fiv] [--] source... target`

## Description
Renames one source path to one target path, or moves source paths into an existing
target directory: with two operands too, a target that is a directory receives the
source under its own name.

## Operands
`source`: source path. `target`: target path or target directory.

## Options
`-f` forces overwrites without prompting. `-i` prompts before overwriting an existing destination. When `-f`
and `-i` are both supplied, the last one wins. `-v` writes one deterministic source-to-target line after each
successful move. Options are recognized before the first source operand; later option-like words are path operands.
The end-of-options marker `--` is accepted. Project extensions `--help`, `--version`, and
`--posix-tools-identify` are recognized.

## Standard Input
Used only for `-i` overwrite responses.

## Standard Output
No data output on success unless `-v` is selected.

## Standard Error
Overwrite prompts and diagnostics for invalid usage and move failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
The implementation renames through the host in one step, replacing an existing file at the target as rename(2)
does. Only a move the host cannot make in one step, as across filesystems, is made by copying: the shared
`Posix_Tools.File_Operations.Moving` copies the operand, keeping modes, owners, times, and symbolic links as links, and
removes the source only once all of it has been copied. A rename the host refuses, such as a directory onto one that is
not empty, is a move failure, reported once for the operand. Interactive overwrite prompts accept an initial `y`
or `Y` byte as confirmation; any other response, including end-of-input, skips that operand without treating the skip
as a move failure.

## Locale Behavior
Help and diagnostics are localized.

## Implementation-Defined Choices
Multiple source operands require the target to be an existing directory.

## Extensions
`-v`, `--help`, `--version`, `--posix-tools-identify`.

## Examples
`mv old new`

## Conformance Status
Conforming with extensions tracked by `MV-POSIX-001`.

## Known Limitations
The copy-and-remove fallback preserves source mode bits, ownership, access time, and modification time where supported
by the host metadata adapter and permitted by host permissions. Other metadata is best effort.
