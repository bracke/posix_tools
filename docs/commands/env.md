# env

## Name
`env` - run a command in a modified environment.

## Synopsis
`env [-i] [-u name] [--] [name=value...] [utility [argument...]]`

## Description
Writes the selected environment when no utility operand is supplied, otherwise runs the utility with the selected
environment.

## Operands
`name=value`: environment assignment. `utility`: command to execute. `argument`: argument passed to the utility.

## Options
`-i` requests an empty starting environment. `-u name` removes the named variable from the selected environment. `--`
ends option recognition. Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Inherited by the utility when a utility operand is supplied.

## Standard Output
One `name=value` line for each selected environment entry when no utility operand is supplied; otherwise utility
standard output.

## Standard Error
Diagnostics for invalid operands.

## Exit Status
`0` success, `1` ordinary operational failure, `2` invalid usage, `125` internal failure, `126` utility found but
not invokable, `127` utility not found.

## Behavioral Details
Without `-i`, processing starts from the inherited command context environment. `-i` starts from an empty environment.
`-u name` removes matching entries before later operands are processed. Assignment operands add or replace entries in
argument order. The first non-assignment operand is executed without invoking a shell. When a utility is executed, env
returns the utility exit status. If the utility cannot be found or cannot be invoked, env returns the POSIX utility
execution status selected by the process adapter.

## Locale Behavior
Help and diagnostics are localized.

## Implementation-Defined Choices
Environment listing order follows the command context environment order, with replacements retaining their original
position and new assignments appended.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`env -i NAME=value printenv NAME`

## Conformance Status
Conforming with extensions tracked by `ENV-POSIX-001`.

## Known Limitations
Host-specific environment-size and process creation details are reported through the portable utility execution status.
