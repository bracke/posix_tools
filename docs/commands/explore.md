# explore

## Name

explore - visual file manager for bracke-terminal

## Synopsis

`explore [--config=file] [--cwd-file=file] [--chooser-file=file] [directory]`

## Description

`explore` is a full-screen, keyboard- and mouse-driven file manager. It takes over the terminal's alternate screen,
shows the directory it was given (or the current directory), and hands the terminal back as it found it when it ends.

`explore` runs only inside bracke-terminal. At start-up it asks the terminal to identify itself and refuses to run in
any terminal that does not.

The screen has three panes: the parent of the current directory on the left, the current directory in the middle, and
on the right a preview of the selected entry: the listing of a directory, or, for a file, what it is as `file`
describes it and then its first lines when it is text, coloured by its language, the members of an archive, the image
of a PNG, JPEG, or GIF, a thumbnail of a PDF or a video, or else a hex dump of its first bytes. Below 80 columns the parent pane is left out, and below 50 the preview too. The top line shows the
current directory; the status line shows the selected entry's mode, owner, size, and modification time, its position,
and any filter or pending prefix key.

Each tab browses on its own, with its own directories, history, filter, and marks; the title line lists the tabs
when there is more than one, the current one in brackets.

A search shows its results in the current pane as it finds them, each by its path below the directory searched, and
the status line says what it looks for and, once it ends, how many it found. Results can be entered, previewed,
marked, and operated on like any entries; `h` goes back to the directory searched, and going elsewhere stops the
search. A search walks the tree on a worker task of its own without following symbolic links, at most 64 levels deep,
and keeps at most 10,000 results; it leaves out entries starting with a dot unless they are shown. Text is searched
for with greplib, line by line, and files with a NUL byte in them are taken as binary and left out.

### Keys

| Key | Action |
| --- | --- |
| `j`, Down / `k`, Up | move down / up |
| `l`, Right, Enter | enter the selected directory, or open the selected file |
| `o` | open the entries with their opener |
| `!` | type a shell command to run on the entries, in the current directory; the entries are its `"$@"` |
| `S` | start a shell in the current directory |
| `cc` / `cf` / `cd` | copy the entries' paths / names, one a line, or the current directory, to the system clipboard |
| `h`, Left | go up to the parent directory |
| `gg`, Home / `G`, End | first / last entry |
| Ctrl-d / Ctrl-u | half a page down / up |
| Ctrl-f, Page Down / Ctrl-b, Page Up | a page down / up |
| `.` | show or hide entries whose names start with a dot |
| `f` | type a filter: only names containing it, regardless of case, are shown; Enter keeps it, Escape clears it |
| Escape | clear the filter |
| `,n` `,a` `,e` `,s` `,m` `,t` | sort by natural name, name, extension, size, modification time, or kind; the capital letter sorts in reverse |
| `~` | go to the home directory |
| `H` / `L` | go back to the directory visited before / forward again |
| `:` | type a path to go to: absolute, relative to the current directory, or from `~`; a file is gone to in its directory |
| `b` and a letter or digit | bookmark the current directory under it |
| `'` and a letter or digit | go to that bookmark |
| `t` / `T` | open a tab on the current directory / close the current tab |
| `[` / `]`, `1` to `9` | the previous / next tab, or the tab with that number |
| `/` | search the tree below the current directory by name: a glob when the pattern has `*`, `?`, or `[` in it, a substring regardless of case when it has not |
| `?` | search the files below the current directory for text, regardless of case |
| `v` | start a visual selection: moving marks every entry between where it started and the cursor; `v` or Escape ends it |
| Space | mark or unmark the selected entry and move down; operations act on the marked entries, or on the selected one when none are marked |
| `y` / `x` | yank / cut the entries for pasting |
| `p` | paste: copy what was yanked, or move what was cut, into the current directory |
| `-` | paste symbolic links to what was yanked or cut |
| `d` | delete, after confirming with `y` |
| `r` | rename the selected entry |
| `a` | create a file, or a directory when the name ends in `/` |
| `m` | change permissions, octal or symbolic as chmod takes them |
| Ctrl-c | cancel the running copies, moves, links, and deletions |
| `w` | open the operations panel: running, waiting, and ended operations; `j`/`k` move in it, `x` cancels the operation under the cursor, whether running or waiting, and `w`, `q`, or Escape close it |
| `q` | quit |

When a pasted entry would replace one that exists, the operation waits for an answer: `o` overwrites it, `s` or
Escape skips it, and `O` and `S` do the same for every further conflict of that operation.

The mouse wheel moves the selection. A click in the current pane selects the entry under it, in the parent pane goes
up, and in the preview pane enters the selected directory.

## Operands

`directory` is the directory to start in. It defaults to the current directory. At most one operand is accepted.

## Options

Each option takes its value after `=` or as the next argument; `--` ends the options.

`--config=file` reads the configuration from `file` instead of from its usual place.

`--cwd-file=file` writes the directory shown when `explore` quits to `file`, without a line feed, so that a shell
function can change to it.

`--chooser-file=file` makes `explore` choose files for another program: opening entries writes their paths to `file`,
each followed by a line feed, and quits instead of opening them. Quitting without opening any leaves `file` as it was.

Common project options such as `--help`, `--version`, and the internal identity option are recognized at the command
boundary.

## Standard Input

Must be a terminal. It is read in raw mode for keys, mouse reports, resize reports, and the terminal's answers to
explore's queries.

## Standard Output

Must be the same terminal. It receives the screen explore draws and its queries to the terminal.

## Standard Error

Diagnostics are localized through messages and written after the terminal has been handed back.

## Exit Status

`0` when the user quits, `1` when the operand is not a directory, the `--cwd-file` file cannot be written, standard input or output is not a terminal, the
terminal cannot be put into raw mode, the terminal does not identify itself as bracke-terminal, or output fails, `2` for
invalid usage, `128` plus the signal number when a terminate or hangup signal ends the session, and `125` for
unexpected internal failures at the command boundary.

## Behavioral Details

At start-up `explore` saves the terminal's settings, puts it into raw mode, and sends the identity query
`OSC 7701 ; q ST` followed by a primary device attributes request. bracke-terminal answers the first with
`OSC 7701 ; v=<version> ; caps=<capability>,... ST`; every terminal answers the second. When the device attributes
arrive without an identity answer before them, or nothing arrives within half a second, the terminal is not
bracke-terminal and `explore` restores it and exits with a diagnostic. Unknown keys and capability names in the answer
are ignored, so the terminal and `explore` can each grow without breaking the other.

Once identified, `explore` switches to the alternate screen and asks for SGR mouse reports, focus reports, bracketed
paste, in-band resize reports, and disambiguated keys. Each frame is sent as one synchronized update.

Directories are read through the shared `Posix_Tools.File_Operations.Listing` on two worker tasks, away from the
screen, so a large or slow directory never holds up the keyboard. Each pane has one outstanding read at most: moving on
replaces it, a read already running for the replaced request stops at its next entry, and entries that arrive for it
are dropped. The current and parent directories are watched, and re-read when they change, with the selection kept on
the same name. Entries are sorted by natural name by default, with directories first and ASCII case ignored. Only the
cells that changed are redrawn. On a directory of 100,000 entries the first frame appears within 100 milliseconds and
every key is answered within 100 milliseconds while the directory is read and sorted, which takes one to three seconds;
the end-to-end tests hold explore to these budgets.

A file's preview is built on a worker task of its own from the first 64 KiB of the file, or from all of an image of up to
16 MiB, so a large or slow file never holds up the keyboard; moving on replaces a preview not yet built. An image is
sent to the terminal through Kitty graphics and placed in the pane with Unicode placeholders, scaled down to fit
without stretching and never enlarged, using the cell size the terminal reports with its size. PNG goes as Kitty's
`f=100`; JPEG and GIF go as bracke-terminal's private `f=1001` and `f=1002`, and only when the terminal advertises
`kgfx-jpeg` and `kgfx-gif` in its identity answer. The terminal keeps the last eight images sent, up to 32 MiB, so
returning to one shows it at once, and a resize only places it again; the least recently shown is freed to make room,
and all are freed when `explore` ends. Inside tmux the graphics commands are passed through to the outer terminal
while the placeholders stay ordinary text. Images are sent directly over the terminal connection, which also works
across ssh.

An archive is listed from its own catalogue, one line per member with its size and path, at most 500 of them: ZIP, 7z,
ar, cpio, ISO 9660, and RAR through zlib, and tar, plain or gzip compressed, through tarlib. A compressed tar is inflated
in memory only up to 64 MiB. Nothing is extracted. Text is coloured by a light tokenizer, by the file's extension or its
`#!` line: keywords, strings, comments, and numbers in Ada, the C family (C, C++, Java, JavaScript, TypeScript, Rust,
Go, C#, Swift, Kotlin), `#`-commented languages (shell, Python, Ruby, Perl, TOML, YAML, make files), and JSON, and
headings in Markdown. A block comment carries on down the lines.

A PDF's first page and a frame one second into a video are made into a PNG by `pdftoppm` and `ffmpeg`, where they are
installed, and shown as images. They are the only programs `explore` runs: they write into a private directory under
`$TMPDIR` that is removed on exit, run for at most ten seconds, and never touch the file but to read it.

Copies, moves, links, and deletions run on two worker tasks of their own, through the shared
`Posix_Tools.File_Operations` that `cp`, `mv`, and `rm` use. They start in the order they were asked for, as far as that
is safe: two operations of one kind never run at once, and an operation whose paths overlap an earlier one's -- the
same path, or one inside the other -- waits for it, so a deletion never races the copy it would remove. Copies keep modes, times, and
symbolic links; a copy into the directory it came from is named `name_1`, `name_2`, and so on; a move across
filesystems copies and then removes the source; deletion removes links, never what they point to. The status line
shows the first running operation, its file, and how far the copy of that file is, and how many more run or wait; up
to sixteen wait their turn. When an operation ends the panes are read again and the status line says how it went: done,
cancelled, or with how many errors and the first of them. The last sixteen that ended are listed in the operations
panel. Renaming, creating, and changing permissions
happen at once.

### Configuration

The configuration is read at start-up from `$XDG_CONFIG_HOME/explore/config.toml`, or `~/.config/explore/config.toml`
when `XDG_CONFIG_HOME` is not set to an absolute path, through tomllib. Every part of it is optional. A part that
cannot be read is left out and the rest is used; the status line names the first such part and how many more there
are until the first key.

```toml
[options]
show_hidden = true          # show entries whose names start with a dot
sort = "natural"            # natural, name, extension, size, modified, or kind
sort_descending = false
thumbnails = true           # make PDF and video thumbnails

[keys]
"J" = "move_bottom"
"ctrl-o" = "open_entries"
"g h" = "go_home"           # two keys, separated by a space
"x" = "none"                # unbound
"F5" = "sort_entries:size_descending"

[theme]
directory = { fg = "bright_blue", bold = true }
cursor = { bg = 24, fg = "white" }

[[open]]
match = ["*.pdf", "*.epub"]
run = 'zathura "$@"'
detach = true

[[preview]]
match = "*.md"
run = 'glow -s dark "$1"'
```

A key is a character, `space`, or one of `enter`, `tab`, `backspace`, `esc`, `up`, `down`, `left`, `right`, `home`,
`end`, `pageup`, `pagedown`, `insert`, `delete`, and `f1` to `f12`, after any of `ctrl-` and `alt-`. Keys bound there
come before the defaults; a default two-key sequence still works when its first key also starts a bound one. An
action is named in lower case: `quit`, `move_up`, `move_down`, `move_top`, `move_bottom`, `half_page_up`,
`half_page_down`, `page_up`, `page_down`, `enter_directory`, `leave_directory`, `toggle_hidden`, `start_filter`,
`clear_filter`, `go_home`, `toggle_mark`, `yank`, `cut`, `paste`, `paste_links`, `delete_entries`, `rename_entry`,
`create_entry`, `change_mode`, `cancel_job`, `show_jobs`, `new_tab`, `close_tab`, `previous_tab`, `next_tab`,
`go_back`, `go_forward`, `jump_to_path`, `visual_mode`, `search_names`, `search_contents`, `open_entries`,
`shell_command`, `spawn_shell`, `copy_path`, `copy_directory`, `copy_name`, and with an argument after a colon
`sort_entries:` a sort key, optionally followed by `_descending`, `switch_tab:` a digit, and `set_bookmark:` and
`go_bookmark:` a letter or digit. `none` unbinds a key.

A theme entry replaces the style of a role: `fg` and `bg` are `default`, one of `black`, `red`, `green`, `yellow`,
`blue`, `magenta`, `cyan`, and `white`, the same after `bright_`, or a palette index from 0 to 255; `bold`, `dim`,
`underline`, and `inverse` are booleans. The roles are `header` (the tabs), `info` (the current path), `muted`
(notes), `error`, `warning` (special files), `success` (executable files), `status`, `alert` (an error in the status
line), `directory`, `link`, `missing` (broken links), `marked`, `cursor`, `inactive_cursor`, `panel`, and for
coloured text `keyword`, `string`, `comment`, `number`, and `heading`; the first six are those terminal_styles uses.
The styles of `marked` and the cursors are laid over an entry's own.

Openers are tried in order, the first whose `match` -- a glob or a list of them, compared with the file's name
regardless of case -- fits the first entry opening all of them; one without `match` fits every file. When none fits,
text goes to `$VISUAL`, or `$EDITOR`, or `vi`, and anything else to `xdg-open`, detached. An opener runs in the
terminal, which `explore` hands to it and takes back when it ends; with `detach = true` it runs on its own with its
input and output away from the terminal, for a program with a window. A previewer's output, with its terminal control
sequences taken out, is the preview of a file its `match` fits, when it prints anything; it runs for at most ten
seconds.

### Running programs

Openers, previewers, shell commands, and the shell all run through `/bin/sh` in the directory shown, with the entries
they are for as the shell's positional parameters: a command names them as `"$@"` or `"$1"`, and no name is ever put
into the text of a command. While a program has the terminal, `explore` leaves the alternate screen and restores the
terminal's settings, and the keyboard's interrupt and quit signals go to the program alone; afterwards `explore` takes
the terminal back, sends its images again, and reads the panes again. A shell command waits for Enter before
`explore` returns, so its output can be read, and the status line reports a command that ended with a status other
than 0. These, the thumbnailers, and the previewers are the only programs `explore` runs: file operations never run
another program.

### Bookmarks

Bookmarks are kept in `$XDG_STATE_HOME/explore/bookmarks`, or `~/.local/state/explore/bookmarks`, one line each: the
letter or digit, a space, and the directory. They are read at start-up and written whenever one is set.

### Clipboard

`cc`, `cf`, and `cd` put text on the system clipboard with OSC 52, which bracke-terminal advertises as `osc52`, and
inside tmux pass it through to the outer terminal.

On every way out -- quitting, a terminate or hangup signal, failing output, or an unexpected internal failure --
`explore` leaves the alternate screen, turns those reports off again, restores the saved terminal settings, and puts
back the signal dispositions it changed. A terminate or hangup signal that was ignored when `explore` started stays
ignored.

Inside tmux (`TMUX` set in the environment), the identity query and every sequence meant for bracke-terminal itself
are wrapped in tmux's DCS passthrough, which requires `set -g allow-passthrough on` in tmux. tmux 3.4 hands the
terminal's answers back to the pane, so the identity check works the same inside tmux, and the image placeholders
are ordinary text that tmux redraws itself.

## Locale Behavior

Interface text, help, and diagnostics are locale-dependent. Pathnames are shown as they are.

## Implementation-Defined Choices

The identity handshake waits at most 500 milliseconds. Environment variables read: `HOME`, `XDG_CONFIG_HOME`,
`XDG_STATE_HOME`, `TMPDIR`, `TMUX`, and, through the shell, `VISUAL`, `EDITOR`, and `SHELL`. A lone ESC byte is taken as the Escape key after 100
milliseconds without further input. Terminals that do not report resizes in band are measured again when the window
change signal arrives.

## Extensions

`explore` is a project extension command, not a POSIX utility. The command supports project-wide help, version, and
identity operations.

## Examples

`explore`

`explore ~/projects`

A shell function that changes to the directory `explore` quits in:

```sh
x() {
    file=$(mktemp) && explore --cwd-file="$file" "$@" && cd -- "$(cat -- "$file")"
    rm -f -- "$file"
}
```

## Conformance Status

Project extension; not a POSIX utility.

## Known Limitations

Only bracke-terminal is supported, by design. There is no trash: deletion is permanent. JPEG and GIF images are shown
only once the terminal advertises them, and previews do not scroll. Syntax colouring knows only a few languages and is
a tokenizer, not a parser. A detached opener keeps running after `explore` ends, and ends with the terminal's session.
Combining characters in names are not drawn. A watched directory is re-read whole when it changes.
