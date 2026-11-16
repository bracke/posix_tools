with Ada.Strings.Unbounded;
with Posix_Tools.Numbers;
with Posix_Tools.Text.DD_Conversions;

package Posix_Tools.Text.DD_Conversion_Engine is
   type Conversion_Settings is record
      Input_Block_Size        : Posix_Tools.Numbers.Count := 512;
      Conversion_Block_Size   : Posix_Tools.Numbers.Count := 0;
      Case_Conversion         : Posix_Tools.Text.DD_Conversions.Case_Conversion_Kind :=
        Posix_Tools.Text.DD_Conversions.No_Case_Conversion;
      Block_Conversion        : Posix_Tools.Text.DD_Conversions.Block_Conversion_Kind :=
        Posix_Tools.Text.DD_Conversions.No_Block_Conversion;
      Character_Set_Conversion :
        Posix_Tools.Text.DD_Conversions.Character_Set_Conversion_Kind :=
          Posix_Tools.Text.DD_Conversions.No_Character_Set_Conversion;
      Swap_Adjacent_Bytes     : Boolean := False;
      Sync_Conversion         : Boolean := False;
   end record;

   type Conversion_Result is record
      Output            : Ada.Strings.Unbounded.Unbounded_String;
      Truncated_Records : Posix_Tools.Numbers.Count := 0;
   end record;

   function Apply
     (Value    : String;
      Settings : Conversion_Settings) return Conversion_Result;

   type Stream_Converter is private;

   procedure Initialize
     (State    : out Stream_Converter;
      Settings : Conversion_Settings);

   procedure Update
     (State  : in out Stream_Converter;
      Input  : String;
      Output : out Ada.Strings.Unbounded.Unbounded_String);

   procedure Finish
     (State             : in out Stream_Converter;
      Output            : out Ada.Strings.Unbounded.Unbounded_String;
      Truncated_Records : out Posix_Tools.Numbers.Count);

private
   type Stream_Converter is record
      Settings          : Conversion_Settings;
      Effective_Block   : Posix_Tools.Text.DD_Conversions.Block_Conversion_Kind :=
        Posix_Tools.Text.DD_Conversions.No_Block_Conversion;
      Block_Data        : Ada.Strings.Unbounded.Unbounded_String;
      Input_Remainder   : Posix_Tools.Numbers.Count := 0;
      Record_Open       : Boolean := False;
      Record_Truncated  : Boolean := False;
      Has_Swab_Byte     : Boolean := False;
      Swab_Byte         : Character := Character'Val (0);
      Truncated_Records : Posix_Tools.Numbers.Count := 0;
   end record;
end Posix_Tools.Text.DD_Conversion_Engine;
