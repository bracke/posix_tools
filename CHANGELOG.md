# Changelog

## 0.1.0

- Initial coordinated V1 repository with the root `posix_tools` crate, shared `posix_tools_common` library
  crate, tests/tooling crate, and one binary subcrate per compiled command.
- Compiled command inventory includes 31 POSIX-style utilities plus the non-POSIX `posix-tools` management
  executable; `awk`, `grep`, and `sed` are integrated command wrappers backed by sibling language/search
  libraries.
- Added structured command metadata, generated manual pages, command reference documents, conformance registry,
  regression registry, package manifest, release checksums, and source archive generation.
- Added messages-backed locale support for help and diagnostics, with command data output kept locale-invariant.
- Added host adapter boundaries for environment, filesystem, process, stream, signal, and terminal integration.
- Added release gates for inventory consistency, executable smoke tests, staged identity verification,
  archive integrity, checksum coverage, documentation consistency, formatting, conformance metadata, and selected
  proof targets.
- Added the native Ada `rg` crate, ripgrep 15.2.0 syntax-policy adapter, bounded sequential standard-input and file
  search, recursive traversal, hidden and maximum-depth controls, and lazy hierarchical `.gitignore`, `.ignore`,
  and `.rgignore` evaluation through `versionlib`; line, byte-column, and filename rendering; inverted selection and
  per-file match limits; quiet, selected-line count, match-count, match-only, files-with-matches, and
  files-without-match result modes; `--files` discovery and ordered `-g` path overrides through the shared traversal
  policy and `Version.Ignore.Wildcard_Matches`; ordered bounded `-f` pattern-file and standard-input sources;
  the pinned ripgrep 15.2.0 file-type catalog with `-t`, `-T`, and `--type-list`; compiled inventory registration;
  scoped parent ignore loading, `--no-ignore-vcs`, `--no-ignore-parent`, `-u`, `-uu`, and binary-searching `-uuu`;
  NUL-based `--binary` and `--text` input policies with bounded named-file prescans and standard-input spooling;
  traversal-time `--max-filesize`; bounded merged `-A`, `-B`, and `-C` context windows with configurable group
  separators; automatic and explicit per-file heading output; and AUnit coverage.
- Added independent NUL pathname output and NUL-delimited search-record modes to `rg`, plus safe `-L`/`--follow`
  traversal with ancestor-loop detection, broken-link diagnostics, and per-root `--one-file-system` boundaries.
- Added bounded `-U`/`--multiline` matching with dotall control, spanning-match rendering, context, counts,
  inversion, match-only fragments, and explicit incompatibility diagnostics for NUL-data mode.
- Added bounded `-r`/`--replace` output with ripgrep-compatible numbered and named capture expansion,
  literal-dollar handling, ordered pattern-set capture numbering, match-only output, context integration, and
  transformed-line grouping for replacements that span, remove, or introduce multiline record boundaries.
- Added bounded sorting for `rg --sort` and `--sortr`: per-root pathname order plus global, stable modification,
  access, and filesystem-supported creation-time order across discovered files, explicit operands, and stdin.
- Added `rg --stats` accounting for matches, selected lines, files, searched and rendered bytes, and measured search
  and total durations, including full-search quiet behavior and multiline, inverted, and maximum-count modes.
- Added `rg --color auto|always|never|ansi` output policy with span-level match highlighting and styled path and
  position metadata, using `terminal_styles` terminal policy without mutating process-wide state during rendering.
- Added iterative `rg --colors` rules for the named path, line, column, match, and highlight roles, including
  named, indexed 256-color, and RGB foreground/background colors, style toggles, role resets, and range-checked
  numeric parsing compatible with the pinned ripgrep SGR output.
- Added line-oriented `rg --json` output with begin, match, context, end, and summary events; byte-accurate offsets
  and submatches; replacement fields; aggregate statistics; and UTF-8 text or base64 byte values.
- Added bounded streaming `rg -E`/`--encoding` support for all 40 decoders and
  all 228 labels from ripgrep 15.2.0's pinned `encoding_rs` 0.8.35 WHATWG data,
  including exact malformed-sequence replacement, byte reconsumption, decoded
  offsets, and statistics.
- Added Unicode 16.0 simple case folding to `regexp` and rg regex/fixed-string
  searches, plus Unicode `Uppercase` property detection for smart case.
- Added complete Unicode 16.0 word classification and the `regex-syntax` 0.8.11
  property/alias inventory to `regexp`; `rg -w`, `\w`, and `\p{...}` now retain
  byte offsets across general Unicode text. Malformed UTF-8 is skipped as a
  nonmatching barrier, and JSON searches NUL-bearing inputs while reporting the
  reference-compatible binary offset.
- Added structured `rg --debug` and `--trace` diagnostics for configuration, regex compilation, ignore-rule
  provenance, path filtering, binary detection, search strategies, and per-file completion events.
- Extended `rg --json` to NUL-delimited `--null-data` searches, preserving escaped NUL record terminators,
  absolute offsets, context records, replacements, and statistics in the JSON Lines event stream.
- Extended `rg --json` to bounded multiline searches with complete touched-record events, block-relative
  submatch offsets, context and inverted records, zero-length progress, and replacement metadata.
- Added bounded native Ada task pools for `rg -j`/`--threads` searches across recursive discoveries, explicit files,
  and independent directory roots, with immutable shared compiled expressions, worker-local cursors, protected job
  and output coordination, deterministic whole-file emission, quiet/output-failure cancellation, a 64-worker
  ceiling, and explicit per-file output-buffer exhaustion.
- Completed nested scoped `(?u:...)` and `(?-u:...)` byte/Unicode matching in `regexp`, including preserved byte
  offsets, malformed UTF-8 barriers, and differential `rg` coverage against ripgrep 15.2.0.
- Completed messages-backed localization for `rg` parser, regex, traversal, input, worker, resource-limit, color,
  and output diagnostics in English, Danish, and Spanish.
- Added deterministic differential, property, and injected-fault coverage for `rg`; added a Linux
  ThreadSanitizer gate and removed a worker-context initialization race found by it.
- Added a proved SPARK queue-state model for bounded `rg` worker scheduling and documented requirement-to-test
  traceability for regex, ignore, input, rendering, localization, concurrency, and robustness behavior.
