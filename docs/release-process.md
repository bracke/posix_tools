# Release Process

A release must build every crate, run the tests/tooling executable, verify
metadata consistency, generate documentation, and produce checksums.

The GitHub Actions workflow in `.github/workflows/ci.yml` installs GNATprove
15.1.0 and runs the Ada release gate on Linux, macOS, and Windows. A release candidate
should not be treated as platform-validated until all three CI jobs have passed
for the candidate commit.
After the gate, the workflow fails if `git status --porcelain` reports anything:
release-check regenerates the docs, man pages, command inventory, and package
manifest before checking them, so only git can see that the committed copies
were stale or that a newly generated file was never committed. Every
runner checks files out with `core.autocrlf` off, because the manifest records
each file's size and checksum and a Windows CRLF checkout would change them.
The local metadata gate checks the workflow triggers, read-only repository
permission, non-fail-fast matrix, timeout, Node 24-compatible checkout action,
sibling dependency checkouts, absence of direct Node 20-era setup/cache
action pins, Node 24-compatible setup-alire branch, tests-crate build step, the
release-check run line, and the drift check, so CI cannot silently stop
exercising the Ada release gate. The sibling checkouts it requires are the
repositories the crates' `path` pins reach, followed through the pinned
manifests, not a hand-kept list. The checkouts follow each sibling's default
branch; they are not pinned to a commit.

Current Ada tooling entry points (`docs/testing.md` lists each one's steps
in order):

- `posix_tools_tests check` runs the metadata, format, and conformance metadata
  checks and the AUnit suite.
- `posix_tools_tests build` builds the root crate, every command subcrate, and
  the tests crate through Alire using `project_tools`, then runs the metadata
  checks.
- `posix_tools_tests format-check`, `conformance`, and `prove` run the metadata
  checks first and then their own checks.
- `posix_tools_tests docs` regenerates `docs/commands/index.md`,
  `generated/command_inventory.csv`, `generated/manual-index.md`, and
  `generated/man/*.1`, then runs the metadata checks.
- `posix_tools_tests prove` runs selected SPARK-enabled GNATprove targets
  directly through `project_tools` against `common/posix_tools_proof.gpr` when
  GNATprove is installed.
- `posix_tools_tests package` regenerates `generated/package-files.txt` and
  `generated/package-manifest.txt`, with byte counts and FNV-1a checksums for
  packaged files, writes and tests the source archive in `dist/` with `7z` or
  `7zz` (one must be on the path), then runs the metadata checks.
- Only `posix_tools_tests release` writes `generated/release-checksums.txt`,
  with FNV-1a checksums for the package manifest, source release archive, and
  built executables, and the file is committed with the release. Between
  releases it is that release's record: no other command writes or checks it,
  so local builds, new commands, and version bumps leave it as it is.
- `posix_tools_tests release-check` regenerates the current generated docs and
  package manifest, builds the root crate, every command subcrate, and the
  tests crate, verifies the exact built root and command executables by internal
  identity, executes built binaries for version-output and representative
  command-data smoke coverage, validates metadata, runs format checks, validates
  conformance metadata, runs the selected GNATprove targets, and
  runs the AUnit suite.
- Metadata validation checks the subcommands' step lists in
  `tests/src/tooling_steps.ads`, which the driver runs: release-check runs the
  selector smoke, staged verification, executable smoke, source archive,
  metadata, format, conformance, proof, and AUnit steps, with the build before
  the smoke tests; release runs the same steps in the same order behind a
  clean-tree check and adds the release checksums after the archive.
- Metadata validation asserts that the CI workflow installs GNATprove through
  Alire and exposes the Alire installation prefix on the runner path before it
  runs the Ada release gate that owns proof execution.
- The metadata gate requires the package entries to be exactly the files git
  tracks, the package file list to be exactly those entries, and the manifest
  to hold one current row for each, so every command manifest, project file,
  wrapper source, reference document, and generated manual page is covered.
- Each command manifest is validated against the compiled command inventory for
  crate name, executable name, synchronized version, MIT license, author and
  maintainer metadata, project-file declaration, local common dependency and
  pin, and coordinated build profile.
- The metadata gate also checks that the Ada build driver names the common
  crate, root crate, tests crate, and every command build label derived from the
  compiled command inventory.
- Generated manual pages are created by the Ada tooling from the compiled
  command inventory and the per-command reference documents. The metadata gate
  compares the manual index, root manual page, and every command manual page
  byte-for-byte against the expected current content; as tracked files they
  are package entries with manifest rows.
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
- During a release, the metadata gate verifies that
  `generated/release-checksums.txt` contains
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
  a clean source tree, then runs the same implemented gates as `release-check`,
  writes and checks the release checksums, and reports completion.
