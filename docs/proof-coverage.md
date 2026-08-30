# Proof Coverage

`posix_tools_tests prove` runs selected GNATprove targets through
`common/posix_tools_proof.gpr` with Z3, proof mode, warnings as errors, and
unproved checks as errors. Most targets run at level 1; the widened
`Posix_Tools.Text.File_Modes` target also runs a focused level-2 pass. Metadata
checks scan SPARK-enabled package specs under `common/src` and
`common/generated` and fail if any of them are absent from either the proof
target list or the inventory below. The gate is intentionally explicit: a unit
is not covered unless it appears in the target inventory below.

## Integrated Targets

- `Posix_Tools`
- `Posix_Tools.Version`
- `Posix_Tools.Command_Inventory`
- `Posix_Tools.Command_Inventory.Tables`
- `Posix_Tools.Extension_Options`
- `Posix_Tools.Numbers`
- `Posix_Tools.Paths`
- `Posix_Tools.Text.UTF_8`
- `Posix_Tools.Text.Classification`
- `Posix_Tools.Text.Whitespace_Data`
- `Posix_Tools.Streams.Counting`
- `Posix_Tools.Counts`
- `Posix_Tools.Tail_Rings`
- `Posix_Tools.Tail_Counts`
- `Posix_Tools.Wc_Fields`
- `Posix_Tools.Exit_Status`
- `Posix_Tools.Commands.Results`
- `Posix_Tools.Commands`
- `Posix_Tools.Streams`
- `Posix_Tools.Text`
- `Posix_Tools.Text.Escaping`
- `Posix_Tools.Text.Checksum_Lines`
- `Posix_Tools.Text.Checksums`
- `Posix_Tools.Text.Cut_Fields`
- `Posix_Tools.Text.DD_Conversions`
- `Posix_Tools.Text.Diagnostic_Fields`
- `Posix_Tools.Text.Duration_Fields`
- `Posix_Tools.Text.File_Magic_Fields`
- `Posix_Tools.Text.File_Operands`
- `Posix_Tools.Text.Glob_Fields`
- `Posix_Tools.Text.Line_Breaks`
- `Posix_Tools.Text.Locale_Fields`
- `Posix_Tools.Text.Byte_Classes`
- `Posix_Tools.Text.Matching`
- `Posix_Tools.Text.Base_Parsing`
- `Posix_Tools.Text.Suffixes`
- `Posix_Tools.Text.Tab_Stops`
- `Posix_Tools.Text.Logical_Paths`
- `Posix_Tools.Text.Portable_Paths`
- `Posix_Tools.Text.Test_Operators`
- `Posix_Tools.Text.Hex_Digests`
- `Posix_Tools.Text.Sort_Modifiers`
- `Posix_Tools.Text.Paste_Delimiters`
- `Posix_Tools.Text.Printf_Escapes`
- `Posix_Tools.Text.Seq_Formats`
- `Posix_Tools.Text.Find_Expressions`
- `Posix_Tools.Text.OD_Formats`
- `Posix_Tools.Text.Signal_Names`
- `Posix_Tools.Text.NL_Fields`
- `Posix_Tools.Text.Nice_Fields`
- `Posix_Tools.Text.Decimal_Parsing`
- `Posix_Tools.Text.File_Modes`
- `Posix_Tools.Text.Numeric_Images`
- `Posix_Tools.Option_Parsing`
- `Posix_Tools.Text.Octal_Modes`
- `Posix_Tools.Text.Octal_Parsing`
- `Posix_Tools.Text.Owner_Groups`
- `Posix_Tools.Text.Time_Fields`
- `Posix_Tools.Text.Touch_Fields`
- `Posix_Tools.Text.Xargs_Fields`
- `Posix_Tools.Text.File_Modes` at level 2

## Current Exclusions

The metadata checks also enforce the non-SPARK side of the boundary. A package
specification under `common/src` or `common/generated` that is not marked
`SPARK_Mode => On` must match one of the entries below, otherwise
`posix_tools_tests metadata` fails.

## Documented Non-SPARK Boundaries

- `posix_tools.arguments`
- `posix_tools.arguments.parsing`
- `posix_tools.commands.*`
- `posix_tools.help`
- `posix_tools.host_adapters.*`
- `posix_tools.localization`
- `posix_tools.presentation`
- `posix_tools.streams.lines`
- `posix_tools.text.dd_blocks`
- `posix_tools.text.dd_conversion_engine`
- `posix_tools.text.dd_operands`
- `posix_tools.text.date_formats`
- `posix_tools.text.expr_expressions`
- `posix_tools.text.expr_regex`
- `posix_tools.text.file_descriptions`
- `posix_tools.text.printf_formats`
- `posix_tools.text.printf_formats.number_images`
- `posix_tools.text.printf_formats.number_images.float_images`
- `posix_tools.text.stat_formats`
- `posix_tools.text.sort_numeric`
- `posix_tools.text.xargs_parsing`

`Posix_Tools.Arguments.Parsing` is explicitly outside SPARK as a boundary
wrapper. The pure short-option decision logic has been extracted and proved as
`Posix_Tools.Option_Parsing`, while the remaining wrapper still depends on the
shared `Ada.Containers.Indefinite_Vectors` argument vector and
`Ada.Strings.Unbounded`. A focused package-level SPARK attempt is rejected before
proof because those container/string entities are declared outside SPARK.

`Posix_Tools.Text.DD_Conversion_Engine` is outside SPARK as the byte
transformation boundary for `dd conv=` execution. The parsed conversion tokens
remain in the proved `Posix_Tools.Text.DD_Conversions` package; the execution
engine depends on unbounded string assembly, byte-table translation, and
record-shaping output construction, and is covered by direct engine tests plus
command-level `dd` tests.

`Posix_Tools.Text.DD_Blocks` centralizes `dd` block slicing, transfer
skip/count/seek planning, offset-overflow checks, and full/partial record
accounting. It remains a non-SPARK boundary because selected block slicing
returns variable-length strings assembled with unbounded strings, and is covered
by direct helper tests plus command-level `dd` tests.

`Posix_Tools.Text.DD_Operands` centralizes `dd` operand parsing and post-parse
validation. It remains a non-SPARK boundary because it carries file-name and
diagnostic text in unbounded strings while assembling conversion settings; the
numeric/conversion token primitives remain in proved packages, and this wrapper
is covered by direct operand tests plus command-level `dd` tests.

Command implementations remain covered primarily by tests. Pure command-local
helpers are extracted when practical: conventional command extension option
dispatch for `--help`, `--version`, and `--posix-tools-identify` is proved in
`Posix_Tools.Extension_Options`; usage-diagnostic prefix classification
and payload slice bounds for localized command diagnostics are proved in
`Posix_Tools.Text.Diagnostic_Fields`; file operand subject naming for `-`
standard-input diagnostics is proved in `Posix_Tools.Text.File_Operands`;
SHA256 checksum-file line digest validation, digest lowercasing, and filename
slice selection are proved in `Posix_Tools.Text.Checksum_Lines`;
POSIX `cksum` CRC-32 byte and length folding is proved in
`Posix_Tools.Text.Checksums`;
`cut` list range parsing for singleton, open-ended, leading-open, closed
ranges, separator handling, and trailing separator rejection plus
position-selection predicates are proved in `Posix_Tools.Text.Cut_Fields`;
`dd` conversion-token, comma-list, size/count suffix, and product parsing is proved in
`Posix_Tools.Text.DD_Conversions`;
`chown` owner/group operand splitting for `owner`, `owner:group`, `owner:`,
and `:group` forms is proved in `Posix_Tools.Text.Owner_Groups`;
`sleep` and `timeout` duration suffix and numeric-field bounds plus exact
millisecond conversion for `timeout` durations are proved in
`Posix_Tools.Text.Duration_Fields`;
`file` magic-file escaped field splitting is proved in
`Posix_Tools.Text.File_Magic_Fields`;
glob bracket-class closing search, negation, literal matching, and range
membership are proved in `Posix_Tools.Text.Glob_Fields`; byte classification and ASCII digit,
octal digit, hex digit, and letter construction are proved in
`Posix_Tools.Text.Byte_Classes`, including direct `xargs` blank splitting
predicates; LF segment counting, segment endpoint selection for
`Posix_Tools.Streams.Lines`, and `cmp` line-number scans are proved in
`Posix_Tools.Text.Line_Breaks`; default locale fallback selection and message
catalog path search ordering are proved in `Posix_Tools.Text.Locale_Fields`;
bounded natural-number
parsing for bases 2 through 16 is proved in `Posix_Tools.Text.Base_Parsing`; lowercase suffix
capacity arithmetic and suffix image construction for `split` are proved in
`Posix_Tools.Text.Suffixes`; positive, strictly ascending tab-stop list parsing
for `expand` and `unexpand` is proved in `Posix_Tools.Text.Tab_Stops`; logical
`PWD` validation for `pwd -L` is proved in `Posix_Tools.Text.Logical_Paths`;
portable filename component validation for `pathchk -p` is proved in
`Posix_Tools.Text.Portable_Paths`; POSIX `test` unary and binary operator
classification and signed numeric comparisons are proved in
`Posix_Tools.Text.Test_Operators`;
SHA256 checksum digest classification is proved in
`Posix_Tools.Text.Hex_Digests`;
`sort` key modifier classification is proved in
`Posix_Tools.Text.Sort_Modifiers`, along with the decision that disables
locale collation for transformed sort keys such as fold-case, dictionary-order,
and ignore-nonprinting comparisons, and complete `sort -k` field/character key
spec parsing; numeric sort key extraction and decimal comparison live in
`Posix_Tools.Text.Sort_Numeric`, which is kept outside SPARK because it depends
on CLDR locale digit, sign, and decimal-separator data;
`paste -d` delimiter escape decoding and cyclic delimiter selection are proved
in `Posix_Tools.Text.Paste_Delimiters`;
`find` expression-start classification is proved in
`Posix_Tools.Text.Find_Expressions`;
`expr` parsing, arithmetic/string evaluation, and BRE-style matching are
isolated in `Posix_Tools.Text.Expr_Expressions` as a non-SPARK recursive parser
and string-evaluation boundary because it depends on argument vectors,
unbounded string results, and backtracking regular-expression matching, and is
covered by command-level `expr` tests;
`od` address-base option classification and rendering, dump-format item parsing,
dump type-size marker parsing, shorthand format option classification and mapping, byte/unit image rendering,
little-endian unit assembly, and offset/count base and suffix parsing are proved in
`Posix_Tools.Text.OD_Formats`;
`kill` signal-name classification and optional `SIG` prefix handling are proved
in `Posix_Tools.Text.Signal_Names`;
`nl` numbering-mode letters, positive numeric option values, empty-line
classification, and logical section delimiter classification are proved in
`Posix_Tools.Text.NL_Fields`;
`nice -n` signed adjustment parsing is proved in
`Posix_Tools.Text.Nice_Fields`;
`xargs` command-size saturation arithmetic is proved in
`Posix_Tools.Text.Xargs_Fields`; `xargs` blank-, line-, and NUL-delimited stdin
tokenization is isolated in `Posix_Tools.Text.Xargs_Parsing` as a non-SPARK
boundary because it returns an argument vector with unbounded string-backed
items and is covered by command-level `xargs` tests;
fixed-width octal file-mode image construction plus any/all mode-bit,
set/clear/mask bit operations, `find -perm` octal/symbolic-mode routing, and
symbolic mode application used by `find -perm`, `chmod`, and `mkdir`,
including who-mask and permission-bit construction and symbolic permission
operation application, plus permission-match predicates for `stat`, `chmod`,
`mkdir`, `find`, and `test` are proved in
`Posix_Tools.Text.File_Modes`; fixed-width decimal, octal, and hexadecimal natural-number
image construction used by `date`, `stat`, `cmp`, and `od` is proved in
`Posix_Tools.Text.Numeric_Images`;
`find` expression-start and type-filter classification, type-match decisions,
count parsing, count-relation, age-window, and ownership-result comparison
semantics for type-, size-, mtime-, user-, and group-style predicates are proved in
`Posix_Tools.Text.Find_Expressions`;
`date` format-string rendering, localized month and weekday names, timezone
offset rendering, and POSIX/ISO week-number rendering are isolated in
`Posix_Tools.Text.Date_Formats` as a non-SPARK string-formatting boundary
because it depends on `Ada.Calendar`, localization, and unbounded string
assembly, and remains covered by command-level `date` tests;
`seq` printf-style format field selection, width parsing, precision parsing, and
conversion classification are proved in `Posix_Tools.Text.Seq_Formats`;
`printf` conversion rendering, field padding, and locale-specific decimal
rendering are isolated in `Posix_Tools.Text.Printf_Formats` and its
`Number_Images` child as a non-SPARK string-formatting boundary because they
depend on unbounded string assembly and CLDR locale numeric data, and remain
covered by command-level `printf` tests;
`stat` custom format rendering is isolated in `Posix_Tools.Text.Stat_Formats`
as a non-SPARK string-assembly boundary and covered by direct renderer tests
plus command-level `stat -c` tests;
natural-number parsing, signed long-integer parsing, decimal text classification,
decimal format-field scanning, negative-number operand recognition, signed-addition
overflow detection, scaled decimal-number parsing for `seq`,
fixed two-/four-digit value conversion, and bounded decimal range parsing with
value-returning range contracts are proved in `Posix_Tools.Text.Decimal_Parsing`; octal mode parsing used by mode-aware
commands is proved in `Posix_Tools.Text.Octal_Modes`; and bounded octal prefix
parsing for command escape sequences is proved in
`Posix_Tools.Text.Octal_Parsing`. Time-of-day field parsing for `HH:MM[:SS]`,
POSIX and ISO timezone offset parsing used by `date` and `touch`, plus
leap-year, month-length, and ordinal day-of-year arithmetic used by `date` are
proved in `Posix_Tools.Text.Time_Fields`. Free-form `touch`
month, weekday, relative-direction, relative-unit vocabulary, and POSIX
timestamp operand shape validation is proved in `Posix_Tools.Text.Touch_Fields`. Short-option
classification in `Posix_Tools.Option_Parsing` also exposes proved predicates
for cursor advancement, exact next-position movement for text-producing cases,
inline argument slice bounds, and source/status consistency for the non-SPARK
argument vector wrapper. `tail` count-origin parsing for `-n` and `-c` values is
proved in `Posix_Tools.Tail_Counts`, including the special `+N` from-start form
and the rejected bare `+` case.
The static command inventory data is proved in
`Posix_Tools.Command_Inventory.Tables`; the public
`Posix_Tools.Command_Inventory` lookup functions carry bounds on returned
executable names, crate names, package names, generated manifest paths,
generated project-file paths, documentation paths, and POSIX status strings
while delegating the repetitive command table cases to the child package.

The `Posix_Tools.Commands.Dispatcher` package is intentionally a
dispatcher-only boundary. Release metadata checks fail if command-local
`Run_*` implementations are added back there, and they require the extracted
`find`, `sort`, `test`, and `uniq` command bodies to remain delegated through
their own packages. That keeps non-SPARK command algorithms smaller and makes
future helper extraction for GNATprove more localized.

The host adapters, localization, process/environment interfaces, filesystem
operations, and packaging/test tooling remain outside GNATprove. Their boundary
is intentionally treated as host integration code and covered by tests and
metadata checks rather than SPARK proof. The stream, process, and filesystem
adapters expose runtime contracts for read-buffer bounds, failed-start status
bands, nonnegative file sizes, nonnegative read offsets, and current-directory
buffer bounds. Those contracts do not prove the operating-system calls behind
them.

The remaining non-SPARK package specs are deliberate boundaries: command specs
depend on the non-SPARK command context and result-dispatch surface; argument
and stream-line wrappers use `Ada.Containers.Indefinite_Vectors`; help,
presentation, and localization call terminal-style, message-catalog, or context
APIs; and host-adapter packages wrap operating-system behavior. Future proof
expansion should continue by extracting command-local pure parsing and
arithmetic helpers into small packages with direct contracts.
