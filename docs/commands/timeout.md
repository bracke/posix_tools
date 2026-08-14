# timeout

## Name

timeout - run a utility with a time limit

## Synopsis

`timeout [-s signal] [-k duration] [--preserve-status] [--foreground] duration utility [argument...]`

## Description

`timeout` runs the named utility without invoking a shell and limits the elapsed time spent waiting for it.
If the limit expires, the utility is terminated by the host process adapter.

## Operands

`duration` is a non-negative decimal duration. The suffixes `s`, `m`, `h`, and `d` select seconds,
minutes, hours, and days. No suffix means seconds.

`utility` names the utility to execute. Remaining operands are passed as its arguments.

## Options

`-s signal`, `--signal=signal`

Select the signal name recorded for timeout termination. V1 validates only that a nonempty signal name is
provided; actual termination is delegated to hostkit's portable timeout stop policy.

`-k duration`, `--kill-after=duration`

Add an additional kill-after interval to the timeout wait limit.

`--preserve-status`

Return the timed-out utility status instead of the timeout status when the host adapter supplies one.

`--foreground`

Accepted as a project extension for command-line compatibility. V1 process-group behavior is delegated to
hostkit.

## Standard Input

Inherited by the invoked utility where the host adapter supports it.

## Standard Output

The invoked utility's standard output is replayed to standard output.

## Standard Error

Diagnostics are written to standard error. The invoked utility's standard error is replayed to standard error.

## Exit Status

`0` through `123` are propagated from the invoked utility when it exits normally.

`124` indicates the timeout expired, unless `--preserve-status` is used.

`126` indicates the utility was found but could not be invoked.

`127` indicates the utility was not found.

`125` indicates an internal failure.

## Behavioral Details

The implementation invokes utilities without a shell. Output replay is bounded by the shared process adapter
capture limit.

## Locale Behavior

Help and diagnostics are locale-dependent through `messages`. Utility data output is not localized.

## Implementation-Defined Choices

Timeout termination uses hostkit's portable stop policy.

## Extensions

`--help`, `--version`, `--posix-tools-identify`, `--signal=signal`, `--kill-after=duration`, and
`--foreground` are project extensions.

## Examples

`timeout 2s utility argument`

## Conformance Status

Conforming with extensions for the implemented POSIX.1-2024 Issue 8 surface.

## Known Limitations

V1 captures and replays child output through bounded temporary files rather than streaming inherited output
directly while the child runs.
