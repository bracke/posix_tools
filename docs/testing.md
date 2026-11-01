# Testing

The `posix_tools_tests` crate is the home for unit, command, root, adapter,
integration, conformance, and regression tests. It uses an AUnit aggregate
suite exposed by `All_Suites.Suite`.

The executable accepts:

- `test`
- `test --suite <name>`
- `test --suite property`
- `test --category unit`
- `test --category integration`
- `test --category conformance`
- `test --category regression`
- `test --category locale`
- `test --category presentation`
- `build`
- `check`
- `format-check`
- `docs`
- `conformance`
- `prove`
- `package`
- `release-check`
- `release`

Invoking `posix_tools_tests` with no arguments runs the normal AUnit suite.
The `--suite` selector names a group of tests or one command's tests. The
groups `basic` (or `common`), `streams`, `regression`, `locale`,
`presentation`, `property`, and `command` (all command-package tests) select
every test whose name starts with the group. A command name such as `wc`,
`tail`, or `root` selects that command's tests by their whole name: `tr` selects
`command:tr ...` but not `command:true ...`, and `id` does not select
`command:identity ...`. Unknown suite names fail with usage status instead of
running an empty AUnit selection. Category selectors map `unit` to the full suite,
`integration` to root-command integration-shaped tests, `conformance` to
inventory/conformance metadata tests, and `regression` to regression-prefixed
tests. `locale` selects locale-dependent help and diagnostic tests.
`presentation` selects terminal styling boundary tests.

## What each subcommand runs

Each subcommand runs a fixed list of steps, in order. The lists are in
`tests/src/tooling_steps.ads`; the driver runs exactly those lists, and the
metadata checks hold the lists to their rules (release is release-check on a
clean tree plus the release checksums, the build comes before the smoke tests,
and whatever writes generated files is followed by the metadata checks).

- `test`: the AUnit suite, or the part of it a selector names.
- `check`: the metadata checks, the format checks, the conformance metadata
  checks, and the AUnit suite.
- `build`: builds the common crate, the root crate, every command crate and
  the tests crate through Alire, and on POSIX hosts builds and runs explore's
  two test crates; then the metadata checks.
- `format-check`: the metadata checks, then the format checks.
- `conformance`: the metadata checks, then the conformance metadata checks.
- `prove`: the metadata checks, then the GNATprove targets.
- `docs`: writes `docs/commands/index.md`, `generated/command_inventory.csv`,
  `generated/manual-index.md`, and `generated/man/*.1` from the compiled
  inventory and `docs/commands/*.md`; then the metadata checks.
- `package`: writes `generated/package-files.txt` and
  `generated/package-manifest.txt`, then writes and integrity-tests
  `dist/posix-tools-<version>-source.7z`, which needs `7z` or `7zz` on the
  path; then the metadata checks.
- `release-check`: `docs` and the package manifest, the build, the selector
  smoke, staged identity verification, the executable smoke, and the release
  archive; then the metadata, format, conformance metadata, and proof checks
  and the AUnit suite.
- `release`: requires a clean source tree, then runs the release-check steps
  with `generated/release-checksums.txt` written after the archive.

Current registered suites include path tests, numeric tests, tail ring arithmetic tests, and wc field arithmetic tests.
They also include stream LF segment tests, stream byte and UTF-8 counting tests, command-package tests, root-command
tests, locale-dependent help and diagnostic tests, and regression coverage for binary fixtures, command option
ordering, `env` utility status propagation, verbose output failures in `cp`, `ln`, `mv`, and `rm`, `xargs` status
classification, `head`, `tail`, and `wc`.

Deterministic property coverage uses fixed seeds that are reported in assertion
labels, which are built from the seed constant each test starts from. The initial property suite exercises generated slash-only pathname
invariants for `basename` and `dirname` with seed `0x50540001`, and generated
byte-stream LF segment split/reassembly with seed `0x50540002`. Shared parser
coverage generates grouped short options and unknown options with seed
`0x4F505453`. Command-level property coverage also exercises `cat` byte
preservation for implicit standard input and explicit `-` standard input with
seed `0x50540003`, generated `basename`/`dirname` command output with seed
`0xBA5ED123`, generated `echo` operand-vector output with seed `0xEC400001`,
generated `true`/`false` operand-ignore behavior with seed `0x7F00F15E`,
generated `pwd` option-precedence behavior with seed `0x50574431`, generated
`head -n` file-prefix behavior with seed `0x48454144`, generated `head -n`
standard-input prefix behavior with seed `0x4845AD15`,
generated `tail -c` file-suffix behavior with seed `0x5441494C`, generated
`tail -c` standard-input suffix behavior with seed `0x54414953`, `wc -c`
file-input equivalence to input byte length with seed `0x5EEDC0DE`, `wc -c`
standard-input equivalence with seed `0x57C00001`, `wc -l` file-input
equivalence to LF byte count with seed `0x1F1E5EED`, and `wc -l`
standard-input equivalence with seed `0x57C0000A`. Inventory-derived coverage
also checks `posix-tools list`, `paths`, and `verify` inventory ordering, plus
`posix-tools help <command>` output for every compiled command against direct
command metadata. Locale tests also verify that `posix-tools list` command data,
all executable version output, both root version entry points, and all internal
identity output do not change across default, English, Danish, and unknown
locales; `posix-tools verify` status labels are checked against English fallback
and Danish catalogs. Presentation tests check forced styled, forced unstyled,
and automatic redirected command help, root help, and diagnostic rendering,
including independent stdout and stderr terminal-state checks. Generated
`tail -n` LF line suffix behavior uses seed `0x5441494E`.

`Test_Contexts.Capturing_Context` provides deterministic arguments, stdout,
stderr, environment values, physical current-directory values, and raw standard
input bytes. Command tests use it to verify standard-input behavior without
mutating process global streams. It can also force stdout failure after a
selected byte count so command tests can verify partial-write handling and
aggregate failure status.

`posix_tools_tests build` invokes Alire through `project_tools` for the root
crate, every command subcrate, and the tests crate. It also runs `explore`'s
own two test crates. `tools/explore/tests` tests explore's packages directly.
`tools/explore/e2e` runs the built `explore` end to end: in a pseudo-terminal
from bracke-terminal's `terminal_pty`, with bracke-terminal's emulator core,
`terminal_core`, on the other side in place of its window. The core answers
explore's identity, device-attribute, and size queries, receives its graphics
and clipboard requests, and keeps the screen it draws, which the tests read cell
by cell: starting and quitting with every terminal mode restored, browsing and
previews, a copy, a resize, the clipboard, an image placed with placeholders,
and a shell command run on the main screen. The same crate times explore on a
directory of 100,000 entries against its budgets: the first frame, handshake
included, within 100 milliseconds, and every key -- moving, jumping to the
end, typing a filter -- answered within 100 milliseconds whether or not the
directory is still being read. It needs the `terminal` repository checked out
beside this one.
The release gates run selector smoke tests for `--suite cat`, `--suite cp`,
`--suite tr`, `--suite id`, `--suite xargs`, `--suite root`, `--suite command`,
`--suite property`, `--category unit`, `--category integration`,
`--category conformance`, `--category regression`, `--category locale`, and
`--category presentation` through `project_tools` process execution after the
tests executable is built. Each selector runs once, and its report must name
the tests it selects and none it does not: `--suite cat` runs no `command:cp`
test, `--suite tr` no `command:true` test, and the categories no command tests.
They also verify that incomplete or unknown selectors fail with usage status 2
instead of silently broadening or ignoring the requested filter.
`posix_tools_tests format-check` scans maintained Ada, Alire/GPR, Markdown, CSV,
and text files for tab characters, trailing whitespace, and multiple
consecutive blank lines, skipping generated build outputs and binary fixtures.
`posix_tools_tests prove` invokes selected GNATprove targets directly through
`project_tools` against `common/posix_tools_proof.gpr`. The maintained target
inventory and documented non-SPARK boundaries are in `docs/proof-coverage.md`;
metadata checks keep that document synchronized with SPARK-enabled package
specs and the curated proof target list. These selected units enable
`SPARK_Mode` and are checked with Z3 in proof mode, warnings as errors, and
unproved checks treated as errors; this does not claim functional proof beyond
the executed GNATprove mode and units.
Restricted sandboxes may block Why3's local proof-server socket; in that case,
run the same `prove` command in a normal host execution context.
