# logname

## Name
`logname` - write the user's login name.

## Synopsis
`logname`

## Description
Writes the login name associated with the current session or user.

## Operands
No operands are accepted.

## Options
Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
The login name followed by a newline.

## Standard Error
Diagnostics for invalid usage or unavailable login name.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
V1 first accepts a nonempty `LOGNAME` value from the command context environment for deterministic test and
environment-driven sessions. If that value is absent or empty, it asks hostkit for the host login name. If the host
cannot report a session login name, V1 falls back to resolving the current user id through the host user database.

## Locale Behavior
Help and diagnostics are localized; the login name is not localized.

## Implementation-Defined Choices
An operational failure is reported only when neither the environment, host login-name API, nor current-user database can
identify a login name.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`logname`

## Conformance Status
Conforming with extensions tracked by `LOGNAME-POSIX-001`.

## Known Limitations
No known V1 limitation.
