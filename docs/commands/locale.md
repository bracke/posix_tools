# locale

## Name
locale - write locale information

## Synopsis
locale
locale -a
locale -m

## Description
`locale` writes the effective locale category values, available locale names, or available charmaps.

## Operands
No operands are accepted.

## Options
`-a` writes available locale names. `-m` writes available charmaps. `--help` and `--version` are project extensions.

## Standard Input
Not used.

## Standard Output
Locale category assignments, locale names, or charmap names.

## Standard Error
Localized diagnostics are written for invalid usage.

## Exit Status
0 on success, 2 for invalid usage, and 125 for internal failure.

## Behavioral Details
Unset categories fall back to `LANG`, then to `C`.

## Locale Behavior
Help and diagnostics are locale-dependent. Locale names and category names are not translated.

## Implementation-Defined Choices
V1 reports the portable `C` and `POSIX` locale names and `UTF-8` charmap.

## Extensions
`--help`, `--version`, and `--posix-tools-identify`.

## Examples
`locale`

## Conformance Status
Conforming with extensions.

## Known Limitations
The available-locale list is intentionally portable and not a host catalog dump.
