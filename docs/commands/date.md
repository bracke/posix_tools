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
`GMT` forms report `%Z` as `UTC`, while other fixed-offset forms report the zone name prefix. Outside fixed-offset
mode, `%Z` uses the numeric `%z` offset as a deterministic fallback.
Weekday names, month names, and AM/PM markers are read from the messages catalog for the effective locale with English
fallback. The `%c`, `%x`, and `%X` composites use deterministic V1 layouts.
Set-time operands are parsed before invoking the host adapter. Invalid dates, invalid times, and malformed seconds are
usage errors. If the host denies setting the system clock, `date` reports an operational failure.

## Locale Behavior
Help and diagnostics are localized. Weekday names, month names, and AM/PM markers in `+format` output are localized
through messages; numeric fields and literal format text are not localized.

## Implementation-Defined Choices
The default timestamp format is implementation-defined. Fixed-offset `TZ` handling is deterministic and does not use a
geographic timezone database.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`date +%Y-%m-%d`

## Conformance Status
Conforming with extensions.

## Known Limitations
Daylight-saving transitions and geographic timezone databases are not implemented; fixed-offset POSIX-style `TZ`
strings are used instead.
