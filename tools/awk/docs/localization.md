# Localization

CLI-authored user-facing text is rendered through `messages` using keys under `awk.`. English and Danish shard catalogs are included. The combined catalog also includes translations for the supported European state-language locale set.

The Ada workflow validates every supported locale in the combined catalog and
validates the English and Danish shard catalogs. Required messages must be
non-empty, and placeholder sets must match English for each key in every
supported locale. It also runs `Messages.Consistency` against the combined
catalog so translations keep required arguments, preserve AWK-specific verbatim
tokens such as `awk`, `awklib`, `-F`, `-v`, `-f`, `--color`, `ARGV`, `ARGC`,
`ENVIRON`, `BEGIN`, `END`, `getline`, `print`, and `printf`, and avoid ICU
apostrophe escape hazards. Process-level tests also render a non-ASCII locale
diagnostic and reject the doubled UTF-8 lead-byte sequence that indicates
mojibake at the executable boundary.

The AUnit localization suite renders a real usage diagnostic for every
supported locale in the combined catalog. For each locale it checks that the
selected catalog text is used, the option argument is interpolated, raw message
keys are not exposed, and no raw terminal escape character is emitted.
The same suite renders `--help` for every supported locale with color disabled
and checks that required CLI/AWK tokens remain visible without raw message keys
or terminal escapes.
The release workflow also rejects known English fallback help and diagnostic
sentences in non-English catalog entries so generated or temporary text cannot
silently replace localized CLI text.
Translation review also uses the checked-in
[Localization Reference](localization-reference.md), which records comparable
POSIX, GNU awk, BWK awk, and BusyBox awk text families to consult for AWK
terminology and help phrasing. These references guide wording only; tests do
not execute another AWK implementation.

Locales outside the supported European state-language locale set fall back
through the `messages` runtime to the catalog default locale. If a requested
message key cannot render but the catalog is otherwise usable, the CLI renders
the catalog-backed
`awk.internal.localization_failed` message instead of exposing the raw key as
ordinary prose. A raw escaped key is reserved only as a last-resort containment
path when even the fallback message cannot render.

Locale never changes AWK source, input, output, numeric conversion, filenames, variable names, variable values, or regular-expression semantics.
