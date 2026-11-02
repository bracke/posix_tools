--  English text of every message in resources/messages/catalog.txt, as
--  that catalogue gives it once rendered: what a message says when no
--  catalogue can be read or the catalogue lacks it. Keep each entry equal
--  to its "en." line; the tests check that they are.
package body Awk_CLI.Localization.Defaults is
   function Template (Key : String) return String is
   begin
      if Key = "awk.help.title" then
         return
           "awk";
      elsif Key = "awk.help.summary" then
         return
           "Ada command-line AWK implementation built on awklib. The command-line" &
           " workflow follows traditional POSIX awk; language and runtime" &
           " behavior are limited to the resolved awklib version.";
      elsif Key = "awk.help.usage.direct_program" then
         return
           "Usage: awk [options] 'program' [operand...]";
      elsif Key = "awk.help.usage.program_files" then
         return
           "Usage: awk [options] -f program-file [-f program-file...] [operand...]";
      elsif Key = "awk.help.options.field_separator" then
         return
           "  -F sep, -Fsep          set FS before execution; the final" &
           " occurrence wins";
      elsif Key = "awk.help.options.variable" then
         return
           "  -v name=value, -vname=value  assign a variable before BEGIN; kept" &
           " in command-line order";
      elsif Key = "awk.help.options.program_file" then
         return
           "  -f file, -ffile        read AWK source from a file; multiple files" &
           " are concatenated in order";
      elsif Key = "awk.help.options.color" then
         return
           "  --color=auto|always|never  style CLI-owned help and diagnostics only";
      elsif Key = "awk.help.options.help" then
         return
           "  --help                 show this help and exit";
      elsif Key = "awk.help.options.version" then
         return
           "  --version              show version information and exit";
      elsif Key = "awk.help.options.terminator" then
         return
           "  --                     end option processing; filenames beginning" &
           " with '-' work after this";
      elsif Key = "awk.help.operands" then
         return
           "Operands after the program are named input files, '-' for standard" &
           " input, or assignments whose name matches [A-Za-z_][A-Za-z0-9_]*.";
      elsif Key = "awk.help.stdin" then
         return
           "If no input operand is present, standard input is used implicitly." &
           " Repeated '-' operands read the single standard-input stream once;" &
           " later uses observe end of file.";
      elsif Key = "awk.help.exit_statuses" then
         return
           "Exit statuses: 0 success, 1 interpreter failure, 2 usage error, 3" &
           " host I/O failure, 70 internal failure.";
      elsif Key = "awk.help.compatibility.heading" then
         return
           "Compatibility";
      elsif Key = "awk.help.compatibility.awklib_limitations" then
         return
           "This program does not claim complete POSIX conformance. AWK language" &
           " and runtime behavior are limited to the resolved awklib version and" &
           " currently registered limitations documented by this project. getline" &
           " behavior follows awklib.";
      elsif Key = "awk.version.program" then
         return
           "awk {version}";
      elsif Key = "awk.version.interpreter" then
         return
           "awklib {version}";
      elsif Key = "awk.version.license" then
         return
           "license MIT";
      elsif Key = "awk.diagnostic.label.info" then
         return
           "info";
      elsif Key = "awk.diagnostic.label.error" then
         return
           "error";
      elsif Key = "awk.diagnostic.label.warning" then
         return
           "warning";
      elsif Key = "awk.diagnostic.label.internal_error" then
         return
           "internal error";
      elsif Key = "awk.diagnostic.header" then
         return
           "awk: {severity}: {detail}";
      elsif Key = "awk.diagnostic.source_location" then
         return
           "{path}:{detail}";
      elsif Key = "awk.diagnostic.detail" then
         return
           "{detail}";
      elsif Key = "awk.diagnostic.hint" then
         return
           "hint: {detail}";
      elsif Key = "awk.source.command_line" then
         return
           "command line";
      elsif Key = "awk.usage.missing_program" then
         return
           "missing AWK program";
      elsif Key = "awk.usage.unknown_option" then
         return
           "unknown option: {option}";
      elsif Key = "awk.usage.missing_option_argument" then
         return
           "missing argument for {option}";
      elsif Key = "awk.usage.invalid_assignment" then
         return
           "invalid assignment: {assignment}";
      elsif Key = "awk.usage.invalid_color_mode" then
         return
           "invalid color mode: {value}";
      elsif Key = "awk.usage.program_file_stdin_unsupported" then
         return
           "program file '-' is unsupported because standard input is reserved" &
           " for AWK data";
      elsif Key = "awk.program_file.open_failed" then
         return
           "cannot open program file: {path}";
      elsif Key = "awk.program_file.read_failed" then
         return
           "cannot read program file: {path}";
      elsif Key = "awk.input_file.open_failed" then
         return
           "cannot open input file: {path}";
      elsif Key = "awk.input_file.read_failed" then
         return
           "cannot read input file: {path}";
      elsif Key = "awk.output_file.open_failed" then
         return
           "cannot open output file: {path}";
      elsif Key = "awk.output_file.write_failed" then
         return
           "cannot write output file: {path}";
      elsif Key = "awk.standard_input.read_failed" then
         return
           "cannot read standard input";
      elsif Key = "awk.standard_output.write_failed" then
         return
           "cannot write standard output";
      elsif Key = "awk.interpreter.parse_failed" then
         return
           "AWK parse failed";
      elsif Key = "awk.interpreter.runtime_failed" then
         return
           "AWK execution failed";
      elsif Key = "awk.interpreter.unsupported_operation" then
         return
           "unsupported awklib operation";
      elsif Key = "awk.internal.localization_failed" then
         return
           "localization failed for message key: {detail}";
      elsif Key = "awk.internal.unexpected_exception" then
         return
           "unexpected internal software failure";
      elsif Key = "awk.hint.use_help" then
         return
           "use --help for command-line syntax";
      elsif Key = "awk.hint.option_terminator" then
         return
           "use -- before filenames that begin with '-'";
      else
         return "";
      end if;
   end Template;
end Awk_CLI.Localization.Defaults;
