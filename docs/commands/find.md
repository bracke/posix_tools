# find

## Name
`find` - walk file hierarchies.

## Synopsis
`find [path...] [expression]`

## Description
Writes each supplied path and recursively visits directory contents. The supported expression subset includes `-name`,
`-path`, `-exec`, `-ok`, `-group`, `-nogroup`, `-nouser`, `-mtime`, `-newer`, `-perm`, `-size`, `-type`, `-user`, `-depth`,
`-prune`, `-xdev`, `!`, `-a`, `-o`, parentheses, and explicit `-print`. When no expression action is present, matching
pathnames are printed by the default action.

## Operands
`path`: starting point. With no operands, `.` is used. A lone `-` is treated as
an ordinary starting path, not as an option.

## Options
`--` ends option recognition for path operands. `-name pattern` emits only paths whose final component matches simple
`*`, `?`, and bracket-list or bracket-range wildcard patterns. `-perm mode` matches exact octal or symbolic permission
templates where hostkit reports permission bits, and `-perm -mode` matches paths where all selected bits are set.
`-type f` emits ordinary files,
`-type d` emits directories, `-type l` emits symbolic links, `-type b`, `-type c`, `-type p`, and `-type s` match
block devices, character devices, FIFOs, and sockets where hostkit reports exact special-file subtype data, `-size n` matches 512-byte block counts rounded up,
`-size nc` matches byte counts, and `+n` or `-n` select greater-than or less-than comparisons. `-mtime n` matches
24-hour periods since modification time using the same exact, greater-than, and less-than count prefixes. `-newer file`
matches paths modified after the reference file. `-user name` and `-group name` match numeric ids or host-resolved names
where hostkit reports ownership. `-nouser` and `-nogroup` match ownership ids that hostkit can read but cannot resolve
to a user or group name. `-path pattern` matches the whole current pathname using the same wildcard rules as `-name`,
`-depth` evaluates each directory after its contents, `-prune` prevents descent into the current directory when `-depth`
is not active, `-xdev` prevents descent below directories whose hostkit device identity differs from the starting path,
`-exec utility [argument...] ;` invokes a utility through the command context after replacing each standalone `{}`
argument with the current pathname, `-exec utility [argument...] {} +` batches matching pathnames after the preceding
arguments and invokes the utility after traversal, `-ok utility [argument...] ;` prompts on standard error and invokes
the utility only for an affirmative `y` or `Y` response on standard input, and `-print` explicitly selects pathname
output.
Expressions may combine predicates with implicit AND, explicit `-a`,
explicit `-o`, `!`, and parentheses. Project extensions `--help`, `--version`, and `--posix-tools-identify` are
recognized.

## Standard Input
Not used.

## Standard Output
Visited pathnames, one per line.

## Standard Error
Diagnostics for traversal failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Traversal is synchronous and deterministic within host directory enumeration order.

## Locale Behavior
Path output is not localized. Help and diagnostics are localized.

## Implementation-Defined Choices
`-xdev` uses hostkit device identity when the host exposes one; if a host reports no comparable identity for a path,
that subtree is traversed rather than guessed. Supported predicates are listed in Options.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`find src`

## Conformance Status
Conforming with extensions. Requirement coverage is tracked by `POSIX-FIND-001`.

## Known Limitations
Host-specific ownership, permission, special-file, and device-identity queries are only applied when hostkit reports
the relevant data as available.
