# Development

Use Ada 2022 and Alire. Local development pins point at sibling crates for `hostkit`,
`i18n`, `messages`, `terminal_styles`, and `project_tools`.
Metadata validation also requires `posix_tools_common` to be pinned locally from
the root crate, every command crate, and the tests/tooling crate.

Normal checks are driven by the Ada executable `posix_tools_tests`.

Continuous integration is defined in `.github/workflows/ci.yml`. The workflow
runs the Ada `posix_tools_tests release-check` gate on Linux, macOS, and Windows
through Alire. Its repository checkouts use the Node 24-compatible checkout action
pinned by the release metadata gate, and the gate requires CI to check out
every sibling repository the crates' Alire `path` pins reach. After the gate, CI
fails if `git status --porcelain` finds a generated file that the gate rewrote
or wrote anew. Alire setup uses
the upstream `setup-alire` v6 branch because it carries the Node 24/cache v5
internals ahead of the next tagged setup-alire release. Local development should
run the same command before opening a release PR.

Selected GNATprove targets are run by `posix_tools_tests prove` through
`project_tools` against `common/posix_tools_proof.gpr`. `docs/proof-coverage.md`
is the maintained proof inventory: it lists the targets, what each covers, and
the current exclusions, including host adapter boundaries. The targets are
checked with Z3 in GNATprove proof mode with warnings and unproved checks
treated as errors. GNATprove still starts Why3 server processes for proof mode,
so restricted sandboxes may fail with local socket permission errors even when
the same command succeeds in a normal host execution context. Do not claim
functional proof beyond the executed GNATprove mode, target units, and
documented properties.

Project tooling must be Ada code using `project_tools`. Metadata checks reject
shell, Python, JavaScript, Make, CMake, PowerShell, and batch tooling files.
Ada sources must not silently discard failures with null handlers.

All maintained GPR projects compile warnings as errors. The core library,
root executable, tests, proof project, and grep also use the project style
switch set; thin command wrappers enforce the shared line-length limit. The
core profile deliberately omits GNAT's alphabetical-body-order and
body-must-have-a-prior-spec checks: local helpers are ordered by execution
flow, and small package bodies may keep private helpers body-local. Explore
retains those two additional checks. The metadata gate reads active Ada
`Default_Switches` declarations from
the packaged project inventory, so commented flags and build artifacts cannot
satisfy the policy.

Commands normally turn an unexpected exception into the localized, opaque
`internal failure` diagnostic. For local debugging only, setting
`POSIX_TOOLS_DEBUG` to a nonempty value appends Ada exception information to
standard error. An undefined or empty value keeps the diagnostic opaque.
