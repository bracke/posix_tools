# getconf

## Name
getconf - write configuration values

## Synopsis
getconf variable [pathname]

## Description
`getconf` writes selected POSIX configuration values known to the project and host adapter.

## Operands
`variable` names the requested configuration value. `pathname` is accepted for path-dependent variables.

## Options
`--help` and `--version` are project extensions.

## Standard Input
Not used.

## Standard Output
The requested value followed by a newline.

## Standard Error
Localized diagnostics are written for unknown variables and invalid operands.

## Exit Status
0 on success, 1 for operational failure, 2 for invalid usage, and 125 for internal failure.

## Behavioral Details
V1 supports `POSIX_VERSION`, `POSIX2_VERSION`, `PATH`, `NAME_MAX`, and `PATH_MAX`.

## Locale Behavior
Help and diagnostics are locale-dependent. Configuration values are not localized.

## Implementation-Defined Choices
Unavailable path limits are reported as `undefined`.

## Extensions
`--help`, `--version`, and `--posix-tools-identify`.

## Examples
`getconf POSIX_VERSION`

## Conformance Status
Conforming with extensions.

## Known Limitations
Only a focused V1 configuration set is implemented.
