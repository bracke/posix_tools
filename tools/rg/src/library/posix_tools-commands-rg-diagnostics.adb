with Posix_Tools.Localization;

package body Posix_Tools.Commands.Rg.Diagnostics is
   function Localized
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Message : String) return String
   is
      Locale : constant String := Context.Effective_Locale;

      function Starts_With (Prefix : String) return Boolean is
        (Message'Length >= Prefix'Length
         and then Message (Message'First .. Message'First + Prefix'Length - 1) = Prefix);

      function With_Detail
        (Prefix  : String;
         Key     : String;
         Default : String) return String
      is
         Detail : constant String :=
           (if Message'Length = Prefix'Length
            then ""
            else Message (Message'First + Prefix'Length .. Message'Last));
      begin
         return Posix_Tools.Localization.Text_1
           (Locale, Key, "detail", Detail, Default);
      end With_Detail;
   begin
      if Message = "a pattern is required" then
         return Posix_Tools.Localization.Text
           (Locale, "posix_tools.rg.diagnostic.pattern_required", Message);
      elsif Message = "--files cannot be combined with search or result options" then
         return Posix_Tools.Localization.Text
           (Locale, "posix_tools.rg.diagnostic.files_conflict", Message);
      elsif Message = "standard input cannot be used for both patterns and search data" then
         return Posix_Tools.Localization.Text
           (Locale, "posix_tools.rg.diagnostic.stdin_conflict", Message);
      elsif Message = "cannot write standard output" then
         return Posix_Tools.Localization.Text
           (Locale, "posix_tools.rg.diagnostic.write_stdout", Message);
      elsif Message = "sorted path set exceeds the 64 MiB limit" then
         return Posix_Tools.Localization.Text
           (Locale, "posix_tools.rg.diagnostic.sorted_paths_limit", Message);
      elsif Message = "standard input exceeds the 1 GiB spool limit" then
         return Posix_Tools.Localization.Text
           (Locale, "posix_tools.rg.diagnostic.stdin_spool_limit", Message);
      elsif Starts_With ("unknown option: ") then
         return With_Detail
           ("unknown option: ", "posix_tools.rg.diagnostic.unknown_option", "unknown option: {detail}");
      elsif Starts_With ("option requires an argument: ") then
         return With_Detail
           ("option requires an argument: ", "posix_tools.rg.diagnostic.option_argument",
            "option requires an argument: {detail}");
      elsif Starts_With ("invalid value for ") then
         return With_Detail
           ("invalid value for ", "posix_tools.rg.diagnostic.invalid_value", "invalid value for {detail}");
      elsif Starts_With ("value is too large for ") then
         return With_Detail
           ("value is too large for ", "posix_tools.rg.diagnostic.value_too_large",
            "value is too large for {detail}");
      elsif Starts_With ("unrecognized file type: ") then
         return With_Detail
           ("unrecognized file type: ", "posix_tools.rg.diagnostic.file_type",
            "unrecognized file type: {detail}");
      elsif Starts_With ("unknown encoding: ") then
         return With_Detail
           ("unknown encoding: ", "posix_tools.rg.diagnostic.encoding", "unknown encoding: {detail}");
      elsif Starts_With ("cannot read pattern file: ") then
         return With_Detail
           ("cannot read pattern file: ", "posix_tools.rg.diagnostic.pattern_file_read",
            "cannot read pattern file: {detail}");
      elsif Starts_With ("cannot close pattern file: ") then
         return With_Detail
           ("cannot close pattern file: ", "posix_tools.rg.diagnostic.pattern_file_close",
            "cannot close pattern file: {detail}");
      elsif Starts_With ("pattern exceeds the 4 MiB limit in file: ") then
         return With_Detail
           ("pattern exceeds the 4 MiB limit in file: ", "posix_tools.rg.diagnostic.pattern_limit",
            "pattern exceeds the 4 MiB limit in file: {detail}");
      elsif Starts_With ("invalid color specification: ") then
         return With_Detail
           ("invalid color specification: ", "posix_tools.rg.diagnostic.color_spec",
            "invalid color specification: {detail}");
      elsif Starts_With ("unrecognized color output type: ") then
         return With_Detail
           ("unrecognized color output type: ", "posix_tools.rg.diagnostic.color_type",
            "unrecognized color output type: {detail}");
      elsif Starts_With ("unrecognized color value: ") then
         return With_Detail
           ("unrecognized color value: ", "posix_tools.rg.diagnostic.color_value",
            "unrecognized color value: {detail}");
      elsif Starts_With ("unrecognized color style: ") then
         return With_Detail
           ("unrecognized color style: ", "posix_tools.rg.diagnostic.color_style",
            "unrecognized color style: {detail}");
      elsif Starts_With ("unrecognized color attribute: ") then
         return With_Detail
           ("unrecognized color attribute: ", "posix_tools.rg.diagnostic.color_attribute",
            "unrecognized color attribute: {detail}");
      elsif Starts_With ("duplicate capture group name: ") then
         return With_Detail
           ("duplicate capture group name: ", "posix_tools.rg.diagnostic.duplicate_capture",
            "duplicate capture group name: {detail}");
      elsif Starts_With ("invalid pattern: ") then
         return With_Detail
           ("invalid pattern: ", "posix_tools.rg.diagnostic.invalid_pattern", "invalid pattern: {detail}");
      elsif Starts_With ("regex feature is not supported in default mode: ") then
         return With_Detail
           ("regex feature is not supported in default mode: ",
            "posix_tools.rg.diagnostic.regex_feature",
            "regex feature is not supported in default mode: {detail}");
      elsif Starts_With ("cannot determine file system for ") then
         return With_Detail
           ("cannot determine file system for ", "posix_tools.rg.diagnostic.file_system",
            "cannot determine file system for {detail}");
      elsif Starts_With ("File system loop found: ") then
         return With_Detail
           ("File system loop found: ", "posix_tools.rg.diagnostic.file_system_loop",
            "File system loop found: {detail}");
      elsif Starts_With ("could not load an ignore file in ") then
         return With_Detail
           ("could not load an ignore file in ", "posix_tools.rg.diagnostic.ignore_file",
            "could not load an ignore file in {detail}");
      elsif Starts_With ("cannot read directory ") then
         return With_Detail
           ("cannot read directory ", "posix_tools.rg.diagnostic.read_directory",
            "cannot read directory {detail}");
      elsif Starts_With ("cannot follow ") then
         return With_Detail
           ("cannot follow ", "posix_tools.rg.diagnostic.follow", "cannot follow {detail}");
      elsif Starts_With ("cannot safely follow ") then
         return With_Detail
           ("cannot safely follow ", "posix_tools.rg.diagnostic.safe_follow",
            "cannot safely follow {detail}");
      elsif Starts_With ("read failed for ") then
         return With_Detail
           ("read failed for ", "posix_tools.rg.diagnostic.read_failed", "read failed for {detail}");
      elsif Starts_With ("cannot read ") then
         return With_Detail
           ("cannot read ", "posix_tools.rg.diagnostic.cannot_read", "cannot read {detail}");
      elsif Starts_With ("close failed for ") then
         return With_Detail
           ("close failed for ", "posix_tools.rg.diagnostic.close_failed", "close failed for {detail}");
      elsif Starts_With ("cannot buffer ") then
         return With_Detail
           ("cannot buffer ", "posix_tools.rg.diagnostic.cannot_buffer", "cannot buffer {detail}");
      elsif Starts_With ("matching limit exceeded in ") then
         return With_Detail
           ("matching limit exceeded in ", "posix_tools.rg.diagnostic.match_limit",
            "matching limit exceeded in {detail}");
      elsif Starts_With ("line exceeds the 4 MiB search limit in ") then
         return With_Detail
           ("line exceeds the 4 MiB search limit in ", "posix_tools.rg.diagnostic.line_limit",
            "line exceeds the 4 MiB search limit in {detail}");
      elsif Starts_With ("multiline input exceeds the 64 MiB buffer limit in ") then
         return With_Detail
           ("multiline input exceeds the 64 MiB buffer limit in ",
            "posix_tools.rg.diagnostic.multiline_limit",
            "multiline input exceeds the 64 MiB buffer limit in {detail}");
      elsif Starts_With ("leading context exceeds the 64 MiB buffer limit in ") then
         return With_Detail
           ("leading context exceeds the 64 MiB buffer limit in ",
            "posix_tools.rg.diagnostic.context_limit",
            "leading context exceeds the 64 MiB buffer limit in {detail}");
      elsif Starts_With ("replacement output exceeds the 64 MiB limit in ") then
         return With_Detail
           ("replacement output exceeds the 64 MiB limit in ",
            "posix_tools.rg.diagnostic.replacement_limit",
            "replacement output exceeds the 64 MiB limit in {detail}");
      elsif Starts_With ("match count exceeds the supported limit in ") then
         return With_Detail
           ("match count exceeds the supported limit in ", "posix_tools.rg.diagnostic.match_count_limit",
            "match count exceeds the supported limit in {detail}");
      elsif Starts_With ("parallel output exceeds the 64 MiB per-file limit: ") then
         return With_Detail
           ("parallel output exceeds the 64 MiB per-file limit: ",
            "posix_tools.rg.diagnostic.parallel_output_limit",
            "parallel output exceeds the 64 MiB per-file limit: {detail}");
      elsif Starts_With ("worker failed for ") then
         return With_Detail
           ("worker failed for ", "posix_tools.rg.diagnostic.worker_failed", "worker failed for {detail}");
      else
         return Message;
      end if;
   end Localized;

   procedure Error_Line
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Message : String)
   is
      Prefix : constant String := "rg: ";
      Plain  : constant String :=
        (if Message'Length >= Prefix'Length
           and then Message (Message'First .. Message'First + Prefix'Length - 1) = Prefix
         then Message (Message'First + Prefix'Length .. Message'Last)
         else Message);
   begin
      Context.Put_Error_Line (Prefix & Localized (Context, Plain));
   end Error_Line;

   procedure Put
     (Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Configured : Log_Level;
      Required   : Log_Level;
      Name       : String;
      Component  : String;
      Message    : String);

   procedure Put
     (Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Configured : Log_Level;
      Required   : Log_Level;
      Name       : String;
      Component  : String;
      Message    : String) is
   begin
      if Configured >= Required then
         Context.Put_Error_Line
           ("rg: " & Name & "|" & Component & "|" & Message);
      end if;
   end Put;

   procedure Debug
     (Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Configured : Log_Level;
      Component  : String;
      Message    : String) is
   begin
      Put (Context, Configured, Debug_Logging, "DEBUG", Component, Message);
   end Debug;

   procedure Trace
     (Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Configured : Log_Level;
      Component  : String;
      Message    : String) is
   begin
      Put (Context, Configured, Trace_Logging, "TRACE", Component, Message);
   end Trace;
end Posix_Tools.Commands.Rg.Diagnostics;
