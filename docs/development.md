# Development

Use Ada 2022 and Alire. Local development pins point at sibling crates for `hostkit`,
`messages`, `terminal_styles`, and `project_tools`.
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

Selected GNATprove targets are run by `posix_tools_tests prove` through Alire
and `project_tools`. The current targets are `posix_tools.numbers`,
`posix_tools.paths`, `posix_tools.text.utf_8`, `posix_tools.counts`,
`posix_tools.tail_rings`, and `posix_tools.wc_fields`, matching the initial
focus on numeric parsing, lexical pathname algorithms, UTF-8 decoder state,
head/tail count-window arithmetic, tail ring-buffer index arithmetic, and `wc`
decimal field-width arithmetic. These selected units
explicitly enable `SPARK_Mode` and are checked in GNATprove flow mode. Do not
claim functional proof beyond the executed GNATprove mode, target units, and
documented properties.

Project tooling must be Ada code using `project_tools`. Metadata checks reject
shell, Python, JavaScript, Make, CMake, PowerShell, and batch tooling files.
Ada sources must not silently discard failures with null handlers.
