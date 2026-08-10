# Architecture

The repository is a single coordinated release containing one root executable crate,
one shared library crate, one binary crate per command, and one tests/tooling crate.

Command executable mains are thin instantiations of `Posix_Tools.Host_Adapters.Run_Command`.
Command behavior lives under `Posix_Tools.Commands`.

`Posix_Tools.Commands.Contexts.Context` is the process-facing command context.
It owns argument access, output/error writes, environment lookup for command
code that needs it, physical current-directory lookup, and raw standard-input
reads for byte-oriented commands. Tests override these primitives in
`Test_Contexts.Capturing_Context`. The context records standard-output failure
at the process boundary so command code can return an operational failure
without confusing a failed write with a failed input read.

Reusable host-specific operations are isolated under `Posix_Tools.Host_Adapters`.
The production context delegates environment lookup, physical current-directory
lookup, terminal checks, and standard stream access to host adapter child
packages rather than importing host-facing packages directly.
Shared file helpers delegate file operand open/read/close operations to
`Posix_Tools.Host_Adapters.File_System`, whose production implementation uses
hostkit descriptors for byte reads; command packages and helpers retain byte
scanning, header, and output policy.
`Posix_Tools.Host_Adapters.Executables` wraps hostkit executable lookup,
executable checks, temporary capture files, bounded identity invocation, and
identity-output validation for the root verifier. POSIX command packages must
not import hostkit directly.

Byte-oriented helpers live under `Posix_Tools.Streams`. `Posix_Tools.Streams.Lines`
defines the LF segment contract used by file-oriented command behavior: newline
segments keep the LF byte and final partial segments are not modified.

Standard input and standard output are accessed through Ada stream interfaces at
the context/process boundary when command data must preserve bytes. Command
algorithms use context primitives instead of reading process global streams
directly.

`Posix_Tools.Streams.Counting` owns byte, LF-line, character, and word counting
state so `wc` can count across bounded input chunks without resetting word or
decoder state at buffer boundaries. UTF-8 decoding is isolated in
`Posix_Tools.Text.UTF_8`, and deterministic Unicode whitespace classification
is isolated in `Posix_Tools.Text.Classification` with a recorded Unicode
version.

`Posix_Tools.Localization` is the narrow adapter over the `messages` runtime.
Help rendering asks the command context for an effective locale and resolves
message identifiers from `common/messages/posix_tools.catalog`, falling back to
stable English defaults if the catalog or locale key is unavailable.

`Posix_Tools.Presentation` is the only project-owned adapter over
`terminal_styles`. Help and root headings pass through it with explicit styling
modes and destination terminal status. Command data output such as `cat`, `wc`,
`pwd`, `echo`, pathname results, and copied file data bypasses presentation
styling. Production terminal status is obtained through
`Posix_Tools.Host_Adapters.Terminals`, which delegates the platform question to
hostkit.

`tail` suffix processing uses bounded retained memory while the requested
suffix fits the memory threshold. Larger byte and line suffix cases spill
through `Posix_Tools.Host_Adapters.Temporary_Storage` and fail without partial
output when the configured spill limit is exceeded.
