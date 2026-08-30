# Development

Use Ada 2022 and Alire. Local development pins point at sibling crates for `hostkit`,
`i18n`, `messages`, `terminal_styles`, and `project_tools`.
Metadata validation also requires `posix_tools_common` to be pinned locally from
the root crate, every command crate, and the tests/tooling crate.

Normal checks are driven by the Ada executable `posix_tools_tests`.

Continuous integration is defined in `.github/workflows/ci.yml`. The workflow
runs the Ada `posix_tools_tests release-check` gate on Linux, macOS, and Windows
through Alire. Its repository checkouts use the Node 24-compatible checkout action
pinned by the release metadata gate, and the gate requires CI to check out the
same sibling dependency repositories used by local Alire pins. Alire setup uses
the upstream `setup-alire` v6 branch because it carries the Node 24/cache v5
internals ahead of the next tagged setup-alire release. Local development should
run the same command before opening a release PR.

Selected GNATprove targets are run by `posix_tools_tests prove` through
`project_tools` against `common/posix_tools_proof.gpr`. The current targets are
`posix_tools`, `posix_tools.version`, `posix_tools.numbers`,
`posix_tools.paths`, `posix_tools.text.utf_8`,
`posix_tools.text.classification`, `posix_tools.text.whitespace_data`,
`posix_tools.streams.counting`, `posix_tools.counts`, `posix_tools.tail_rings`,
`posix_tools.wc_fields`, `posix_tools.exit_status`,
`posix_tools.commands.results`, `posix_tools.text.escaping`,
`posix_tools.text.line_breaks`, `posix_tools.text.byte_classes`,
`posix_tools.text.matching`, `posix_tools.text.printf_escapes`,
`posix_tools.text.decimal_parsing`,
`posix_tools.option_parsing`, `posix_tools.text.octal_modes`,
`posix_tools.text.octal_parsing`, and `posix_tools.text.time_fields`, matching
the focus on the root SPARK boundary, version metadata predicates, numeric parsing,
lexical pathname algorithms, UTF-8 decoder state, Unicode whitespace
classification, text stream counting arithmetic, head/tail count-window
arithmetic, tail ring-buffer index arithmetic, `wc` decimal field-width
arithmetic, process status-code ranges, command result records, text escaping
length rules, LF line-segment arithmetic, ASCII/POSIX byte-class predicates,
substring predicates, bounded decimal range parsing, short-option decisions, and
octal mode parsing, and time-of-day field parsing. `docs/proof-coverage.md` is
the maintained proof inventory and records current exclusions, including host
adapter boundaries. These selected
units are checked with Z3 in GNATprove proof mode at level 1 with warnings and
unproved checks treated as errors. GNATprove still starts Why3 server processes
for proof mode, so restricted sandboxes may fail with local socket permission
errors even when the same command succeeds in a normal host execution context.
Do not claim functional proof beyond the executed GNATprove mode, target units,
and documented properties.

Project tooling must be Ada code using `project_tools`. Metadata checks reject
shell, Python, JavaScript, Make, CMake, PowerShell, and batch tooling files.
Ada sources must not silently discard failures with null handlers.
