# Release Process

A release must build every crate, run the tests/tooling executable, verify
metadata consistency, generate documentation, and produce checksums.

The GitHub Actions workflow in `.github/workflows/ci.yml` installs GNATprove
and runs the Ada release gate on Linux, macOS, and Windows. A release candidate
should not be treated as platform-validated until all three CI jobs have passed
for the candidate commit.
The local metadata gate checks the workflow triggers, read-only repository
permission, non-fail-fast matrix, timeout, Node 24-compatible checkout action,
local sibling dependency checkouts, absence of direct Node 20-era setup/cache
action pins, Node 24-compatible setup-alire branch, tests-crate build step, and
release-check invocation so CI cannot silently stop exercising the Ada release
gate.

Current Ada tooling entry points:

- `posix_tools_tests check` validates metadata and runs the AUnit suite.
- `posix_tools_tests build` builds the root crate, every command subcrate, and
  the tests crate through Alire using `project_tools`.
- `posix_tools_tests docs` regenerates `generated/manual-index.md`.
- `posix_tools_tests prove` runs selected SPARK-enabled GNATprove targets
  directly through `project_tools` against `common/posix_tools_proof.gpr` when
  GNATprove is installed.
- `posix_tools_tests package` regenerates `generated/package-manifest.txt`
  with byte counts and FNV-1a checksums for packaged files.
- `posix_tools_tests release-check` and `release` regenerate
  `generated/release-checksums.txt` with FNV-1a checksums for the package
  manifest, source release archive, and built executables.
- `posix_tools_tests release-check` regenerates the current generated docs and
  package manifest, builds the root crate, every command subcrate, and the
  tests crate, verifies the exact built root and command executables by internal
  identity, executes built binaries for version-output and representative
  command-data smoke coverage, validates metadata, runs format checks, validates
  conformance metadata, runs the selected GNATprove targets, and
  runs the AUnit suite.
- Metadata validation asserts that the `release-check` branch names the selector
  smoke, staged verification, executable smoke, source archive, release checksum,
  metadata, format, conformance, proof, and AUnit steps.
- Metadata validation asserts that the CI workflow installs GNATprove through
  Alire and exposes the Alire installation prefix on the runner path before it
  runs the Ada release gate that owns proof execution.
- Metadata validation also asserts that the `release` branch runs clean-tree
  enforcement before release generation/build work and reports completion
  through the Ada project_tools driver.
- The metadata gate validates package-manifest coverage from the compiled Ada
  command inventory for each command manifest, project file, wrapper source,
  reference document, and generated manual page.
- Each command manifest is validated against the compiled command inventory for
  crate name, executable name, synchronized version, MIT license, author and
  maintainer metadata, project-file declaration, local common dependency and
  pin, and coordinated build profile.
- The metadata gate also checks that the Ada build driver names the common
  crate, root crate, tests crate, and every command build label derived from the
  compiled command inventory.
- The metadata gate checks that staged verification invokes the bounded identity
  adapter for the built root executable and every command executable derived
  from the compiled command inventory.
- Generated manual pages are created by the Ada tooling from the compiled
  command inventory and the per-command reference documents. The metadata gate
  compares the manual index, root manual page, and every command manual page
  byte-for-byte against the expected current content and requires every
  generated manual page to appear in the package manifest.
- The metadata gate requires the AI-oriented project guide and checks its
  repository map, package map, dependency rules, import boundaries, workflow,
  testing, localization, styling, resource, completion, and rejected architecture
  sections.
- The metadata gate checks that the Ada format scanner and testing guide cover
  maintained Ada, Alire/GPR, Markdown, CSV, and text files for tabs, trailing
  whitespace, and multiple consecutive blank lines.
- The metadata gate also verifies that every entry in
  `generated/package-files.txt` has exactly one current checksum row in
  `generated/package-manifest.txt`, that the manifest carries the synchronized
  version header, and that the manifest has no extra data rows beyond its
  header.
- The package file-list gate requires release-critical metadata to be packaged:
  the CI workflow, command inventory, requirements, regressions, generated
  manual index, and package file list. The generated package manifest and
  release checksum file are validated separately as release outputs around the
  archive.
- The proof gate runs selected GNATprove targets directly, including the root
  SPARK boundary, version metadata predicates, numeric parsing, lexical paths,
  UTF-8 decoding, Unicode whitespace classification, text stream counting
  arithmetic, head/tail count-window arithmetic, tail count-origin parsing,
  tail ring-buffer index
  arithmetic, `wc` decimal field-width arithmetic, process status-code ranges,
  command result records, text escaping length rules, and LF line-segment
  arithmetic and line-number scans, ASCII/POSIX byte-class predicates, substring predicates, and
  direct `xargs` blank splitting, `find` expression, type-filter, type-match,
  count parsing, count-relation, age-window, and ownership-result
  predicates, bounded decimal range parsing, short-option decisions, signal-name
  classification, `sort` transformed-key locale-collation decisions and `-k`
  positive key-number parsing, `nl` field classification, fixed-width file-mode, any/all
  mode-bit, set/clear/mask bit, `find -perm` octal/symbolic routing,
  symbolic mode application for `find`, `chmod`, and `mkdir`, permission-match,
  numeric, and split-suffix image construction, and octal mode parsing.
  Time-of-day field parsing and free-form `touch` date vocabulary are also
  covered by the selected proof targets.
  `docs/proof-coverage.md` records the integrated target inventory,
  host-boundary exclusions, and current analyzer limitations. The selected units
  run with Z3 in proof mode, with warnings and unproved checks treated as
  errors. The integrated suite uses level 1 by default and includes an
  additional level-2 pass for `Posix_Tools.Text.File_Modes`.
  GNATprove proof mode still depends on Why3 local server processes, so the
  release proof gate must run in an execution context that permits those local
  sockets.
- The metadata gate verifies that `generated/release-checksums.txt` contains
  exactly the synchronized version header, package-manifest row, source-archive
  row, root executable row, and one row for every command executable from the
  compiled Ada inventory. When the referenced artifact exists, the gate
  recomputes and validates the recorded FNV-1a value.
- Version synchronization is checked as exact current lines across the root,
  common, tests, and command Alire manifests, the compiled
  `Posix_Tools.Version.Version_String` metadata, the changelog, and generated
  documentation, package-manifest, and release-checksum headers.
- The release message catalog is validated as a required source file, selected
  release locale identifiers are checked by metadata validation, and the catalog
  must appear in the generated package manifest.
- The release gate writes `dist/posix-tools-<version>-source.7z` from
  `generated/package-files.txt`, immediately runs a 7z archive integrity test,
  and records the archive checksum. `dist/` is ignored because release archives
  are reproducible outputs, while their checksums are recorded in generated
  metadata.
- `posix_tools_tests release` first requires `git status --porcelain` to report
  a clean source tree, then runs the same implemented gates as `release-check`
  and reports completion.
