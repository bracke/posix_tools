with Ada.Real_Time;
with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Rg.Diagnostics;
with Posix_Tools.Commands.Rg.Globs;
with Posix_Tools.Commands.Rg.Json;
with Posix_Tools.Commands.Rg.Options;
with Posix_Tools.Commands.Rg.Patterns;
with Posix_Tools.Commands.Rg.Rendering;
with Posix_Tools.Commands.Rg.Search;
with Posix_Tools.Commands.Rg.Traversal;
with Posix_Tools.Commands.Rg.Types;
with Posix_Tools.Help;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Rg_Arithmetic;
with Posix_Tools.Version;
with Regexp;

package body Posix_Tools.Commands.Rg is
   use type Posix_Tools.Commands.Rg.Options.Parse_Outcome;
   use type Posix_Tools.Commands.Rg.Rendering.Result_Mode;
   use type Posix_Tools.Commands.Rg.Search.Binary_Policy;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;
   use type Ada.Real_Time.Time;

   procedure Write_Help (Context : in out Posix_Tools.Commands.Contexts.Context'Class);

   procedure Write_Version (Context : in out Posix_Tools.Commands.Contexts.Context'Class);

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Config  : Posix_Tools.Commands.Rg.Options.Invocation;
      Outcome : Posix_Tools.Commands.Rg.Options.Parse_Outcome;
      Started : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
   begin
      Result.Status := Posix_Tools.Exit_Status.Success;

      if Context.Argument_Count = 1 and then Context.Argument (1) = "--posix-tools-identify" then
         Posix_Tools.Help.Render_Identity (Context, "rg");
         if Context.Output_Failed then
            Result.Status := Trouble;
         end if;
         return;
      end if;

      Posix_Tools.Commands.Rg.Options.Parse (Context, Config, Outcome);
      case Outcome is
         when Posix_Tools.Commands.Rg.Options.Show_Help =>
            Write_Help (Context);
         when Posix_Tools.Commands.Rg.Options.Show_Version =>
            Write_Version (Context);
         when Posix_Tools.Commands.Rg.Options.Parse_Error =>
            Posix_Tools.Commands.Rg.Diagnostics.Error_Line
              (Context, Posix_Tools.Commands.Rg.Options.Diagnostic (Config));
            Context.Put_Error_Line ("usage: rg [OPTIONS] PATTERN [PATH ...]");
            Result.Status := Trouble;
            return;
         when Posix_Tools.Commands.Rg.Options.Search_Ready =>
            Posix_Tools.Commands.Rg.Diagnostics.Debug
              (Context,
               Posix_Tools.Commands.Rg.Options.Diagnostics (Config),
               "rg::config",
               "accepted invocation with"
               & Natural'Image (Posix_Tools.Commands.Rg.Options.Pattern_Count (Config))
               & " pattern(s) and"
               & Natural'Image (Posix_Tools.Commands.Rg.Options.Path_Count (Config))
               & " path(s)");
            if Posix_Tools.Commands.Rg.Options.Type_List_Only (Config) then
               Posix_Tools.Commands.Rg.Types.Put_List (Context);
               Result.Status :=
                 (if Context.Output_Failed
                  then Trouble
                  else Posix_Tools.Exit_Status.Success);
               return;
            elsif Posix_Tools.Commands.Rg.Options.Files_Only (Config) then
               declare
                  Had_Result : Boolean := False;
                  Had_Error  : Boolean := False;
                  Glob_Policy : Posix_Tools.Commands.Rg.Globs.Policy;
                  Files : Posix_Tools.Commands.Rg.Traversal.File_Set;
                  Order : constant Posix_Tools.Commands.Rg.Traversal.Sort_Order :=
                    Posix_Tools.Commands.Rg.Options.Sort_Order (Config);
                  Metadata_Sort : constant Boolean :=
                    Posix_Tools.Commands.Rg.Traversal.Is_Metadata_Sort (Order);
                  function File_Style return Posix_Tools.Commands.Rg.Rendering.Format;

                  function File_Style return Posix_Tools.Commands.Rg.Rendering.Format is
                  begin
                     return
                       (Null_Pathnames => Posix_Tools.Commands.Rg.Options.Null_Pathnames (Config),
                        Color => Posix_Tools.Commands.Rg.Options.Color_Handling (Config),
                        Destination_Is_Terminal => Context.Standard_Output_Is_Terminal,
                        Colors => Posix_Tools.Commands.Rg.Options.Color_Palette (Config),
                        others => <>);
                  end File_Style;

                  function Directory_Options
                    (Preserve_Dot_Prefix : Boolean)
                     return Posix_Tools.Commands.Rg.Traversal.Discovery_Options;

                  function Directory_Options
                    (Preserve_Dot_Prefix : Boolean)
                     return Posix_Tools.Commands.Rg.Traversal.Discovery_Options is
                  begin
                     return
                       (Include_Hidden => Posix_Tools.Commands.Rg.Options.Include_Hidden (Config),
                        Use_Ignore     => Posix_Tools.Commands.Rg.Options.Use_Ignore_Files (Config),
                        Use_Vcs_Ignore => Posix_Tools.Commands.Rg.Options.Use_Vcs_Ignore (Config),
                        Use_Parent_Ignore => Posix_Tools.Commands.Rg.Options.Use_Parent_Ignore (Config),
                        Follow_Links   => Posix_Tools.Commands.Rg.Options.Follow_Links (Config),
                        One_File_System => Posix_Tools.Commands.Rg.Options.One_File_System (Config),
                        Max_Depth      => Posix_Tools.Commands.Rg.Options.Max_Depth (Config),
                        Max_File_Size  => Posix_Tools.Commands.Rg.Options.Max_File_Size (Config),
                        Prefix_Dot     => Preserve_Dot_Prefix,
                        Null_Pathnames => Posix_Tools.Commands.Rg.Options.Null_Pathnames (Config),
                        Sort           => Order,
                        Glob_Policy    => Glob_Policy,
                        Type_Policy    => Posix_Tools.Commands.Rg.Options.Type_Filter (Config),
                        Style          => File_Style,
                        Diagnostics    => Posix_Tools.Commands.Rg.Options.Diagnostics (Config));
                  end Directory_Options;

                  procedure List_Directory
                    (Name                : String;
                     Preserve_Dot_Prefix : Boolean);

                  procedure List_Directory
                    (Name                : String;
                     Preserve_Dot_Prefix : Boolean)
                  is
                     Tree_Result : Posix_Tools.Commands.Rg.Traversal.Traversal_Outcome;
                  begin
                     if Metadata_Sort then
                        Posix_Tools.Commands.Rg.Traversal.Collect_Tree
                          (Context, Name, Directory_Options (Preserve_Dot_Prefix), Files, Tree_Result);
                     else
                        Posix_Tools.Commands.Rg.Traversal.List_Tree
                          (Context, Name, Directory_Options (Preserve_Dot_Prefix), Tree_Result);
                     end if;
                     Had_Result := Had_Result or else Tree_Result.Had_Result;
                     Had_Error := Had_Error
                       or else Tree_Result.Input_Error
                       or else Tree_Result.Output_Error;
                  end List_Directory;

                  procedure List_Explicit (Name : String);

                  procedure List_Explicit (Name : String) is
                     Kind : constant Posix_Tools.Host_Adapters.File_System.File_Kind :=
                       Posix_Tools.Host_Adapters.File_System.Kind (Name);
                     Add_Result : Posix_Tools.Commands.Rg.Traversal.Traversal_Outcome :=
                       (others => <>);
                  begin
                     if Name = "-" then
                        if Metadata_Sort then
                           Posix_Tools.Commands.Rg.Traversal.Add_File
                             (Context, Files, "-", "<stdin>", True, Add_Result);
                        else
                           Posix_Tools.Commands.Rg.Rendering.Put_Path
                             (Context,
                              "<stdin>",
                              (if Posix_Tools.Commands.Rg.Options.Null_Pathnames (Config)
                               then ASCII.NUL
                               else ASCII.LF),
                              File_Style);
                           Had_Result := True;
                        end if;
                     elsif Kind = Posix_Tools.Host_Adapters.File_System.Directory then
                        List_Directory (Name, Preserve_Dot_Prefix => True);
                     elsif Kind = Posix_Tools.Host_Adapters.File_System.Ordinary_File then
                        if Metadata_Sort then
                           Posix_Tools.Commands.Rg.Traversal.Add_File
                             (Context, Files, Name, Name, False, Add_Result);
                        else
                           Posix_Tools.Commands.Rg.Rendering.Put_Path
                             (Context,
                              Name,
                              (if Posix_Tools.Commands.Rg.Options.Null_Pathnames (Config)
                               then ASCII.NUL
                               else ASCII.LF),
                              File_Style);
                           Had_Result := True;
                        end if;
                     else
                        Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                          (Context, "cannot read " & Posix_Tools.Commands.Helpers.Escape_Untrusted (Name));
                        Had_Error := True;
                     end if;
                     Had_Error := Had_Error or else Add_Result.Input_Error;
                  end List_Explicit;
               begin
                  for Index in 1 .. Posix_Tools.Commands.Rg.Options.Glob_Count (Config) loop
                     Posix_Tools.Commands.Rg.Globs.Add
                       (Glob_Policy, Posix_Tools.Commands.Rg.Options.Glob (Config, Index));
                  end loop;

                  if Posix_Tools.Commands.Rg.Options.Path_Count (Config) = 0 then
                     List_Directory (".", Preserve_Dot_Prefix => False);
                  else
                     for Index in 1 .. Posix_Tools.Commands.Rg.Options.Path_Count (Config) loop
                        List_Explicit (Posix_Tools.Commands.Rg.Options.Path (Config, Index));
                        exit when Context.Output_Failed;
                     end loop;
                  end if;

                  if Metadata_Sort then
                     declare
                        Sort_Result : Posix_Tools.Commands.Rg.Traversal.Traversal_Outcome :=
                          (others => <>);
                     begin
                        Posix_Tools.Commands.Rg.Traversal.Sort_Files
                          (Context, Files, Order, Sort_Result);
                        Had_Error := Had_Error or else Sort_Result.Input_Error;
                     end;

                     if Posix_Tools.Commands.Rg.Traversal.Files_Ready (Files) then
                        for Index in 1 .. Posix_Tools.Commands.Rg.Traversal.File_Count (Files) loop
                           Posix_Tools.Commands.Rg.Rendering.Put_Path
                             (Context,
                              Posix_Tools.Commands.Rg.Traversal.File_Label (Files, Index),
                              (if Posix_Tools.Commands.Rg.Options.Null_Pathnames (Config)
                               then ASCII.NUL
                               else ASCII.LF),
                              File_Style);
                           Had_Result := True;
                           exit when Context.Output_Failed;
                        end loop;
                     end if;
                  end if;

                  if Context.Output_Failed then
                     Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                       (Context, "cannot write standard output");
                  end if;

                  if Had_Error or else Context.Output_Failed then
                     Result.Status := Trouble;
                  elsif Had_Result then
                     Result.Status := Posix_Tools.Exit_Status.Success;
                  else
                     Result.Status := No_Matches;
                  end if;
                  return;
               end;
            else
               declare
                  Compiled : Posix_Tools.Commands.Rg.Patterns.Compiled_Pattern_Array
                    (1 .. Posix_Tools.Commands.Rg.Options.Pattern_Count (Config));
                  Had_Result : Boolean := False;
                  Had_Error : Boolean := False;
                  Glob_Policy : Posix_Tools.Commands.Rg.Globs.Policy;
                  Capture_Offset : Natural := 0;
                  Capture_Names : Posix_Tools.Arguments.Vector;
                  Statistics : Posix_Tools.Commands.Rg.Traversal.Traversal_Outcome;
                  Files : Posix_Tools.Commands.Rg.Traversal.File_Set;
                  Order : constant Posix_Tools.Commands.Rg.Traversal.Sort_Order :=
                    Posix_Tools.Commands.Rg.Options.Sort_Order (Config);
                  Metadata_Sort : constant Boolean :=
                    Posix_Tools.Commands.Rg.Traversal.Is_Metadata_Sort (Order);
                  Requested_Mode : constant Posix_Tools.Commands.Rg.Rendering.Result_Mode :=
                    Posix_Tools.Commands.Rg.Options.Mode (Config);
                  Json_Output : constant Boolean :=
                    Posix_Tools.Commands.Rg.Options.Json_Output (Config)
                    and then Requested_Mode in
                      Posix_Tools.Commands.Rg.Rendering.Matching_Lines
                      | Posix_Tools.Commands.Rg.Rendering.Only_Matching
                      | Posix_Tools.Commands.Rg.Rendering.Quiet;

                  function Output_Style
                    (Automatic_Name : Boolean)
                     return Posix_Tools.Commands.Rg.Rendering.Format;

                  function Output_Style
                    (Automatic_Name : Boolean)
                     return Posix_Tools.Commands.Rg.Rendering.Format
                  is
                  begin
                     return
                       (Prefix_Name      =>
                          Posix_Tools.Commands.Rg.Options.Prefix_Filename
                            (Config, Automatic_Name),
                        Show_Line_Number =>
                          Posix_Tools.Commands.Rg.Options.Line_Numbers
                            (Config, Context.Standard_Output_Is_Terminal),
                        Show_Column      => Posix_Tools.Commands.Rg.Options.Columns (Config),
                        Heading         =>
                          not Json_Output
                          and then Posix_Tools.Commands.Rg.Options.Headings
                            (Config, Context.Standard_Output_Is_Terminal),
                        Null_Pathnames  => Posix_Tools.Commands.Rg.Options.Null_Pathnames (Config),
                        Record_Terminator =>
                          (if Posix_Tools.Commands.Rg.Options.Null_Data (Config)
                           then ASCII.NUL
                           else ASCII.LF),
                        Color => Posix_Tools.Commands.Rg.Options.Color_Handling (Config),
                        Destination_Is_Terminal => Context.Standard_Output_Is_Terminal,
                        Colors => Posix_Tools.Commands.Rg.Options.Color_Palette (Config));
                  end Output_Style;

                  function Added (Left, Right : Natural) return Natural renames
                    Posix_Tools.Rg_Arithmetic.Saturating_Add;

                  procedure Merge_Statistics
                    (Search_Result : Posix_Tools.Commands.Rg.Search.Search_Outcome;
                     Search_Time   : Duration);
                  procedure Merge_Statistics
                    (Tree_Result : Posix_Tools.Commands.Rg.Traversal.Traversal_Outcome);

                  procedure Merge_Statistics
                    (Search_Result : Posix_Tools.Commands.Rg.Search.Search_Outcome;
                     Search_Time   : Duration) is
                  begin
                     Statistics.Match_Count := Added (Statistics.Match_Count, Search_Result.Match_Count);
                     Statistics.Matched_Lines := Added
                       (Statistics.Matched_Lines, Search_Result.Matched_Lines);
                     if Search_Result.Had_Match then
                        Statistics.Files_With_Matches := Added (Statistics.Files_With_Matches, 1);
                     end if;
                     if Search_Result.Was_Searched then
                        Statistics.Files_Searched := Added (Statistics.Files_Searched, 1);
                     end if;
                     Statistics.Bytes_Searched := Added
                       (Statistics.Bytes_Searched, Search_Result.Bytes_Searched);
                     Statistics.Bytes_Printed := Added
                       (Statistics.Bytes_Printed, Search_Result.Bytes_Printed);
                     Statistics.Search_Time := Statistics.Search_Time + Search_Time;
                  end Merge_Statistics;

                  procedure Merge_Statistics
                    (Tree_Result : Posix_Tools.Commands.Rg.Traversal.Traversal_Outcome) is
                  begin
                     Statistics.Match_Count := Added (Statistics.Match_Count, Tree_Result.Match_Count);
                     Statistics.Matched_Lines := Added
                       (Statistics.Matched_Lines, Tree_Result.Matched_Lines);
                     Statistics.Files_With_Matches := Added
                       (Statistics.Files_With_Matches, Tree_Result.Files_With_Matches);
                     Statistics.Files_Searched := Added
                       (Statistics.Files_Searched, Tree_Result.Files_Searched);
                     Statistics.Bytes_Searched := Added
                       (Statistics.Bytes_Searched, Tree_Result.Bytes_Searched);
                     Statistics.Bytes_Printed := Added
                       (Statistics.Bytes_Printed, Tree_Result.Bytes_Printed);
                     Statistics.Search_Time := Statistics.Search_Time + Tree_Result.Search_Time;
                  end Merge_Statistics;

                  function Number_Image (Value : Natural) return String is
                     Image : constant String := Natural'Image (Value);
                  begin
                     return Image (Image'First + 1 .. Image'Last);
                  end Number_Image;

                  function Seconds_Image (Value : Duration) return String is
                     Microseconds : constant Long_Long_Integer :=
                       Long_Long_Integer (Value * 1_000_000.0);
                     Whole : constant Natural := Natural (Microseconds / 1_000_000);
                     Fraction : constant Natural := Natural (Microseconds mod 1_000_000);
                     Fraction_Image : constant String := Number_Image (Fraction);
                     Padding : constant Natural := 6 - Fraction_Image'Length;
                  begin
                     return Number_Image (Whole)
                       & "." & String'[1 .. Padding => '0'] & Fraction_Image;
                  end Seconds_Image;

                  procedure Put_Statistics;
                  procedure Put_Json_Summary;

                  procedure Put_Statistics is
                     LF : constant Character := ASCII.LF;
                     Total_Time : constant Duration :=
                       Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Started);
                  begin
                     Context.Put
                       (LF
                        & Number_Image (Statistics.Match_Count) & " matches" & LF
                        & Number_Image (Statistics.Matched_Lines) & " matched lines" & LF
                        & Number_Image (Statistics.Files_With_Matches) & " files contained matches" & LF
                        & Number_Image (Statistics.Files_Searched) & " files searched" & LF
                        & Number_Image (Statistics.Bytes_Printed) & " bytes printed" & LF
                        & Number_Image (Statistics.Bytes_Searched) & " bytes searched" & LF
                        & Seconds_Image (Statistics.Search_Time) & " seconds spent searching" & LF
                        & Seconds_Image (Total_Time) & " seconds total" & LF);
                  end Put_Statistics;

                  procedure Put_Json_Summary is
                  begin
                     Context.Put_Line
                       (Posix_Tools.Commands.Rg.Json.Summary_Event
                          (Elapsed_Total =>
                             Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Started),
                           Search_Elapsed => Statistics.Search_Time,
                           Searches => Statistics.Files_Searched,
                           Searches_With_Match => Statistics.Files_With_Matches,
                           Bytes_Searched => Statistics.Bytes_Searched,
                           Bytes_Printed => Statistics.Bytes_Printed,
                           Matched_Lines => Statistics.Matched_Lines,
                           Matches => Statistics.Match_Count));
                  end Put_Json_Summary;

                  function Search_Options
                    (Automatic_Name : Boolean;
                     Recursive      : Boolean)
                     return Posix_Tools.Commands.Rg.Search.Execution_Options;

                  function Search_Options
                    (Automatic_Name : Boolean;
                     Recursive      : Boolean)
                     return Posix_Tools.Commands.Rg.Search.Execution_Options
                  is
                     Binary : constant Posix_Tools.Commands.Rg.Search.Binary_Policy :=
                       Posix_Tools.Commands.Rg.Options.Binary_Handling (Config);
                  begin
                     return
                       (Style     => Output_Style (Automatic_Name),
                        Invert    => Posix_Tools.Commands.Rg.Options.Invert_Match (Config),
                        Max_Count => Posix_Tools.Commands.Rg.Options.Max_Count (Config),
                        Mode      =>
                          (if Json_Output
                             and then Requested_Mode =
                               Posix_Tools.Commands.Rg.Rendering.Only_Matching
                           then Posix_Tools.Commands.Rg.Rendering.Matching_Lines
                           else Requested_Mode),
                        Before_Context => Posix_Tools.Commands.Rg.Options.Before_Context (Config),
                        After_Context  => Posix_Tools.Commands.Rg.Options.After_Context (Config),
                        Context_Separator => Ada.Strings.Unbounded.To_Unbounded_String
                          (Posix_Tools.Commands.Rg.Options.Context_Separator (Config)),
                        Separate_First_Group => Had_Result,
                        Null_Data => Posix_Tools.Commands.Rg.Options.Null_Data (Config),
                        Multiline => Posix_Tools.Commands.Rg.Options.Multiline (Config),
                        Replace_Matches => Posix_Tools.Commands.Rg.Options.Has_Replacement (Config),
                        Replacement => Ada.Strings.Unbounded.To_Unbounded_String
                          (Posix_Tools.Commands.Rg.Options.Replacement (Config)),
                        Collect_Statistics =>
                          Posix_Tools.Commands.Rg.Options.Statistics (Config) or else Json_Output,
                        Json_Output => Json_Output,
                        Encoding => Posix_Tools.Commands.Rg.Options.Encoding (Config),
                        Diagnostics => Posix_Tools.Commands.Rg.Options.Diagnostics (Config),
                        Abort_Callback => null,
                        Binary    =>
                          (if not Json_Output
                             and then not Recursive
                             and then Binary = Posix_Tools.Commands.Rg.Search.Detect_Binary
                           then Posix_Tools.Commands.Rg.Search.Search_Binary
                           else Binary));
                  end Search_Options;

                  procedure Search_One
                    (Name        : String;
                     Label       : String;
                     Prefix_Name : Boolean);

                  procedure Search_One
                    (Name        : String;
                     Label       : String;
                     Prefix_Name : Boolean)
                  is
                     Search_Result : Posix_Tools.Commands.Rg.Search.Search_Outcome;
                     Search_Started : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
                  begin
                     Posix_Tools.Commands.Rg.Search.Search_Source
                       (Context,
                        Name,
                        Label,
                        Search_Options (Prefix_Name, Recursive => False),
                        Compiled,
                        Search_Result);
                     Had_Result := Had_Result or else Search_Result.Had_Result;
                     Had_Error := Had_Error
                       or else Search_Result.Input_Error
                       or else Search_Result.Match_Error
                       or else Search_Result.Output_Error;
                     Merge_Statistics
                       (Search_Result,
                        Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Search_Started));
                  end Search_One;

                  procedure Collect_Explicit (Name, Label : String; Standard_Input : Boolean);

                  procedure Collect_Explicit
                    (Name, Label : String;
                     Standard_Input : Boolean)
                  is
                     Add_Result : Posix_Tools.Commands.Rg.Traversal.Traversal_Outcome :=
                       (others => <>);
                  begin
                     Posix_Tools.Commands.Rg.Traversal.Add_File
                       (Context, Files, Name, Label, Standard_Input, Add_Result);
                     Had_Error := Had_Error or else Add_Result.Input_Error;
                  end Collect_Explicit;

                  function Discovery_Options_For
                    (Preserve_Dot_Prefix : Boolean)
                     return Posix_Tools.Commands.Rg.Traversal.Discovery_Options;

                  function Discovery_Options_For
                    (Preserve_Dot_Prefix : Boolean)
                     return Posix_Tools.Commands.Rg.Traversal.Discovery_Options is
                  begin
                     return
                       (Include_Hidden => Posix_Tools.Commands.Rg.Options.Include_Hidden (Config),
                        Use_Ignore     => Posix_Tools.Commands.Rg.Options.Use_Ignore_Files (Config),
                        Use_Vcs_Ignore => Posix_Tools.Commands.Rg.Options.Use_Vcs_Ignore (Config),
                        Use_Parent_Ignore => Posix_Tools.Commands.Rg.Options.Use_Parent_Ignore (Config),
                        Follow_Links   => Posix_Tools.Commands.Rg.Options.Follow_Links (Config),
                        One_File_System => Posix_Tools.Commands.Rg.Options.One_File_System (Config),
                        Max_Depth      => Posix_Tools.Commands.Rg.Options.Max_Depth (Config),
                        Max_File_Size  => Posix_Tools.Commands.Rg.Options.Max_File_Size (Config),
                        Prefix_Dot     => Preserve_Dot_Prefix,
                        Null_Pathnames => Posix_Tools.Commands.Rg.Options.Null_Pathnames (Config),
                        Sort           => Order,
                        Glob_Policy    => Glob_Policy,
                        Type_Policy    => Posix_Tools.Commands.Rg.Options.Type_Filter (Config),
                        Style          => Output_Style (Automatic_Name => True),
                        Diagnostics    => Posix_Tools.Commands.Rg.Options.Diagnostics (Config));
                  end Discovery_Options_For;

                  function Traversal_Options_For
                    (Preserve_Dot_Prefix : Boolean;
                     Automatic_Name      : Boolean)
                     return Posix_Tools.Commands.Rg.Traversal.Traversal_Options;

                  function Traversal_Options_For
                    (Preserve_Dot_Prefix : Boolean;
                     Automatic_Name      : Boolean)
                     return Posix_Tools.Commands.Rg.Traversal.Traversal_Options is
                     Discovery : constant Posix_Tools.Commands.Rg.Traversal.Discovery_Options :=
                       Discovery_Options_For (Preserve_Dot_Prefix);
                  begin
                     return
                       (Include_Hidden => Discovery.Include_Hidden,
                        Use_Ignore     => Discovery.Use_Ignore,
                        Use_Vcs_Ignore => Discovery.Use_Vcs_Ignore,
                        Use_Parent_Ignore => Discovery.Use_Parent_Ignore,
                        Follow_Links   => Discovery.Follow_Links,
                        One_File_System => Discovery.One_File_System,
                        Max_Depth      => Discovery.Max_Depth,
                        Max_File_Size  => Discovery.Max_File_Size,
                        Prefix_Dot     => Discovery.Prefix_Dot,
                        Null_Pathnames => Discovery.Null_Pathnames,
                        Sort           => Discovery.Sort,
                        Threads        => Posix_Tools.Commands.Rg.Options.Threads (Config),
                        Glob_Policy    => Discovery.Glob_Policy,
                        Type_Policy    => Discovery.Type_Policy,
                        Search         => Search_Options (Automatic_Name, Recursive => True),
                        Diagnostics    => Discovery.Diagnostics);
                  end Traversal_Options_For;

                  function Has_Standard_Input_Path return Boolean is
                  begin
                     for Index in 1 .. Posix_Tools.Commands.Rg.Options.Path_Count (Config) loop
                        if Posix_Tools.Commands.Rg.Options.Path (Config, Index) = "-" then
                           return True;
                        end if;
                     end loop;
                     return False;
                  end Has_Standard_Input_Path;

                  function Use_Parallel_Batch return Boolean is
                    (not Metadata_Sort
                     and then Posix_Tools.Commands.Rg.Options.Path_Count (Config) > 1
                     and then not Has_Standard_Input_Path
                     and then Posix_Tools.Commands.Rg.Traversal.Effective_Worker_Count
                       (Posix_Tools.Commands.Rg.Options.Threads (Config), Order) > 1);

                  procedure Search_Directory
                    (Name                : String;
                     Preserve_Dot_Prefix : Boolean);

                  procedure Search_Directory
                    (Name                : String;
                     Preserve_Dot_Prefix : Boolean)
                  is
                     Search_Result : Posix_Tools.Commands.Rg.Traversal.Traversal_Outcome;
                  begin
                     if Metadata_Sort then
                        Posix_Tools.Commands.Rg.Traversal.Collect_Tree
                          (Context, Name, Discovery_Options_For (Preserve_Dot_Prefix), Files, Search_Result);
                     else
                        Posix_Tools.Commands.Rg.Traversal.Search_Tree
                          (Context,
                           Name,
                           Compiled,
                           Traversal_Options_For (Preserve_Dot_Prefix, Automatic_Name => True),
                           Search_Result);
                     end if;
                     Had_Result := Had_Result or else Search_Result.Had_Result;
                     Had_Error := Had_Error
                       or else Search_Result.Input_Error
                       or else Search_Result.Match_Error
                       or else Search_Result.Output_Error;
                     Merge_Statistics (Search_Result);
                  end Search_Directory;

                  procedure Collect_Directory
                    (Name                : String;
                     Preserve_Dot_Prefix : Boolean)
                  is
                     Collect_Result : Posix_Tools.Commands.Rg.Traversal.Traversal_Outcome;
                  begin
                     Posix_Tools.Commands.Rg.Traversal.Collect_Tree
                       (Context,
                        Name,
                        Discovery_Options_For (Preserve_Dot_Prefix),
                        Files,
                        Collect_Result);
                     Had_Error := Had_Error or else Collect_Result.Input_Error;
                  end Collect_Directory;

                  procedure Search_Parallel_Batch is
                     Search_Result : Posix_Tools.Commands.Rg.Traversal.Traversal_Outcome;
                  begin
                     Posix_Tools.Commands.Rg.Traversal.Search_Files
                       (Context,
                        Files,
                        Compiled,
                        Traversal_Options_For
                          (Preserve_Dot_Prefix => True,
                           Automatic_Name      => True),
                        Search_Result);
                     Had_Result := Had_Result or else Search_Result.Had_Result;
                     Had_Error := Had_Error
                       or else Search_Result.Input_Error
                       or else Search_Result.Match_Error
                       or else Search_Result.Output_Error;
                     Merge_Statistics (Search_Result);
                  end Search_Parallel_Batch;
               begin
                  for Index in 1 .. Posix_Tools.Commands.Rg.Options.Glob_Count (Config) loop
                     Posix_Tools.Commands.Rg.Globs.Add
                       (Glob_Policy, Posix_Tools.Commands.Rg.Options.Glob (Config, Index));
                  end loop;

                  for Index in Compiled'Range loop
                     declare
                        Diagnostic : Posix_Tools.Commands.Rg.Patterns.Compile_Diagnostic;
                     begin
                        Posix_Tools.Commands.Rg.Patterns.Compile
                          (Posix_Tools.Commands.Rg.Options.Pattern (Config, Index),
                           (Fixed_Strings => Posix_Tools.Commands.Rg.Options.Fixed_Strings (Config),
                            Case_Handling => Posix_Tools.Commands.Rg.Options.Case_Handling (Config),
                            Whole_Word    => Posix_Tools.Commands.Rg.Options.Whole_Word (Config),
                            Whole_Line    => Posix_Tools.Commands.Rg.Options.Whole_Line (Config),
                            Dot_Matches_Newline =>
                              Posix_Tools.Commands.Rg.Options.Multiline_Dotall (Config),
                            Multiline_Anchors =>
                              Posix_Tools.Commands.Rg.Options.Multiline (Config),
                            Capture_Offset => Capture_Offset,
                            others        => <>),
                           Compiled (Index),
                           Diagnostic);

                        case Diagnostic.Status is
                           when Posix_Tools.Commands.Rg.Patterns.Pattern_Ok =>
                              Posix_Tools.Commands.Rg.Diagnostics.Trace
                                (Context,
                                 Posix_Tools.Commands.Rg.Options.Diagnostics (Config),
                                 "rg::regexp",
                                 "compiled pattern" & Positive'Image (Index) & " with regexp");
                              declare
                                 Count : constant Natural :=
                                   Posix_Tools.Commands.Rg.Patterns.Capture_Count (Compiled (Index));
                              begin
                                 for Capture in 1 .. Count loop
                                    declare
                                       Name : constant String :=
                                         Posix_Tools.Commands.Rg.Patterns.Capture_Name
                                           (Compiled (Index), Capture);
                                    begin
                                       if Name /= "" then
                                          for Existing of Capture_Names loop
                                             if Existing = Name then
                                                Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                                                  (Context, "duplicate capture group name: " & Name);
                                                Result.Status := Trouble;
                                                return;
                                             end if;
                                          end loop;
                                          Capture_Names.Append (Name);
                                       end if;
                                    end;
                                 end loop;
                                 if Count > Natural'Last - Capture_Offset then
                                    Capture_Offset := Natural'Last;
                                 else
                                    Capture_Offset := Capture_Offset + Count;
                                 end if;
                              end;
                           when Posix_Tools.Commands.Rg.Patterns.Pattern_Invalid =>
                              Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                                (Context,
                                 "invalid pattern: " & Regexp.Compile_Status'Image (Diagnostic.Engine_Status)
                                 & (if Diagnostic.Error_Offset = 0
                                    then ""
                                    else " at byte" & Natural'Image (Diagnostic.Error_Offset)));
                              Result.Status := Trouble;
                              return;
                           when Posix_Tools.Commands.Rg.Patterns.Pattern_Disallowed =>
                              Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                                (Context,
                                 "regex feature is not supported in default mode: "
                                 & Regexp.Policy_Feature'Image (Diagnostic.Feature));
                              Result.Status := Trouble;
                              return;
                        end case;
                     end;
                  end loop;

                  Posix_Tools.Commands.Rg.Diagnostics.Debug
                    (Context,
                     Posix_Tools.Commands.Rg.Options.Diagnostics (Config),
                     "rg::regexp",
                     "compiled" & Natural'Image (Compiled'Length) & " pattern(s) with regexp");

                  if Posix_Tools.Commands.Rg.Options.Path_Count (Config) = 0 then
                     if Posix_Tools.Commands.Rg.Options.Pattern_Stdin_Used (Config)
                       or else Context.Standard_Input_Is_Terminal
                     then
                        Search_Directory (".", Preserve_Dot_Prefix => False);
                     elsif Metadata_Sort then
                        Collect_Explicit ("-", "<stdin>", Standard_Input => True);
                     else
                        Search_One ("-", "<stdin>", Prefix_Name => False);
                     end if;
                  else
                     for Index in 1 .. Posix_Tools.Commands.Rg.Options.Path_Count (Config) loop
                        declare
                           Name : constant String := Posix_Tools.Commands.Rg.Options.Path (Config, Index);
                        begin
                           if Name /= "-"
                             and then Posix_Tools.Host_Adapters.File_System.Kind (Name)
                               = Posix_Tools.Host_Adapters.File_System.Directory
                           then
                              if Use_Parallel_Batch then
                                 Collect_Directory (Name, Preserve_Dot_Prefix => True);
                              else
                                 Search_Directory (Name, Preserve_Dot_Prefix => True);
                              end if;
                           elsif Use_Parallel_Batch then
                              Collect_Explicit (Name, Name, Standard_Input => False);
                           elsif Metadata_Sort and then Name = "-" then
                              Collect_Explicit ("-", "<stdin>", Standard_Input => True);
                           elsif Metadata_Sort
                             and then Posix_Tools.Host_Adapters.File_System.Kind (Name)
                               = Posix_Tools.Host_Adapters.File_System.Ordinary_File
                           then
                              Collect_Explicit (Name, Name, Standard_Input => False);
                           elsif Metadata_Sort then
                              Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                                (Context,
                                 "cannot read "
                                 & Posix_Tools.Commands.Helpers.Escape_Untrusted (Name));
                              Had_Error := True;
                           else
                              Search_One
                                (Name,
                                 (if Name = "-" then "<stdin>" else Name),
                                 Prefix_Name => Posix_Tools.Commands.Rg.Options.Path_Count (Config) > 1);
                           end if;
                        end;
                        exit when Context.Output_Failed
                          or else
                            (Posix_Tools.Commands.Rg.Options.Mode (Config)
                               = Posix_Tools.Commands.Rg.Rendering.Quiet
                             and then Had_Result
                             and then not Posix_Tools.Commands.Rg.Options.Statistics (Config));
                     end loop;

                     if Use_Parallel_Batch and then not Context.Output_Failed then
                        Search_Parallel_Batch;
                     end if;
                  end if;

                  if Metadata_Sort then
                     declare
                        Sort_Result : Posix_Tools.Commands.Rg.Traversal.Traversal_Outcome :=
                          (others => <>);
                        Prefix_Name : constant Boolean :=
                          (if Posix_Tools.Commands.Rg.Options.Path_Count (Config) = 0
                           then Posix_Tools.Commands.Rg.Options.Pattern_Stdin_Used (Config)
                             or else Context.Standard_Input_Is_Terminal
                           elsif Posix_Tools.Commands.Rg.Options.Path_Count (Config) > 1
                           then True
                           else Posix_Tools.Commands.Rg.Options.Path (Config, 1) /= "-"
                             and then Posix_Tools.Host_Adapters.File_System.Kind
                               (Posix_Tools.Commands.Rg.Options.Path (Config, 1))
                                 = Posix_Tools.Host_Adapters.File_System.Directory);
                     begin
                        Posix_Tools.Commands.Rg.Traversal.Sort_Files
                          (Context, Files, Order, Sort_Result);
                        Had_Error := Had_Error or else Sort_Result.Input_Error;

                        if Posix_Tools.Commands.Rg.Traversal.Files_Ready (Files) then
                           for Index in 1 .. Posix_Tools.Commands.Rg.Traversal.File_Count (Files) loop
                              Search_One
                                (Posix_Tools.Commands.Rg.Traversal.File_Name (Files, Index),
                                 Posix_Tools.Commands.Rg.Traversal.File_Label (Files, Index),
                                 Prefix_Name);
                              exit when Context.Output_Failed
                                or else
                                  (Posix_Tools.Commands.Rg.Options.Mode (Config)
                                     = Posix_Tools.Commands.Rg.Rendering.Quiet
                                   and then Had_Result
                                   and then not Posix_Tools.Commands.Rg.Options.Statistics (Config));
                           end loop;
                        end if;
                     end;
                  end if;

                  if Context.Output_Failed then
                     Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                       (Context, "cannot write standard output");
                  end if;

                  if Posix_Tools.Commands.Rg.Options.Max_Count (Config) > 0
                    and then not Context.Output_Failed
                  then
                     if Json_Output then
                        Put_Json_Summary;
                     elsif Posix_Tools.Commands.Rg.Options.Statistics (Config) then
                        Put_Statistics;
                     end if;
                  end if;

                  if Posix_Tools.Commands.Rg.Options.Mode (Config)
                       = Posix_Tools.Commands.Rg.Rendering.Quiet
                    and then Had_Result
                  then
                     Result.Status := Posix_Tools.Exit_Status.Success;
                  elsif Had_Error or else Context.Output_Failed then
                     Result.Status := Trouble;
                  elsif Had_Result then
                     Result.Status := Posix_Tools.Exit_Status.Success;
                  else
                     Result.Status := No_Matches;
                  end if;
                  return;
               end;
            end if;
      end case;

      Result.Status := (if Context.Output_Failed then Trouble else Posix_Tools.Exit_Status.Success);
   end Run;

   procedure Write_Help (Context : in out Posix_Tools.Commands.Contexts.Context'Class) is
      LF : constant Character := ASCII.LF;
   begin
      Context.Put
        ("Usage: rg [OPTIONS] PATTERN [PATH ...]" & LF
         & "       rg [OPTIONS] -e PATTERN... [-f FILE]... [PATH ...]" & LF
         & "       rg [OPTIONS] --files [PATH ...]" & LF
         & "Search standard input or explicit files for lines matching PATTERN." & LF
         & LF
         & "  -e PATTERN   add a search pattern" & LF
         & "  -f FILE      add patterns from FILE, one per line" & LF
         & "  -g GLOB      include or exclude paths with an ordered glob" & LF
         & "  -t TYPE      search only files matching TYPE" & LF
         & "  -T TYPE      exclude files matching TYPE" & LF
         & "  -F           treat patterns as fixed strings" & LF
         & "  -i, -s, -S   insensitive, sensitive, or smart case" & LF
         & "  -w, -x       require a whole-word or whole-line match" & LF
         & "  -n, -N       show or suppress line numbers" & LF
         & "  -H, -I       show or suppress filenames" & LF
         & "      --heading, --no-heading  group results beneath file headings" & LF
         & "  -v           select non-matching lines" & LF
         & "  -m NUM       stop after NUM selected lines per file" & LF
         & "  -A, -B, -C NUM  show trailing, leading, or surrounding context" & LF
         & "      --context-separator TEXT  set the separator between context groups" & LF
         & "  -c, -l, -q   count lines, list matching files, or search quietly" & LF
         & "  -o           print only non-overlapping matching text" & LF
         & "  -r TEXT      replace matches in selected output" & LF
         & "      --count-matches  report the number of matches" & LF
         & "      --files-without-match  list files with no selected lines" & LF
         & "      --files  list files that would be searched" & LF
         & "      --type-list  list supported file types" & LF
         & "      --column  show the first match byte column" & LF
         & "      --hidden  search hidden files and directories" & LF
         & "      --no-ignore  do not respect ignore files" & LF
         & "  -u, -uu, -uuu  disable filters; repeat for hidden and binary files" & LF
         & "      --no-ignore-vcs  disable Git ignore sources" & LF
         & "      --no-ignore-parent  do not read ignore files above search roots" & LF
         & "  -L, --follow  follow symbolic links during recursive discovery" & LF
         & "      --one-file-system  do not descend into other file systems" & LF
         & "      --max-depth NUM  descend at most NUM directories" & LF
         & "      --max-filesize NUM  skip discovered files larger than NUM bytes" & LF
         & "      --sort KEY, --sortr KEY  sort by path or file metadata" & LF
         & "  -j, --threads NUM  use approximately NUM search worker threads (0 is automatic)" & LF
         & "      --stats  print aggregate search statistics" & LF
         & "      --json  emit ripgrep-compatible JSON Lines events" & LF
         & "      --debug, --trace  show traversal and search diagnostics" & LF
         & "      --color WHEN  use auto, always, never, or ansi color output" & LF
         & "      --colors RULE  customize a named output color or style" & LF
         & "  -a, --text  search binary data as text" & LF
         & "      --binary  search binary files without printing their contents" & LF
         & "  -E, --encoding NAME  decode a ripgrep/WHATWG encoding_rs 0.8.35 label" & LF
         & "  -0, --null  write NUL after output pathnames" & LF
         & "      --null-data  use NUL-delimited search records" & LF
         & "  -U, --multiline  permit matches to span multiple lines" & LF
         & "      --multiline-dotall  make dot match line terminators in multiline mode" & LF
         & LF
         & "      --help, --version, --posix-tools-identify" & LF);
   end Write_Help;

   procedure Write_Version (Context : in out Posix_Tools.Commands.Contexts.Context'Class) is
   begin
      Context.Put
        ("rg " & Posix_Tools.Version.Version_String & ASCII.LF
         & "engine regexp" & ASCII.LF
         & "compatibility reference ripgrep 15.2.0" & ASCII.LF
         & "license MIT" & ASCII.LF);
   end Write_Version;
end Posix_Tools.Commands.Rg;
