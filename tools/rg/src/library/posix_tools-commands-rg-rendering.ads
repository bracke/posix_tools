with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Rg.Colors;

--  Deterministic non-colour selected-line rendering.
package Posix_Tools.Commands.Rg.Rendering is
   type Color_Mode is (Color_Automatic, Color_Always, Color_Never);

   type Result_Mode is
     (Matching_Lines,
      Quiet,
      Count_Lines,
      Count_Matches,
      Only_Matching,
      Files_With_Matches,
      Files_Without_Match);

   type Format is record
      Prefix_Name      : Boolean := False;
      Show_Line_Number : Boolean := False;
      Show_Column      : Boolean := False;
      Heading          : Boolean := False;
      Null_Pathnames   : Boolean := False;
      Record_Terminator : Character := ASCII.LF;
      Color             : Color_Mode := Color_Automatic;
      Destination_Is_Terminal : Boolean := False;
      Colors            : Posix_Tools.Commands.Rg.Colors.Palette :=
        Posix_Tools.Commands.Rg.Colors.Default_Palette;
   end record;

   function Highlight_Match (Text : String; Style : Format) return String;
   function Highlight_Text (Text : String; Style : Format) return String;

   procedure Put_Selected_Line
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Label       : String;
      Line        : Ada.Strings.Unbounded.Unbounded_String;
      Line_Number : Positive;
      Column      : Positive;
      Style       : Format;
      Count_Output : access procedure (Count : Natural) := null;
      Highlight    : Boolean := False;
      Logical_Length : Natural := Natural'Last);

   procedure Put_Context_Line
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Label       : String;
      Line        : Ada.Strings.Unbounded.Unbounded_String;
      Line_Number : Positive;
      Style       : Format;
      Count_Output : access procedure (Count : Natural) := null);

   procedure Put_Context_Separator
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      Separator : String;
      Terminator : Character;
      Count_Output : access procedure (Count : Natural) := null;
      Style        : Format := (others => <>));

   procedure Put_Count
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Label       : String;
      Count       : Natural;
      Style       : Format);

   procedure Put_Heading
     (Context      : in out Posix_Tools.Commands.Contexts.Context'Class;
      Label        : String;
      Style        : Format;
      Count_Output : access procedure (Count : Natural) := null);

   procedure Put_Path
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Label   : String;
      Terminator : Character := ASCII.LF;
      Style      : Format := (others => <>));
end Posix_Tools.Commands.Rg.Rendering;
