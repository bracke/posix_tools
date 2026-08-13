# mv

## Name
`mv` - rename a file.

## Synopsis
`mv [-fiv] [--] source... target`

## Description
Renames one source path to one target path, or moves multiple source paths into
an existing target directory.

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
The implementation first delegates to the Ada runtime rename operation. If that fails, it attempts a portable
copy-and-remove fallback for regular files and directory trees. Interactive overwrite prompts accept an initial `y`
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
The copy-and-remove fallback preserves source mode bits where supported by the host metadata adapter. Other metadata is
best effort.
