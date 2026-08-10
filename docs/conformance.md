# Conformance

Normative baseline: The Open Group Base Specifications, Issue 8,
IEEE Std 1003.1-2024, POSIX.1-2024.

The root `posix-tools` executable is outside POSIX conformance claims.

The current release gate runs on Linux, Windows, and macOS through CI. Each
runner builds the common crate, root executable, command subcrates, and tests
crate, then runs staged identity verification, metadata checks, conformance
metadata checks, formatting checks, and the AUnit suite. This establishes V1
platform validation for the implemented behavior, but it does not by itself
upgrade commands with remaining registry gaps to full POSIX conformance.

The Ada conformance tooling validates the generated requirements registry for
the expected CSV shape, unique requirement identifiers, linked validation
artifacts, allowed status values, POSIX.1-2024 baseline references,
documentation links for known deviations, matching deviation identifiers in
the linked documentation, and coverage for every released command in the
compiled inventory.

Tail follow mode is a known V1 deviation until implemented. Tail suffix
processing is implemented for `-n number` and `-c number`, including
host-backed spill storage when retained data exceeds the in-memory threshold
and remains within the configured spill limit.

`wc -m` uses deterministic incremental UTF-8 decoding through
`Posix_Tools.Text.UTF_8` and rejects malformed or incomplete sequences for
text-counting modes. Byte and line modes remain raw byte operations. Word
classification uses `Posix_Tools.Text.Classification`, backed by generated
`Posix_Tools.Text.Whitespace_Data` ranges with recorded Unicode 15.1.0 source
and license metadata. Full arbitrary POSIX locale character classification
remains open V1 acceptance work.

Formatted command data for `basename`, `dirname`, `echo`, `pwd`, and `wc` is
written through the shared raw output path with explicit LF terminators.

Selected usage and operational diagnostics are rendered through `messages`
catalog entries in the shared command helper, with deterministic locale tests
covering English fallback and Danish output.
