# rg

## Name

`rg` — recursively search paths for matching text.

## Synopsis

`rg [OPTIONS] PATTERN [PATH ...]`

`rg [OPTIONS] -e PATTERN... [-f FILE]... [PATH ...]`

## Description

`rg` is a native Ada recursive-search extension. Pattern matching is provided
exclusively by `regexp`, and Git-compatible ignore processing is provided by
`Version.Ignore` from `versionlib`.

## Operands

`PATTERN` is the search expression. `-e` and `-f` provide explicit pattern
sources instead. Each `PATH` names an input file or search root.

## Options

The implemented search options are:

- `--files` lists files that would be searched without requiring a pattern.
  It shares recursive traversal, ignore, hidden-file, and depth behavior with
  content search. Pattern sources are ignored without being opened; other
  search and result options are rejected in this mode.
- `-g GLOB` or `--glob GLOB` adds an ordered path override. A leading `!`
  excludes matches; later matching rules win. Patterns without a slash match
  basenames at every depth, while slash-containing patterns match root-relative
  paths. Positive matches can re-include ignored files, but an ignored or
  excluded parent directory must itself be re-included before traversal can
  reach descendants. Globs do not imply `--hidden`.
- `-t TYPE` or `--type TYPE` includes files matching a named type. Repeated
  inclusions form a union. `-T TYPE` or `--type-not TYPE` excludes a type and
  exclusions win over inclusions. The pseudo-type `all` denotes every known
  type but not unknown files. Type filters apply during directory traversal;
  explicit file operands remain explicit.
- `--type-list` writes the complete pinned ripgrep 15.2.0 type catalog.
- `-e PATTERN` adds a pattern and may be repeated.
- `-f FILE` or `--file FILE` adds one pattern per line from `FILE` and may be
  repeated or interleaved with `-e`; source order is preserved. `-f -` reads
  patterns from standard input. Pattern records are bounded to 4 MiB.
- `-F` treats patterns as fixed strings.
- `-i`, `-s`, and `-S` select insensitive, sensitive, or smart Unicode case
  handling. Insensitive matching uses Unicode 16.0 simple case folding, aligned
  with ripgrep 15.2.0's `regex-syntax` dependency. Smart case uses the Unicode
  `Uppercase` property; it does not mistake non-ASCII uppercase patterns for
  lowercase patterns.
- `-w` and `-x` require a whole-word or whole-line match.
- `-v` selects records for which no pattern matches.
- `-m NUM` or `--max-count NUM` limits selected records per input file.
- `-A NUM` or `--after-context NUM` writes `NUM` records after each selected
  record. `-B NUM` or `--before-context NUM` writes leading records, and
  `-C NUM` or `--context NUM` sets both values. Explicit `-A` and `-B` values
  override `-C` regardless of option order. Overlapping windows are merged.
- `--context-separator TEXT` replaces the default `--` record between
  disjoint context groups and between groups from separate input files.
- `-n` and `-N` enable or suppress one-based line numbers.
- `-H` and `-I` enable or suppress source-name prefixes.
- `--heading` groups line and match-only results into file sections;
  `--no-heading` restores per-record filename prefixes. Heading layout is
  selected automatically for terminal output. `-I` suppresses header names
  while retaining blank-line separation between input sections. Count and
  file-list modes retain their ordinary path rendering.
- `--column` adds the first match's one-based byte column and implies line
  numbers unless `-N` was specified.
- `-c` or `--count` reports selected-line counts for files with selections.
- `--count-matches` reports the number of non-overlapping matches. With
  inverted matching it counts selected lines, matching the reference.
- `-l` or `--files-with-matches` reports each file containing a selection.
- `--files-without-match` reports files containing no selected lines.
- `-o` or `--only-matching` writes every non-overlapping match on its own
  output record. With `-c`, it selects match counting; with `-v`, selected
  whole records are written.
- `-r TEXT` or `--replace TEXT` replaces every non-overlapping match in
  selected output. `$0`, numbered captures, `$name`, and `${name}` follow
  ripgrep replacement syntax; `$$` writes a literal dollar and unknown
  captures expand to empty text. Capture numbers span the ordered pattern set.
  With `-o`, only expanded replacements are written. Count, file, quiet, and
  inverted modes retain their ordinary result semantics. In multiline mode,
  replacements may remove or introduce line breaks; selected output line
  numbers follow the transformed text while context retains original numbers.
- `-q` or `--quiet` suppresses results and stops globally at the first
  selection; a selection determines success even after a recoverable input
  error.
- `--hidden` includes hidden files and directories.
- `--no-ignore` disables `.gitignore`, `.ignore`, `.rgignore`, repository
  excludes, and configured global excludes.
- `--no-ignore-vcs` disables `.gitignore`, repository excludes, and configured
  Git global excludes while retaining `.ignore` and `.rgignore`.
- `--no-ignore-parent` prevents ignore files above each explicit search root
  from being loaded. Ignore files in the search root and its descendants remain
  active. Explicit search directories are re-included without bypassing rules
  that target their descendants.
- `-u` disables every ignore source while retaining hidden-file filtering;
  `-uu` additionally includes hidden paths, and `-uuu` also searches binary
  files without writing their contents.
- `-L` or `--follow` follows symbolic links encountered during recursive
  discovery; `--no-follow` restores the default. Explicit symlink operands are
  resolved in either mode. Ancestor loops and broken discovered links are
  diagnosed without preventing results from other files.
- `--one-file-system` prevents descent into directories whose device or volume
  differs from the current search root; `--no-one-file-system` restores
  unrestricted descent. Each explicit directory operand establishes its own
  boundary, including a directory reached through an explicit symbolic link.
- `--max-depth NUM` bounds recursive descent with the ripgrep 15.2.0 depth
  convention. A value of zero visits no directory entries.
- `--max-filesize NUM` skips discovered files larger than the limit. Uppercase
  `K`, `M`, and `G` suffixes use 1024-byte units. Explicit file operands are
  not filtered, matching the reference behavior.
- `--sort KEY` and `--sortr KEY` sort ascending or descending. The `path` key
  sorts within each directory operand while preserving directory-operand and
  explicit-file order. The `modified`, `accessed`, and `created` keys order
  every discovered and explicit file globally, preserve discovery order for
  equal timestamps, and place standard input last ascending or first
  descending. Creation-time ordering is available only when the filesystem
  exposes a birth time for every selected file; missing metadata is an
  explicit error. `--sort none` restores ordinary traversal, and the last
  sorting option wins. Sorted discovery keeps at most 64 MiB of pathname data.
- `-j NUM` or `--threads NUM` selects the approximate number of native Ada
  search workers. Zero, the default, uses the host CPU count. At most 64 workers
  are created, and no more workers than selected files are used. Multiple
  explicit files and independent directory roots share one queue; their output
  retains operand and discovery order. Compiled expressions are shared
  read-only while every worker owns its match cursors and input state. Jobs are
  taken through a protected queue; complete per-file output is released through
  a protected sequence gate, so text and JSON events cannot interleave. Sorting
  forces one worker. An operand set containing standard input remains sequential
  because the command input stream is not shared between tasks.
- `--debug` writes structured configuration, regex compilation, ignore-source,
  and path-exclusion messages to standard error. Ignore decisions retain the
  matching pattern, source path, and source line supplied by `Version.Ignore`.
  `--trace` includes every debug message and adds directory descent, selected
  path, input strategy, encoding, binary-offset, and per-file completion
  events. If both flags occur, the last one controls verbosity. Diagnostic
  output never changes the ordinary result stream or exit-status rules.
- `--stats` appends ripgrep-compatible aggregate match, selected-line,
  matching-file, searched-file, printed-byte, searched-byte, search-time, and
  total-time fields. Printed bytes cover line-oriented result output but not
  count or file-result modes or the statistics block itself. Statistics force
  quiet searches to finish so their totals describe every selected input;
  `--no-stats` restores ordinary output. Independent `--files` discovery does
  not emit search statistics.
- `--json` emits one ripgrep-compatible JSON object per line. Search output is
  represented by `begin`, `match`, `context`, `end`, and final `summary`
  events, with zero-based absolute byte offsets and submatch byte ranges.
  Replacement output is attached to each submatch while the event retains the
  original input line. Valid UTF-8 path and line values use `text`; other byte
  strings use base64 `bytes`. JSON implies the accounting needed by per-file
  and summary statistics, and `--stats` does not add text to the JSON stream.
  Multiline matches emit one event containing the complete touched record
  block, with submatch offsets relative to that block and context in separate
  events.
  As in the reference command, count and file-result modes remain textual,
  `-o` retains whole-line JSON match events, and quiet mode emits only its
  summary. With `--null-data`, terminated input records retain their NUL byte
  as `\u0000` in the event's `lines` value while JSON events remain
  LF-delimited. `--no-json` restores ordinary output.
- `--color WHEN` controls ANSI styling. `auto` follows terminal detection and
  the shared `terminal_styles` `NO_COLOR` policy, `always` and `ansi` force
  styling, and `never` suppresses it. Matching spans are bold red, pathnames
  are magenta, and line and column numbers are green. Context text and
  replacement-created text are not marked as matches. Styling applies to
  streaming, multiline, match-only, heading, count-prefix, and file-list
  output. Automatic policy and terminal detection come from `terminal_styles`;
  forced and suppressed modes are applied locally without mutating its
  process-wide policy, including during parallel searches.
- `--colors RULE` applies an iterative custom palette rule. Roles are `path`,
  `line`, `column`, `match`, and `highlight`; attributes are `fg`, `bg`, and
  `style`. Color values may be one of the eight named terminal colors, an ANSI
  palette index from `0` through `255`, or an RGB triple such as `0,128,255`.
  Every numeric component is range checked. Styles are `bold`, `intense`,
  `underline`, and `italic`, together with their `no`-prefixed forms.
  `ROLE:none` clears a role, and later rules can enable it again. `highlight`
  styles non-matching portions of selected lines, distinguishing them from
  context records. The emitted named, indexed, and truecolor SGR sequences
  follow the pinned ripgrep 15.2.0 behavior.
- `-a` or `--text` treats every input as text. `--binary` searches binary files
  but suppresses their raw contents. `--no-text` and `--no-binary` restore
  automatic detection; the last binary-policy option wins.
- `-E NAME` or `--encoding NAME` decodes input incrementally before matching.
  Label resolution matches the complete 228-label WHATWG table used by
  `encoding_rs` 0.8.35, the version pinned by ripgrep 15.2.0. The 40 decoders
  comprise UTF-8 and UTF-16; IBM866; ISO-8859-2 through -8, -10, -13, -14,
  -15, and -16; KOI8-R/U; Macintosh and x-mac-cyrillic; Windows-874 and
  Windows-1250 through -1258; GBK, GB18030, Big5, EUC-JP, ISO-2022-JP,
  Shift_JIS, EUC-KR, replacement, and x-user-defined. Labels are trimmed of
  ASCII whitespace and compared case-insensitively, exactly as the reference.
  Thus labels such as `ascii` and `us-ascii` intentionally select Windows-1252,
  while legacy ISO-2022-KR labels select the replacement decoder. `auto`, which
  is the default, recognizes UTF-8 and both UTF-16 byte-order marks; without a
  mark it preserves input bytes. The rg extension `none` disables mark detection.
  Every UTF-16 label honors either UTF-16 mark when present and otherwise uses
  its named or aliased default byte order. Malformed and unmapped sequences use
  the same U+FFFD replacement and byte-reconsumption rules as encoding_rs.
  Columns, JSON offsets, size accounting, line limits, and match spans refer to
  the decoded UTF-8 stream. `--no-encoding` restores automatic detection.
  Unknown labels are rejected explicitly rather than guessed.
- `-0` or `--null` writes NUL after pathname fields and terminates path-only
  results with NUL. `--no-null` restores ordinary pathname separators.
- `--null-data` reads NUL-delimited search records and NUL-terminates search
  output records, counts, context separators, and file-result modes. Embedded
  newlines remain part of a record, and delimiter NULs are not treated as
  binary-file markers. `--no-null-data` restores LF-delimited search records.
  The independent `--files` discovery mode remains LF-delimited unless
  `--null` is also specified.
- `-U` or `--multiline` permits matches to cross line terminators;
  `--no-multiline` restores record-at-a-time matching. `--multiline-dotall`
  makes dot match line terminators, while `--no-multiline-dotall` restores the
  default. Spanning matches select every touched line, and match-only output is
  split into record fragments. With `--null-data`, the bounded multiline input
  and output pipeline uses NUL record terminators while regex dot behavior
  remains byte-compatible with the pinned reference.
- `--help`, `--version`, and `--posix-tools-identify` provide command metadata.

## Standard Input

When no path is given and standard input is not a terminal, records are read
incrementally from standard input. When `-f -` consumes standard input for
patterns, an invocation without search paths searches the current directory;
an explicit `-` search path is rejected as a conflicting use of the stream.
Binary-policy searches spool standard input through bounded temporary storage
before rendering. The spool limit is 1 GiB; exceeding it is an explicit error.
`--text` retains the direct incremental path.

## Standard Output

Selected records are written to standard output. Recursive and multi-file
searches prefix records with their source path, unless heading layout groups
them beneath one source-name header per matching input.

## Standard Error

Invalid options and patterns, unreadable inputs, ignore-source failures,
over-limit records, and match-limit failures produce diagnostics.

## Exit Status

Zero denotes at least one match or successful metadata output, one denotes no
matches, and two denotes an error.

## Behavioral Details

The compatibility reference is ripgrep 15.2.0. Default regex mode rejects
backreferences, lookaround, atomic groups, and possessive repetition even when
the underlying engine can compile them. Scoped `(?-u:...)` groups select
ASCII/byte matching and can match invalid UTF-8 bytes; nested `(?u:...)` groups
restore Unicode matching. Mixed scopes retain byte-accurate spans and captures.

Compiled regexes are bounded to 1024 pattern bytes and 2048 states. Matching
uses a one-million-step default budget and reports exhaustion explicitly.

Input is read in bounded 64 KiB chunks. A record longer than 4 MiB is reported
instead of being silently omitted. Followed directory links are checked against
the active ancestor chain by stable file identity, with canonical paths as a
portable fallback. File-system boundaries use the host adapter's POSIX device
identifier or Windows volume serial number. Ignore files are loaded lazily at
each directory and parsed exclusively by `Version.Ignore`, retaining the
effective source, line, pattern, and scope.

Leading context is retained in a bounded 64 MiB ring. Exceeding that bound is
reported as an input error. `-m` drains its trailing context window after the
last counted selection without allowing later matches to extend that window.

Automatic binary detection uses a bounded raw-byte prescan for named files.
Recursively discovered binary files are skipped by default, while explicit file
operands are searched and report a `binary file matches` summary instead of raw
data. The summary's offset is zero-based and counts bytes from the start of the
input. JSON mode searches NUL-bearing input and reports the first NUL byte in
the per-file `binary_offset` field, matching the reference event protocol.

NUL-data mode bypasses that NUL-based binary prescan because NUL is the record
delimiter. Matching and byte columns operate on each complete bounded record,
including any embedded newline bytes.

Multiline mode retains at most 64 MiB per input so the regex engine can evaluate
cross-line matches while preserving global byte spans. Exceeding that limit is
an explicit input error. The ordinary record-at-a-time path remains streaming.

Replacement output is limited to 64 MiB per input record or multiline input.
Adjacent multiline replacements are grouped without materializing unbounded
output, and replacement-created records retain the first match byte column.

Parallel search buffers at most 64 MiB of standard output and 4 MiB of
diagnostics per active worker and file. Exceeding either bound is an explicit
error. Workers stop taking queued jobs after quiet success, output failure, or
buffer exhaustion; a worker exception is converted into an input diagnostic so
the ordered output gate cannot deadlock.

## Locale Behavior

Search data is represented as UTF-8 after optional decoding. The regex adapter
uses Unicode 16.0 simple case folding and reports byte offsets, matching the
case-equivalence model of ripgrep 15.2.0. Word boundaries and `\w` use the
Unicode 16.0 `Perl_Word` table. Unicode property escapes use the complete
property, value, and loose-alias inventory pinned by `regex-syntax` 0.8.11.
Malformed UTF-8 bytes do not match Unicode atoms, do not create word
boundaries, and do not prevent a search from resuming at the next valid byte.

## Implementation-Defined Choices

The executable is an Ada 2022 implementation and does not invoke another
search program.

## Extensions

`rg` is a non-POSIX extension to `posix_tools`.

## Examples

`rg --version`

`rg --files --hidden --max-depth 2 src`

`rg --files -t ada src`

`rg -S "Ada" src`

`rg -n --column -o "name" alire.toml`

`rg --count-matches -F "TODO" src`

`rg --hidden --max-depth 2 -F "TODO" .`

## Conformance Status

Project extension; not a POSIX utility.

## Known Limitations

Compiled patterns and multiline buffers retain the documented bounded limits.
The default syntax policy intentionally excludes PCRE2-only constructs, and no
`--pcre2` compatibility is claimed.
