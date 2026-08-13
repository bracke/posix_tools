# date

## Name
`date` - write the current date and time.

## Synopsis
`date [-u] [--] [+format]`
`date [-u] [--] mmddhhmm[[cc]yy][.ss]`

## Description
Writes the current host date and time. `-u` selects UTC output. `--` ends option recognition. A `+format` operand
formats selected timestamp fields. A set-time operand updates the system clock through hostkit where the host permits
it.

## Operands
`+format`: optional output format. Supported directives are `%a`, `%A`, `%b`, `%h`, `%B`, `%C`, `%Y`, `%y`, `%m`,
`%d`, `%e`, `%H`, `%I`, `%k`, `%l`, `%M`, `%p`, `%S`, `%s`, `%c`, `%D`, `%F`, `%R`, `%r`, `%T`, `%X`, `%x`, `%G`,
`%g`, `%U`, `%V`, `%W`, `%u`, `%w`, `%j`, `%z`, `%Z`, `%%`, `%n`, and `%t`.

`mmddhhmm[[cc]yy][.ss]`: set the system date and time. Two-digit years `69` through `99` map to 1969 through
1999; `00` through `68` map to 2000 through 2068. `.ss` supplies optional seconds.

## Options
`-u` writes the timestamp in UTC. Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
One date-time line.

## Standard Error
Diagnostics for invalid usage.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
With no operand, the output format is the Ada calendar formatting image used by the current implementation. With
`+format`, supported directives are expanded and unsupported directives are preserved with their leading percent sign.
In UTC mode, `%z` emits `+0000` and `%Z` emits `UTC`. The `-u` option selects UTC and takes precedence over `TZ`.
`TZ` environment values with
alphabetic zone prefixes and fixed numeric offsets are honored in deterministic forms such as `UTC0`, `UTC-0000`,
`GMT+00:00`, `UTC+02:30`, `GMT-0330`, `CET-1`, and `FOO+02:30`. Quoted zone names such as `<UTC+1>+02:30` are also
accepted for fixed-offset mode. POSIX-style strings with a DST suffix or rule tail, such as `EST5EDT` and
`EST5EDT,M3.2.0,M11.1.0`, use only the standard fixed offset and ignore DST transition rules. Zero-offset `UTC` and
`GMT` forms report `%Z` as `UTC`, while other fixed-offset forms report the zone name prefix. IANA-style timezone
identifiers and aliases such as `Etc/UTC`, `Asia/Kolkata`, `Europe/Copenhagen`, and `US/Eastern` are resolved through
hostkit using the host timezone database where the platform exposes it; otherwise the sibling `i18n` crate's generated
tzdb data is used for the selected UTC instant. For named zones, `%z` reports the resolved numeric offset and `%Z`
reports the host abbreviation, an i18n short name, or the canonical zone identifier depending on the provider.
Unknown `TZ` values leave the implementation-defined local timezone behavior unchanged.
Weekday names, month names, and AM/PM markers are read from the messages catalog for the effective locale with English
fallback. The `%c`, `%x`, and `%X` composites use deterministic V1 layouts.
Set-time operands are parsed before invoking the host adapter. Invalid dates, invalid times, and malformed seconds are
usage errors. If the host denies setting the system clock, `date` reports an operational failure.

## Locale Behavior
Help and diagnostics are localized. Weekday names, month names, and AM/PM markers in `+format` output are localized
through messages; numeric fields and literal format text are not localized.

## Implementation-Defined Choices
The default timestamp format is implementation-defined. POSIX-style DST suffix and transition-rule tails on fixed-offset
`TZ` strings are accepted but only the standard offset is applied. Named timezone support prefers hostkit host-database
resolution and falls back to the generated tzdb subset provided by `i18n`.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`date +%Y-%m-%d`

## Conformance Status
Conforming with extensions.

## Known Limitations
None recorded for the implemented V1 `date` scope.
