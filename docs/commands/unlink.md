# unlink

## Name

`unlink` - call the unlink function on a pathname.

## Synopsis

`unlink file`

## Description

`unlink` removes the directory entry named by `file`. It does not accept options in V1.

## Operands

`file`: pathname to unlink.

## Options

The project extensions `--help`, `--version`, and `--posix-tools-identify` are handled by the common process wrapper.
The `--` end-of-options marker is accepted before the operand.

## Standard Input

Not used.

## Standard Output

No output is written on success.

## Standard Error

Diagnostics are localized through `messages`.

## Exit Status

`0` on success.
`1` for operational failure.
`2` for invalid usage.

## Behavioral Details

Exactly one operand is required after an optional `--` marker. Missing and extra operands are usage errors.

## Locale Behavior

Diagnostics and help are locale-dependent. Command data output is not localized.

## Implementation-Defined Choices

Host filesystem error details are normalized through the project adapter.

## Extensions

`--help`, `--version`, `--posix-tools-identify`, and `--` are project extensions.

## Examples

`unlink path`

## Conformance Status

Conforming with extensions.

## Known Limitations

Directory unlinking behavior follows the host filesystem adapter.
