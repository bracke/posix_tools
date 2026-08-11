# Development

Use Ada 2022 and Alire. Local development pins point at sibling crates for `hostkit`,
`messages`, `terminal_styles`, and `project_tools`.
Metadata validation also requires `posix_tools_common` to be pinned locally from
the root crate, every command crate, and the tests/tooling crate.

Normal checks are driven by the Ada executable `posix_tools_tests`.

Continuous integration is defined in `.github/workflows/ci.yml`. The workflow
runs the Ada `posix_tools_tests release-check` gate on Linux, macOS, and
Windows through Alire. Local development should run the same command before
opening a release PR.

Selected GNATprove targets are run by `posix_tools_tests prove` through Alire
and `project_tools`. The current targets are `posix_tools.numbers`,
`posix_tools.paths`, and `posix_tools.text.utf_8`, matching the initial focus
on numeric parsing, lexical pathname algorithms, and UTF-8 decoder state.
Current output is proof-readiness evidence only unless the target unit
explicitly enables SPARK_Mode and the checked property is documented.

Project tooling must be Ada code using `project_tools`. Metadata checks reject
shell, Python, JavaScript, Make, CMake, PowerShell, and batch tooling files.
Ada sources must not silently discard failures with null handlers.
