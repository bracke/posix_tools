# Testing

The `posix_tools_tests` crate is the home for unit, command, root, adapter,
integration, conformance, and regression tests. It uses an AUnit aggregate
suite exposed by `All_Suites.Suite`.

The executable accepts:

- `test`
- `test --suite <name>`
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
The `--suite` selector maps to AUnit test-name prefixes such as `basic`,
`streams`, `root`, `wc`, `tail`, and other command names. `command` selects all
command-package tests. Category selectors map `unit` to the full suite,
`integration` to root-command integration-shaped tests, `conformance` to
inventory/conformance metadata tests, and `regression` to regression-prefixed
tests. `locale` selects locale-dependent help and diagnostic tests.
`presentation` selects terminal styling boundary tests.

Current registered suites include basic path and numeric tests, stream LF
segment tests, stream byte and UTF-8 counting tests, command-package tests,
root-command tests, locale-dependent help and diagnostic tests, and regression
coverage for binary fixtures, `head`, `tail`, and `wc`.

Deterministic property coverage uses fixed seeds that are reported in assertion
labels. The initial property suite exercises generated slash-only pathname
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
all executable version output, and all internal identity output do not change
across default, English, Danish, and unknown locales. Generated `tail -n` LF line
suffix behavior uses seed `0x5441494E`.

`Test_Contexts.Capturing_Context` provides deterministic arguments, stdout,
stderr, environment values, physical current-directory values, and raw standard
input bytes. Command tests use it to verify standard-input behavior without
mutating process global streams. It can also force stdout failure after a
selected byte count so command tests can verify partial-write handling and
aggregate failure status.

`posix_tools_tests check` validates metadata, runs format checks, validates
conformance metadata, and runs the AUnit suite. `posix_tools_tests docs` writes
`generated/manual-index.md` from the compiled command inventory and then runs
metadata validation.
`posix_tools_tests build` invokes Alire through `project_tools` for the root
crate, every command subcrate, and the tests crate.
The release gates run selector smoke tests for `--suite cat`, `--suite command`,
`--category unit`, `--category integration`, `--category conformance`,
`--category regression`, `--category locale`, and `--category presentation`
through `project_tools` process execution after the tests executable is built.
They also verify that incomplete or unknown selectors fail with usage status 2
instead of silently broadening or ignoring the requested filter.
`posix_tools_tests format-check` scans maintained Ada, Alire/GPR, Markdown, CSV,
and text files for tab characters, trailing whitespace, and multiple
consecutive blank lines, skipping generated build outputs and binary fixtures.
`posix_tools_tests prove` invokes selected GNATprove flow-analysis targets
through `project_tools` and Alire for `Posix_Tools.Numbers`,
`Posix_Tools.Paths`, and `Posix_Tools.Text.UTF_8`. These selected units enable
`SPARK_Mode` and are checked as flow-analysis targets; this does not claim
functional proof beyond the executed GNATprove mode and units.
