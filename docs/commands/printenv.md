# printenv

## Name

printenv - write environment values

## Synopsis

`printenv [name...]`

## Description

`printenv` writes the current command context environment. With no operands it writes all environment entries as
`name=value` records. With operands it writes the value of each named variable that is present.

## Operands

Each operand is an environment variable name.

## Options

`--` may be used to end option recognition. Common project options such as `--help`, `--version`, and the internal
identity option are recognized by the process wrapper.

## Standard Input

Not used.

## Standard Output

Environment entries or selected values, one per line.

## Standard Error

Diagnostics are localized through messages.

## Exit Status

`0` when all requested output succeeds and every requested variable is present, `1` when any requested variable is
missing or output fails, `2` for invalid usage, and `125` for unexpected internal failures at the command boundary.

## Behavioral Details

The command observes only the command context environment and does not mutate it.

## Locale Behavior

Environment data output is locale-invariant. Help and diagnostics are locale-dependent.

## Implementation-Defined Choices

The order for full-environment output is the order provided by the command context.

## Extensions

`printenv` is a project extension command. The command supports project-wide help, version, and identity operations.

## Examples

`printenv PATH`

## Conformance Status

Project extension.

## Known Limitations

No additional limitations are documented for the V1 project-extension behavior.
