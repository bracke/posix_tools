# cp

## Name
`cp` - copy a file.

## Synopsis
`cp [-fHiLpPRrv] [--] source... target`

## Description
Copies one source file or recursive source directory to one target path, or multiple sources into an existing target directory.

## Operands
`source`: input file path. `target`: output file path or target directory. A lone `-` is treated as an ordinary
pathname operand, not as standard input or an option.

## Options
`-f` forces overwrites without prompting. `-H` and `-L` select the default behavior of following symbolic links named
by source operands. `-i` prompts before overwriting an existing destination. When `-f` and `-i`
are both supplied, the last one wins. `-P` copies symbolic links as symbolic links where hostkit supports link reading
and creation. `-p` preserves permission bits and ownership where the hostkit metadata service
reports support and preserves modification timestamps where the host timestamp service supports it. `-R` and `-r` copy
directory trees recursively. `-v` writes deterministic source-to-target lines after
successful copies.
Options are recognized before the first source operand; later option-like words are path operands. The end-of-options
marker `--` is accepted.
Project extensions `--help`, `--version`, and
`--posix-tools-identify` are recognized.

## Standard Input
Used only for `-i` overwrite responses.

## Standard Output
No data output on success unless `-v` is selected.

## Standard Error
Overwrite prompts and diagnostics for invalid usage and file failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
The V1 expanded implementation copies file contents through bounded internal buffers at the command boundary. Recursive
directory copying creates missing target directories and copies contained entries. Interactive overwrite prompts are
localized through `messages`, safely escape untrusted path text, and accept
an initial `y` or `Y` byte as confirmation; any other response, including end-of-input, skips that operand without
treating the skip as a copy failure. Symbolic links are followed unless `-P` is the last selected symlink traversal
mode.
Directory sources without `-R` or `-r` fail with a localized `is a directory` diagnostic. Recursive directory copies
fail immediately with a localized `not a directory` diagnostic when the destination path already exists as a
non-directory.
Copies that would write a source onto the same underlying destination file, including a destination hard link to the
source where hostkit reports identity, fail before writing. Recursive copies that would place the destination at or
below the source directory fail before creating the destination subtree.
FIFOs, character or block device nodes, and Unix-domain socket files are recreated through hostkit where the platform
exposes portable special-file metadata and permits creation.

## Locale Behavior
Diagnostics and help are localized; copied data is not localized.

## Implementation-Defined Choices
Multiple source operands require the target to be an existing directory. Ownership preservation with `-p` is attempted
only when source and target ownership metadata are both available, and it can still be refused by host permissions.
Special-file recreation is limited by host platform capabilities and ordinary filesystem permissions. Device-node
creation is commonly privileged. Windows does not have POSIX pathname sockets or device nodes, so those creation
operations are unavailable there.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`cp input output`

## Conformance Status
Conforming with extensions.

## Known Limitations
No known limitation for the implemented V1 surface beyond host permission and platform capability limits documented
above.
