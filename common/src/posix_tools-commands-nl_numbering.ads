with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Text.NL_Fields;

package Posix_Tools.Commands.Nl_Numbering is
   type Numbering_State is record
      Header_Mode : Posix_Tools.Text.NL_Fields.Number_Mode :=
        Posix_Tools.Text.NL_Fields.No_Lines;
      Body_Mode : Posix_Tools.Text.NL_Fields.Number_Mode :=
        Posix_Tools.Text.NL_Fields.Nonempty_Lines;
      Footer_Mode : Posix_Tools.Text.NL_Fields.Number_Mode :=
        Posix_Tools.Text.NL_Fields.No_Lines;
      Section : Posix_Tools.Text.NL_Fields.Logical_Section :=
        Posix_Tools.Text.NL_Fields.Body_Section;
      Increment : Long_Long_Integer := 1;
      Separator : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.To_Unbounded_String ("" & Character'Val (9));
      Value         : Long_Long_Integer := 1;
      Initial_Value : Long_Long_Integer := 1;
      Width         : Natural := 6;
      Delimiter     : String (1 .. 2) := [1 => Character'Val (16#5C#), 2 => ':'];
      No_Restart    : Boolean := False;
   end record;

   procedure Number_File
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      State   : in out Numbering_State;
      Name    : String;
      Ok      : out Boolean);
end Posix_Tools.Commands.Nl_Numbering;
