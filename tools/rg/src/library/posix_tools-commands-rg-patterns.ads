with Regexp;
with Ada.Strings.Unbounded;

--  The ripgrep-compatible policy and matching adapter over Regexp.
package Posix_Tools.Commands.Rg.Patterns is
   type Case_Mode is (Sensitive, Insensitive);

   type Compile_Options is record
      Fixed_Strings       : Boolean := False;
      Case_Handling       : Case_Mode := Sensitive;
      Whole_Word          : Boolean := False;
      Whole_Line          : Boolean := False;
      Dot_Matches_Newline : Boolean := False;
      Multiline_Anchors   : Boolean := False;
      Character_Mode      : Regexp.Character_Mode_Type := Regexp.UTF_8_Mode;
      Capture_Offset      : Natural := 0;
   end record;

   type Pattern_Status is (Pattern_Ok, Pattern_Invalid, Pattern_Disallowed);

   type Compile_Diagnostic is record
      Status       : Pattern_Status := Pattern_Invalid;
      Engine_Status : Regexp.Compile_Status := Regexp.Empty_Pattern;
      Error_Offset : Natural := 0;
      Feature      : Regexp.Policy_Feature := Regexp.Policy_Feature_None;
   end record;

   type Compiled_Pattern is private;
   type Compiled_Pattern_Array is array (Positive range <>) of Compiled_Pattern;
   type Match_Cursor is private;
   type Match_Cursor_Array is array (Positive range <>) of Match_Cursor;

   --  Compile Source under the default ripgrep syntax policy. Backreferences,
   --  lookaround, atomic groups, and possessive quantifiers are rejected.
   procedure Compile
     (Source     : String;
      Options    : Compile_Options;
      Pattern    : out Compiled_Pattern;
      Diagnostic : out Compile_Diagnostic);

   function Is_Valid (Pattern : Compiled_Pattern) return Boolean;
   function Capture_Count (Pattern : Compiled_Pattern) return Natural;
   function Capture_Name (Pattern : Compiled_Pattern; Index : Positive) return String
     with Pre => Is_Valid (Pattern) and then Index <= Capture_Count (Pattern);

   --  Find the first match. Offsets in the result are byte offsets, including
   --  in UTF-8 mode.
   function Find_First
     (Pattern   : Compiled_Pattern;
      Text      : String;
      Max_Steps : Natural := Regexp.Default_Max_Steps;
      Abort_Callback : Regexp.Match_Abort_Callback := null)
      return Regexp.Match_Result
      with Pre => Is_Valid (Pattern);

   procedure Start
     (Pattern : Compiled_Pattern;
      Cursor  : out Match_Cursor;
      Abort_Callback : Regexp.Match_Abort_Callback := null)
     with Pre => Is_Valid (Pattern);

   procedure Next
     (Cursor : in out Match_Cursor;
      Text   : String;
      Found  : out Regexp.Match_Result);

   procedure Next_With_Captures
     (Cursor   : in out Match_Cursor;
      Text     : String;
      Found    : out Regexp.Match_Result;
      Captures : out Regexp.Capture_Buffer;
      Count    : out Natural);

   type Replacement_Status is (Replacement_Ok, Replacement_Too_Large);

   --  Append one ripgrep replacement expansion. Capture references use the
   --  $name and ${name} syntax accepted by ripgrep rather than the native
   --  regexp replacement-template syntax.
   procedure Append_Replacement
     (Pattern        : Compiled_Pattern;
      Text           : String;
      Found          : Regexp.Match_Result;
      Captures       : Regexp.Capture_Buffer;
      Capture_Count  : Natural;
      Template       : String;
      Output         : in out Ada.Strings.Unbounded.Unbounded_String;
      Maximum_Length : Natural;
      Status         : out Replacement_Status);

private
   type Compiled_Pattern is record
      Expression : Regexp.Regexp;
      Match      : Regexp.Match_Options := (Case_Sensitive => True, others => <>);
      Capture_Offset : Natural := 0;
      Valid      : Boolean := False;
   end record;

   type Match_Cursor is record
      Engine : Regexp.Match_Cursor;
   end record;
end Posix_Tools.Commands.Rg.Patterns;
