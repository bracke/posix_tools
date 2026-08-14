# yes

## Name

`yes` - repeatedly write a string.

## Synopsis

`yes [string...]`

## Description

`yes` repeatedly writes one line to standard output until output fails. With no operands, the line is `y`.
With operands, the line is the operands joined by one space.

`yes` is a project extension and is not part of the POSIX.1-2024 conformance claim.

## Operands

`string`: text to repeat.

## Options

The project extensions `--help`, `--version`, and `--posix-tools-identify` are handled by the common process wrapper.
Other option-like arguments are ordinary operands.

## Standard Input

Not used.

## Standard Output

Repeated lines are written until the output stream reports failure.

## Standard Error

Diagnostics are localized through `messages`.

## Exit Status

`1` when output fails.
`2` for invalid usage handled by the common wrapper.

## Behavioral Details

Command data is not localized. A routine pipe close is represented as output failure by the command context.

## Locale Behavior

Diagnostics and help are locale-dependent. Repeated command data is locale-invariant.

## Implementation-Defined Choices

V1 reports output termination as operational failure.

## Extensions

The complete command is a project extension.

## Examples

`yes`

`yes ok`

## Conformance Status

Conforming with extensions.

## Known Limitations

No rate limiting is applied.
