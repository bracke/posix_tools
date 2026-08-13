# Conformance

Normative baseline: The Open Group Base Specifications, Issue 8,
IEEE Std 1003.1-2024, POSIX.1-2024.

The root `posix-tools` executable is outside POSIX conformance claims.

The current release gate runs on Linux, Windows, and macOS through CI. Each
runner builds the common crate, root executable, command subcrates, and tests
crate, then runs staged identity verification, metadata checks, conformance
metadata checks, formatting checks, and the AUnit suite. This establishes V1
platform validation for the implemented behavior tracked in the conformance
registry.

The Ada conformance tooling validates the generated requirements registry for
the expected CSV shape, stable uppercase requirement identifier syntax, unique
requirement identifiers, linked validation artifacts, allowed status values,
POSIX.1-2024 baseline references, existing implementation references for Ada
units and repository paths, test references for AUnit routines, regression
records, documentation paths, and explicit Ada tooling or CI validation
artifacts, documentation links for known deviations, matching deviation
identifiers in the linked documentation, synchronized known-deviation status
between requirement rows and the compiled command inventory, and coverage for
every released command in the compiled inventory. It also validates the
regression registry for row shape, stable regression identifier syntax,
duplicate identifiers, required command and summary fields, linked AUnit or
explicit validation artifacts, and a bidirectional link from every regression
identifier back to at least one requirement validation field. The same
conformance pass validates
the generated command inventory CSV header, row count, deterministic ordering,
field values against the compiled Ada inventory, and existence of every
referenced command manifest, project file, reference document, and wrapper
source.

The metadata release gate requires each per-command reference document,
including the non-POSIX root executable reference, to carry the V1 command
reference sections defined by the project documentation policy. It also
compares the generated command inventory CSV byte-for-byte against the compiled
Ada command inventory, and compares the generated manual index plus every
generated manual page against the compiled inventory metadata and command
reference document sections with explicit line-ending normalization. The
repository line-ending policy pins generated CSV and text metadata to LF so
these comparisons remain deterministic on Windows, Linux, and macOS checkouts.

Tail suffix processing is implemented for `-n number` and `-c number`,
including host-backed spill storage when retained data exceeds the in-memory
threshold and remains within the configured spill limit. Follow mode is a V1
known deviation tracked as `TAIL-FOLLOW-001`: `-f`, `-F`, and `--follow` are
accepted as finite option spellings that emit the currently available suffix and
exit; live waiting and reopen behavior are not implemented in this release.

`wc -m` uses deterministic incremental UTF-8 decoding through
`Posix_Tools.Text.UTF_8` and rejects malformed or incomplete sequences for
text-counting modes. Byte and line modes remain raw byte operations. Word
classification uses `Posix_Tools.Text.Classification`, backed by generated
`Posix_Tools.Text.Whitespace_Data` ranges with recorded Unicode 15.1.0 source
and license metadata. This is a documented V1 extension rather than full
arbitrary POSIX locale character classification.

Formatted command data for `basename`, `dirname`, `echo`, `pwd`, and `wc` is
written through the shared raw output path with explicit LF terminators.

Selected usage and operational diagnostics are rendered through `messages`
catalog entries in the shared command helper, with deterministic locale tests
covering English fallback, Danish output, Spanish output, unknown-locale
fallback, and missing-message fallback. Human diagnostics pass through the
project presentation adapter with stderr terminal status, so redirected
diagnostics remain plain text.
