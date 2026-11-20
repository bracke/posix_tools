# `rg` Phase 1: dependency API mapping

> Implementation status: the mapped `Regexp` concurrency and character-mode
> clarifications and the scoped `Version.Ignore` builder, snapshots,
> provenance, and repository-exclude loader are implemented and covered by the
> sibling-library suites. The sequential `rg` pipeline now uses those APIs for
> bounded input, explicit files, recursive traversal, and lazy hierarchical
> ignore evaluation.

Status: verified and implemented against the sibling checkouts on 2026-11-20.

Reference behavior is pinned to ripgrep 15.2.0 (`ripgrep 15.2.0`, revision
`e89fff89ac`). Any reference-version change must update the inventory and
differential fixtures deliberately.

## Outcome

The existing libraries proved suitable foundations. `Version.Ignore` now has a
reusable scoped rule-set builder, snapshots for lazy traversal, source-load
outcomes, structured provenance, and an explicit immutable-read contract.
`Regexp` supplies compilation, matching, captures, pattern sets, cancellation,
bounded execution, Unicode 16.0 tables, and a read-only sharing contract.
`rg` uses these APIs directly in both its sequential and native-task pipelines.

## `Regexp` mapping

| `rg` responsibility | Existing `Regexp` API | Adapter rule |
| --- | --- | --- |
| Regex compilation | `Compile` and `Compile_Diagnostic` | Compile in `UTF_8_Mode` for Unicode-aware syntax. Preserve `Status` and `Error_Offset` in the `rg` diagnostic. |
| Fixed strings | `Escape_Literal`, `Compile_Literal`, `Compile_Literal_Set`, `Compile_Literal_Word_Set`, and literal wrapper helpers | Use only the library's literal facilities when composing fixed patterns. An empty pattern must be represented by a library-supported empty expression such as `(?:)`, because a zero-length source passed to `Compile` is reported as `Empty_Pattern`. |
| `-w` and `-x` | `Compile_Whole_Word`, `Compile_Line`, and literal equivalents; `Whole_Word` and `Multiline_Anchors` options | Prefer compile-time wrappers so each pattern retains the correct mode. Do not use `Whole_Word` to implement `-x`. |
| Multiple patterns | `Regexp_Array`, `Find_First_Of`, `Find_From_Of`, tokenization, and capture variants | Keep declarations distinct and preserve declaration order for equal-start ties. Do not join user regexes by hand. |
| Match iteration | `Match_Cursor`, `Start`, `Next`, capture-aware variants, `Find_All`, and `Find_All_From` | Cursor APIs already advance after zero-length matches. Treat `Find_All_Limit_Exceeded` as an explicit search error, never as end-of-input. |
| Spans and captures | `Match_Result`, `Text_Range`, `Find_*_With_Captures`, named-capture queries | Public offsets are one-based byte offsets relative to `Text'First`; convert to ripgrep's zero-based JSON byte offsets only in rendering. Empty matches have `Last < First`. |
| Case modes | `Match_Options.Case_Sensitive` | Always set this field. Its library default is `False`, while ripgrep's default is case-sensitive. Implement smart case in the adapter before matching. |
| Multiline | `Dot_Matches_Newline`, `Multiline_Anchors`, `Stream_Cursor`, `Start_Stream`, and `Feed` | `-U` controls whether a match may span records; `--multiline-dotall` independently controls dot. Do not conflate the two flags. |
| Limits and cancellation | `Max_Steps`, `Abort_Callback`, detailed limit statuses | Use a command cancellation callback. A step-limit or callback stop is not `No_Match`; propagate it into final status and diagnostics. |
| Replacement | replacement validation, planning, capture references, and replace helpers | Validate the replacement once. Rendering may use a bounded plan per selected record so original byte offsets remain authoritative. |
| Syntax policy | `Features`, `Pattern_Policy`, `Validate_Policy_Detail` | Default mode must reject backreferences, lookaround, atomic groups, and possessive constructs even though the engine accepts them. Do not expose `--pcre2`. |
| Strategy metadata | `Recommended_Strategy`, `Required_Prefix`, `Summary`, and `Lint` | May select literal/prefix fast paths but must not change semantics. |

### Regex behavior already established

- `Regexp` is a `Pure`, SPARK-enabled package. The current `Regexp` value is a
  bounded record containing inline states, capture names, source text, and class
  data; it contains no access value or shared mutable cache.
- Matching workspaces are local to calls. A `Match_Cursor` or `Stream_Cursor` is
  mutable and therefore worker-local. The compiled expression may be copied or
  read by multiple workers with the current implementation.
- UTF-8 mode consumes valid code points while preserving byte offsets. Invalid
  bytes are nonmatching barriers and matching resumes at the next valid byte.
- Unicode word classification and property escapes use the complete Unicode
  16.0 tables and loose aliases pinned by `regex-syntax` 0.8.11.
- Non-overlapping iteration has defined zero-length progress.
- A matching call has a single total step budget, and cancellation is checked
  through the same bounded step path.

### Bounded regex constraints

These are not adapter details and must be visible in the option inventory:

1. A compiled source pattern is limited to 1024 bytes and 2048 states. The public
   limit parameters can lower those ceilings but cannot raise the inline
   implementation maxima.
2. The stream cursor retains at most 16384 bytes. A valid streaming match or
   undecidable greedy match may therefore report `Stream_Buffer_Full` where
   ripgrep's dynamically sized implementation succeeds. `rg -U` uses its own
   explicit 64 MiB whole-input bound and does not rely on this cursor.
3. `Match_Limit_Exceeded` represents either budget exhaustion or cancellation.
   `rg` queries its worker cancellation callback immediately to distinguish a
   shared stop request from the one-million-step default budget.

### Completed `regexp` changes

- Documented a public concurrency contract stating that compiled `Regexp` values
  are immutable and may be read concurrently, while cursors are worker-local.
- Wired active worker cancellation through the documented callback companion
  mechanism and added explicit limit diagnostics.
- Expanded the safe bounded defaults to 1024 pattern bytes, 2048 states, one
  million match steps, and a 16 KiB stream window, with regression tests.
- Implemented `rg -U` with a separately bounded 64 MiB input strategy, avoiding
  an unsupported claim of unbounded streaming compatibility.

## `Version.Ignore` mapping

| `rg` responsibility | Existing `Version.Ignore` API | Finding |
| --- | --- | --- |
| Repository rules | `Load (Root)` and `Load (Repository_Handle)` | Loads configured global excludes, repository `info/exclude`, and nested `.gitignore` files. |
| Hierarchical matching | rule `Base_Dir`, `Match_Within`, `Is_Ignored_In`, and `Excludes_Directory` | Nested rules are scoped to their directory. `Match_Within` treats an explicitly selected traversal root as included while retaining direct and nested rule provenance below it. |
| Git negation | `Match`, `Is_Ignored`, parent checks | Last applicable rule wins, but an ignored parent prevents a child negation from re-including descendants, matching Git traversal. |
| Provenance | `Match_Result` | Reports effective pattern, source path, source line, and decision. |
| Path normalization | internal root-relative normalization | Accepts relative or rooted queries, normalizes Windows separators, and honors the host's case behavior plus `core.ignoreCase`. |
| Raw globs | `Wildcard_Matches` | Suitable for pathname-style `*`, `?`, classes, and `**`; it deliberately omits gitignore directory semantics. |
| In-memory rules | `Rules_From_Text` | Parses one anonymous, root-anchored rule source. It cannot be appended to another rule set or assigned a source scope/precedence. |

### Ignore behavior already established

`Load` uses this precedence order: configured global excludes, repository
`info/exclude`, then `.gitignore` files in hierarchical traversal order. It
skips symlinked ignore files and does not descend into an already ignored
directory. The existing tests compare many decisions with `git check-ignore`,
including nested files, negation, ignored parents, BOM/CRLF input, separator
normalization, `core.ignoreCase`, symlinked ignore files, and source precedence.

The loader is eager: it scans the whole selected tree to discover nested
`.gitignore` files before returning. This is correct for existing version-control
callers, but it duplicates `rg` traversal and offers no way to add `.ignore` or
`.rgignore` in the same precedence model.

### Resolved ignore integration gaps

The builder now accepts named file and text sources with base directories,
source kinds, and precedence. `Snapshot` supports lazy hierarchical traversal;
`Add_Repository_Excludes` preserves Git configuration behavior; `Match_Within`
implements explicit-root boundaries; `Source_Load_Result` exposes file errors;
and `Match_Result` contains base directory, source kind, and reason. `Finish`
documents its result as immutable and safe for concurrent reads.

### Implemented `versionlib` extension

Add a reusable builder while preserving both existing `Load` overloads:

```ada
type Rule_Source_Kind is
  (Global_Exclude, Repository_Exclude, Gitignore, Ignore_File,
   Rgignore_File, Explicit_Source);

type Rule_Set_Builder is limited private;

function Create
  (Root             : String;
   Case_Insensitive : Boolean := False) return Rule_Set_Builder;

procedure Add_File
  (Builder    : in out Rule_Set_Builder;
   Path       : String;
   Base_Dir   : String;
   Kind       : Rule_Source_Kind;
   Precedence : Integer;
   Result     : out Source_Load_Result);

procedure Add_Text
  (Builder     : in out Rule_Set_Builder;
   Text        : String;
   Source_Name : String;
   Base_Dir    : String;
   Kind        : Rule_Source_Kind;
   Precedence  : Integer);

function Finish (Builder : Rule_Set_Builder) return Ignore_Rules;

function Match_Within
  (Rules         : Ignore_Rules;
   Relative_Path : String;
   Is_Directory  : Boolean;
   Boundary      : String) return Match_Result;
```

The exact spelling may follow `versionlib` conventions, but the contract must
provide all of these semantics:

- lower precedence is evaluated before higher precedence;
- within a source, later lines win;
- within a precedence tier, deeper directory scope wins for a descendant;
- source provenance includes kind, file/name, line, pattern, and base directory;
- callers can choose parent scope and VCS/non-VCS sources independently;
- callers can preserve explicit-root inclusion without suppressing rules that
  directly match descendants or exclude directories below that root;
- construction reports missing, unreadable, malformed, and loaded sources;
- `Finish` produces an immutable rule set explicitly safe for concurrent reads.

Existing `Load` and `Rules_From_Text` should be reimplemented through this
builder so there remains one parser and one evaluator. Their externally visible
behavior must remain unchanged. Add differential fixtures against Git for the
legacy loaders and against ripgrep 15.2.0 for mixed `.gitignore`, `.ignore`, and
`.rgignore` precedence.

## Ownership and execution decisions

- `rg` owns CLI precedence, hidden-file policy, `-u` levels, explicit path
  behavior, file types, glob overrides, traversal orchestration, rendering, and
  exit-status aggregation.
- `Version.Ignore` owns parsing and evaluating every gitignore-syntax source,
  including `.ignore` and `.rgignore` when requested by `rg`.
- `Regexp` owns all regular-expression and literal matching. `rg` may enforce a
  narrower syntax policy but must not implement matching constructs.
- `greplib` provides related bounded record and event facilities. The completed
  adapter reuses shared project infrastructure where semantics align and keeps
  ripgrep-specific decoding, traversal, JSON, and ordering inside `rg`; its
  internal regex adapter is not used as a second matcher integration.

## Completed dependency-ordered implementation

1. `Version.Ignore` exposes the scoped builder, source outcomes, provenance,
   immutable snapshots, and compatibility-preserving legacy loaders.
2. `Regexp` documents immutable sharing, enforces the default syntax policy,
   supports nested Unicode/byte scopes, and propagates limits and cancellation.
3. `tools/rg` is registered as a standalone non-POSIX command with pinned local
   crates, help, version, documentation, smoke tests, and packaging metadata.
4. The option model validates every accepted combination; unsupported options
   remain hard diagnostics rather than accepted no-ops.
5. Sequential fixed-string and regular-expression search uses `Regexp`
   exclusively with bounded record input and byte-accurate match spans.
6. Traversal evaluates lazy scoped ignore sources, multiple roots, explicit
   paths, globs, types, links, file-system boundaries, and sorting.
7. Text, context, count, path, replacement, color, JSON, and statistics modes
   have focused AUnit and pinned-reference differential coverage.
8. All pinned WHATWG decoders, binary policies, NUL records, and multiline
   matching have explicit bounded failure behavior.
9. A bounded native task pool uses protected queues, ordered output, active
   cancellation, worker-local contexts, stress tests, and a ThreadSanitizer CI
   gate. Worker bounds and queue transitions are covered by GNATprove.
10. Inventory, localization, documentation, proof targets, release packaging,
    and the local release gate are integrated.

## Verification baseline

- `regexp`: GNATLS 15.2.0; library build passed; 32/32 AUnit tests passed.
- `versionlib`: GNATLS 15.2.0; full transport-inclusive suite passed, 1220/1220
  tests with no failed assertions or unexpected errors.
- `posix_tools`: the `rg` suite passes normally and under ThreadSanitizer;
  `posix_tools_tests release-check` is the final local release gate.
- `versionlib` manifest crate name is exactly `versionlib`; the dependency and
  pin names in the specification are correct.
