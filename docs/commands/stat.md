# stat

## Name

stat - write file metadata

## Synopsis

`stat file...`

`stat -c format file...`

## Description

`stat` writes a compact metadata block for each file operand using the posix_tools filesystem adapter.

## Operands

Each operand is a file path to inspect.

## Options

`-c format` writes one formatted line per operand. Supported format fields are `%%`, `%n` pathname, `%s` size, `%F`
file type, `%a` octal mode, `%u` user id, and `%g` group id. The escapes `\n`, `\t`, and `\\` are recognized.
`--` may be used to end option recognition. Common project options such as `--help`, `--version`, and the internal
identity option are recognized by the process wrapper.

## Standard Input

Not used.

## Standard Output

For each existing operand, `stat` writes fields for file path, size, type, mode, user id, and group id. Multiple
operands are separated by one blank line. In `-c` mode, each operand writes one formatted output line.

## Standard Error

Diagnostics are localized through messages.

## Exit Status

`0` when all operands are inspected and output succeeds, `1` when any operand cannot be inspected or output fails,
`2` for invalid usage, and `125` for unexpected internal failures at the command boundary.

## Behavioral Details

The default output format is stable for this project but is not GNU or BSD `stat` compatible. Missing permission or
ownership metadata is reported as `unknown`. The `-c` format language is a focused project-compatible subset.

## Locale Behavior

Metadata labels and diagnostics are locale-dependent in future catalog-backed help. Pathname data and numeric output
are locale-invariant in V1.

## Implementation-Defined Choices

File type, size, permissions, ownership, and special-file classification follow hostkit metadata behavior on the
active platform.

## Extensions

`stat` is a project extension command. The command supports project-wide help, version, and identity operations.

## Examples

`stat README.md`

`stat -c '%n %s %F' README.md`

## Conformance Status

Project extension.

## Known Limitations

Timestamp format fields are not implemented in V1.
