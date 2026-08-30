with Ada.Strings.Unbounded;
with Posix_Tools.Numbers;
with Posix_Tools.Text.DD_Conversion_Engine;

package Posix_Tools.Text.DD_Operands is
   type Settings is record
      Input                     : Ada.Strings.Unbounded.Unbounded_String;
      Output                    : Ada.Strings.Unbounded.Unbounded_String;
      Count                     : Posix_Tools.Numbers.Count := Posix_Tools.Numbers.Count'Last;
      Input_File_Count          : Posix_Tools.Numbers.Count := 1;
      Input_Block_Size          : Posix_Tools.Numbers.Count := 512;
      Output_Block_Size         : Posix_Tools.Numbers.Count := 512;
      Conversion_Settings       : Posix_Tools.Text.DD_Conversion_Engine.Conversion_Settings;
      Skip_Blocks               : Posix_Tools.Numbers.Count := 0;
      Seek_Blocks               : Posix_Tools.Numbers.Count := 0;
      No_Truncate_Output        : Boolean := False;
      Continue_After_Read_Error : Boolean := False;
   end record;

   function Parse_Argument
     (Argument : String;
      Options  : in out Settings;
      Error    : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;

   function Validate
     (Options : Settings;
      Error   : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
end Posix_Tools.Text.DD_Operands;
