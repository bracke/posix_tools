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

   --  Why an operand was refused; Subject is the operand, or the name of
   --  the one whose value is missing.
   type Operand_Error_Kind is
     (No_Error,
      Invalid_Block_Size,
      Invalid_Conversion,
      Invalid_Count,
      Invalid_File_Count,
      Invalid_Operand,
      Invalid_Seek,
      Invalid_Skip);

   type Operand_Error is record
      Kind    : Operand_Error_Kind := No_Error;
      Subject : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Parse_Argument
     (Argument : String;
      Options  : in out Settings;
      Error    : out Operand_Error) return Boolean;

   function Validate
     (Options : Settings;
      Error   : out Operand_Error) return Boolean;
end Posix_Tools.Text.DD_Operands;
