with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Rg.Diagnostics;
with Posix_Tools.Commands.Rg.Patterns;
with Posix_Tools.Commands.Rg.Input;
with Posix_Tools.Commands.Rg.Rendering;
with Regexp;

--  Sequential line matching and output for one input source.
package Posix_Tools.Commands.Rg.Search is
   type Binary_Policy is (Detect_Binary, Search_Binary, Treat_As_Text);

   type Execution_Options is record
      Style     : Posix_Tools.Commands.Rg.Rendering.Format;
      Invert    : Boolean := False;
      Max_Count : Natural := Natural'Last;
      Mode      : Posix_Tools.Commands.Rg.Rendering.Result_Mode :=
        Posix_Tools.Commands.Rg.Rendering.Matching_Lines;
      Binary    : Binary_Policy := Detect_Binary;
      Before_Context : Natural := 0;
      After_Context  : Natural := 0;
      Context_Separator : Ada.Strings.Unbounded.Unbounded_String;
      Separate_First_Group : Boolean := False;
      Null_Data : Boolean := False;
      Multiline : Boolean := False;
      Replace_Matches : Boolean := False;
      Replacement : Ada.Strings.Unbounded.Unbounded_String;
      Collect_Statistics : Boolean := False;
      Json_Output : Boolean := False;
      Encoding : Posix_Tools.Commands.Rg.Input.Encoding_Mode :=
        Posix_Tools.Commands.Rg.Input.Automatic_Encoding;
      Diagnostics : Posix_Tools.Commands.Rg.Diagnostics.Log_Level :=
        Posix_Tools.Commands.Rg.Diagnostics.Logging_Off;
      Abort_Callback : Regexp.Match_Abort_Callback := null;
   end record;

   type Search_Outcome is record
      Had_Match    : Boolean := False;
      Had_Result   : Boolean := False;
      Stop_All     : Boolean := False;
      Input_Error  : Boolean := False;
      Match_Error  : Boolean := False;
      Output_Error : Boolean := False;
      Was_Searched  : Boolean := False;
      Match_Count   : Natural := 0;
      Matched_Lines : Natural := 0;
      Bytes_Searched : Natural := 0;
      Bytes_Printed  : Natural := 0;
   end record;

   procedure Search_Source
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Name        : String;
      Label       : String;
      Options     : Execution_Options;
      Patterns    : Posix_Tools.Commands.Rg.Patterns.Compiled_Pattern_Array;
      Outcome     : out Search_Outcome);
end Posix_Tools.Commands.Rg.Search;
