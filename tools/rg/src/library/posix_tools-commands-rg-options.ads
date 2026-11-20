with Posix_Tools.Arguments;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Rg.Diagnostics;
with Posix_Tools.Commands.Rg.Input;
with Posix_Tools.Commands.Rg.Patterns;
with Posix_Tools.Commands.Rg.Colors;
with Posix_Tools.Commands.Rg.Rendering;
with Posix_Tools.Commands.Rg.Search;
with Posix_Tools.Commands.Rg.Traversal;
with Posix_Tools.Commands.Rg.Types;
private with Ada.Strings.Unbounded;

--  Deterministic command-line parsing for rg. Only options represented here
--  are accepted; later phases add options together with their semantics.
package Posix_Tools.Commands.Rg.Options is
   type Parse_Outcome is (Search_Ready, Show_Help, Show_Version, Parse_Error);

   type Invocation is private;

   procedure Parse
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Config  : out Invocation;
      Outcome : out Parse_Outcome);

   function Diagnostic (Config : Invocation) return String;
   function Pattern_Count (Config : Invocation) return Natural;
   function Pattern (Config : Invocation; Index : Positive) return String
     with Pre => Index <= Pattern_Count (Config);
   function Path_Count (Config : Invocation) return Natural;
   function Path (Config : Invocation; Index : Positive) return String
     with Pre => Index <= Path_Count (Config);
   function Glob_Count (Config : Invocation) return Natural;
   function Glob (Config : Invocation; Index : Positive) return String
     with Pre => Index <= Glob_Count (Config);
   function Fixed_Strings (Config : Invocation) return Boolean;
   function Files_Only (Config : Invocation) return Boolean;
   function Type_List_Only (Config : Invocation) return Boolean;
   function Type_Filter
     (Config : Invocation) return Posix_Tools.Commands.Rg.Types.Policy;
   function Pattern_Stdin_Used (Config : Invocation) return Boolean;
   function Whole_Word (Config : Invocation) return Boolean;
   function Whole_Line (Config : Invocation) return Boolean;
   function Only_Matching (Config : Invocation) return Boolean;
   function Include_Hidden (Config : Invocation) return Boolean;
   function Use_Ignore_Files (Config : Invocation) return Boolean;
   function Use_Vcs_Ignore (Config : Invocation) return Boolean;
   function Use_Parent_Ignore (Config : Invocation) return Boolean;
   function Follow_Links (Config : Invocation) return Boolean;
   function One_File_System (Config : Invocation) return Boolean;
   function Max_Depth (Config : Invocation) return Natural;
   function Max_File_Size (Config : Invocation) return Long_Long_Integer;
   function Sort_Order
     (Config : Invocation) return Posix_Tools.Commands.Rg.Traversal.Sort_Order;
   function Threads (Config : Invocation) return Natural;
   function Binary_Handling
     (Config : Invocation) return Posix_Tools.Commands.Rg.Search.Binary_Policy;
   function Line_Numbers
     (Config             : Invocation;
      Output_Is_Terminal : Boolean) return Boolean;
   function Columns (Config : Invocation) return Boolean;
   function Headings
     (Config             : Invocation;
      Output_Is_Terminal : Boolean) return Boolean;
   function Invert_Match (Config : Invocation) return Boolean;
   function Max_Count (Config : Invocation) return Natural;
   function Before_Context (Config : Invocation) return Natural;
   function After_Context (Config : Invocation) return Natural;
   function Context_Separator (Config : Invocation) return String;
   function Null_Pathnames (Config : Invocation) return Boolean;
   function Null_Data (Config : Invocation) return Boolean;
   function Multiline (Config : Invocation) return Boolean;
   function Multiline_Dotall (Config : Invocation) return Boolean;
   function Has_Replacement (Config : Invocation) return Boolean;
   function Replacement (Config : Invocation) return String;
   function Statistics (Config : Invocation) return Boolean;
   function Json_Output (Config : Invocation) return Boolean;
   function Diagnostics
     (Config : Invocation) return Posix_Tools.Commands.Rg.Diagnostics.Log_Level;
   function Encoding
     (Config : Invocation) return Posix_Tools.Commands.Rg.Input.Encoding_Mode;
   function Color_Handling
     (Config : Invocation) return Posix_Tools.Commands.Rg.Rendering.Color_Mode;
   function Color_Palette
     (Config : Invocation) return Posix_Tools.Commands.Rg.Colors.Palette;
   function Mode
     (Config : Invocation) return Posix_Tools.Commands.Rg.Rendering.Result_Mode;
   function Prefix_Filename
     (Config          : Invocation;
      Automatic_Value : Boolean) return Boolean;
   function Case_Handling
     (Config : Invocation) return Posix_Tools.Commands.Rg.Patterns.Case_Mode;

private
   type Requested_Case_Mode is (Sensitive_Case, Insensitive_Case, Smart_Case);
   type Toggle_Mode is (Automatic, Enabled, Disabled);

   type Invocation is record
      Pattern_Texts : Posix_Tools.Arguments.Vector;
      Pattern_Sources : Posix_Tools.Arguments.Vector;
      Paths         : Posix_Tools.Arguments.Vector;
      Glob_Texts    : Posix_Tools.Arguments.Vector;
      Error_Text    : Posix_Tools.Arguments.Vector;
      Fixed         : Boolean := False;
      List_Files    : Boolean := False;
      List_Types    : Boolean := False;
      File_Types    : Posix_Tools.Commands.Rg.Types.Policy;
      Used_Pattern_Stdin : Boolean := False;
      Word          : Boolean := False;
      Line          : Boolean := False;
      Hidden        : Boolean := False;
      Ignore_Files  : Boolean := True;
      Vcs_Ignore    : Boolean := True;
      Parent_Ignore : Boolean := True;
      Follow        : Boolean := False;
      Single_Device : Boolean := False;
      Unrestricted  : Natural range 0 .. 3 := 0;
      Depth_Limit   : Natural := Natural'Last;
      File_Size_Limit : Long_Long_Integer := Long_Long_Integer'Last;
      Ordering      : Posix_Tools.Commands.Rg.Traversal.Sort_Order :=
        Posix_Tools.Commands.Rg.Traversal.Unsorted;
      Worker_Count  : Natural := 0;
      Binary_Mode   : Posix_Tools.Commands.Rg.Search.Binary_Policy :=
        Posix_Tools.Commands.Rg.Search.Detect_Binary;
      Line_Numbers  : Toggle_Mode := Automatic;
      File_Names    : Toggle_Mode := Automatic;
      Column_Number : Boolean := False;
      Heading_Mode  : Toggle_Mode := Automatic;
      Inverted      : Boolean := False;
      Match_Limit   : Natural := Natural'Last;
      Before_Lines  : Natural := 0;
      After_Lines   : Natural := 0;
      Separator     : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.To_Unbounded_String ("--");
      Nul_Paths     : Boolean := False;
      Nul_Records   : Boolean := False;
      Multi_Record  : Boolean := False;
      Dotall        : Boolean := False;
      Replace_Set   : Boolean := False;
      Replace_Text  : Ada.Strings.Unbounded.Unbounded_String;
      Show_Statistics : Boolean := False;
      Json            : Boolean := False;
      Logging         : Posix_Tools.Commands.Rg.Diagnostics.Log_Level :=
        Posix_Tools.Commands.Rg.Diagnostics.Logging_Off;
      Input_Encoding  : Posix_Tools.Commands.Rg.Input.Encoding_Mode :=
        Posix_Tools.Commands.Rg.Input.Automatic_Encoding;
      Color_Output : Posix_Tools.Commands.Rg.Rendering.Color_Mode :=
        Posix_Tools.Commands.Rg.Rendering.Color_Automatic;
      Colors : Posix_Tools.Commands.Rg.Colors.Palette :=
        Posix_Tools.Commands.Rg.Colors.Default_Palette;
      Result_Format : Posix_Tools.Commands.Rg.Rendering.Result_Mode :=
        Posix_Tools.Commands.Rg.Rendering.Matching_Lines;
      Match_Only    : Boolean := False;
      Case_Mode     : Requested_Case_Mode := Sensitive_Case;
   end record;
end Posix_Tools.Commands.Rg.Options;
