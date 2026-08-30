with Posix_Tools.Text.DD_Conversions;

package body Posix_Tools.Text.DD_Operands is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Numbers.Count;
   use type Posix_Tools.Numbers.Parse_Status;
   use type Posix_Tools.Text.DD_Conversions.Block_Conversion_Kind;
   use type Posix_Tools.Text.DD_Conversions.Case_Conversion_Kind;
   use type Posix_Tools.Text.DD_Conversions.Character_Set_Conversion_Kind;

   function Parse_Count_Operand
     (Argument   : String;
      Prefix_End : Positive) return Posix_Tools.Numbers.Parse_Result
   is
   begin
      return
        (if Argument'Length = Prefix_End
         then (Status => Posix_Tools.Numbers.Empty, Value => 0)
         else Posix_Tools.Text.DD_Conversions.Parse_Nonnegative
           (Argument (Argument'First + Prefix_End .. Argument'Last)));
   end Parse_Count_Operand;

   function Parse_Conversions
     (Value   : String;
      Options : in out Settings) return Boolean
   is
      Parsed : constant Posix_Tools.Text.DD_Conversions.Parsed_Conversions :=
        Posix_Tools.Text.DD_Conversions.Parse_Conversions (Value);
   begin
      if not Parsed.Valid then
         return False;
      end if;

      if Parsed.Case_Conversion /= Posix_Tools.Text.DD_Conversions.No_Case_Conversion then
         Options.Conversion_Settings.Case_Conversion := Parsed.Case_Conversion;
      end if;
      if Parsed.Block_Conversion /= Posix_Tools.Text.DD_Conversions.No_Block_Conversion then
         Options.Conversion_Settings.Block_Conversion := Parsed.Block_Conversion;
      end if;
      if Parsed.Character_Set_Conversion /=
        Posix_Tools.Text.DD_Conversions.No_Character_Set_Conversion
      then
         Options.Conversion_Settings.Character_Set_Conversion := Parsed.Character_Set_Conversion;
      end if;

      Options.Conversion_Settings.Swap_Adjacent_Bytes :=
        Options.Conversion_Settings.Swap_Adjacent_Bytes or else Parsed.Swap_Adjacent_Bytes;
      Options.Conversion_Settings.Sync_Conversion :=
        Options.Conversion_Settings.Sync_Conversion or else Parsed.Sync_Conversion;
      Options.No_Truncate_Output :=
        Options.No_Truncate_Output or else Parsed.No_Truncate_Output;
      Options.Continue_After_Read_Error :=
        Options.Continue_After_Read_Error or else Parsed.Continue_After_Read_Error;
      return True;
   end Parse_Conversions;

   procedure Set_Invalid
     (Error : out Unbounded_String;
      Text  : String)
   is
   begin
      Error := To_Unbounded_String (Text);
   end Set_Invalid;

   function Parse_Argument
     (Argument : String;
      Options  : in out Settings;
      Error    : out Unbounded_String) return Boolean
   is
   begin
      Error := Null_Unbounded_String;

      if Argument'Length > 3
        and then Argument (Argument'First .. Argument'First + 2) = "if="
      then
         Options.Input := To_Unbounded_String (Argument (Argument'First + 3 .. Argument'Last));
      elsif Argument'Length > 3
        and then Argument (Argument'First .. Argument'First + 2) = "of="
      then
         Options.Output := To_Unbounded_String (Argument (Argument'First + 3 .. Argument'Last));
      elsif Argument'Length >= 6
        and then Argument (Argument'First .. Argument'First + 5) = "count="
      then
         declare
            Parsed : constant Posix_Tools.Numbers.Parse_Result :=
              Parse_Count_Operand (Argument, 6);
         begin
            if Parsed.Status /= Posix_Tools.Numbers.Valid then
               Set_Invalid (Error, "invalid count '" & Argument & "'");
               return False;
            end if;
            Options.Count := Parsed.Value;
         end;
      elsif Argument'Length >= 6
        and then Argument (Argument'First .. Argument'First + 5) = "files="
      then
         declare
            Parsed : constant Posix_Tools.Numbers.Parse_Result :=
              Parse_Count_Operand (Argument, 6);
         begin
            if Parsed.Status /= Posix_Tools.Numbers.Valid or else Parsed.Value = 0 then
               Set_Invalid (Error, "invalid file count '" & Argument & "'");
               return False;
            end if;
            Options.Input_File_Count := Parsed.Value;
         end;
      elsif Argument'Length >= 5
        and then Argument (Argument'First .. Argument'First + 4) = "skip="
      then
         declare
            Parsed : constant Posix_Tools.Numbers.Parse_Result :=
              Parse_Count_Operand (Argument, 5);
         begin
            if Parsed.Status /= Posix_Tools.Numbers.Valid then
               Set_Invalid (Error, "invalid skip '" & Argument & "'");
               return False;
            end if;
            Options.Skip_Blocks := Parsed.Value;
         end;
      elsif Argument'Length >= 6
        and then Argument (Argument'First .. Argument'First + 5) = "iseek="
      then
         declare
            Parsed : constant Posix_Tools.Numbers.Parse_Result :=
              Parse_Count_Operand (Argument, 6);
         begin
            if Parsed.Status /= Posix_Tools.Numbers.Valid then
               Set_Invalid (Error, "invalid skip '" & Argument & "'");
               return False;
            end if;
            Options.Skip_Blocks := Parsed.Value;
         end;
      elsif Argument'Length >= 5
        and then Argument (Argument'First .. Argument'First + 4) = "seek="
      then
         declare
            Parsed : constant Posix_Tools.Numbers.Parse_Result :=
              Parse_Count_Operand (Argument, 5);
         begin
            if Parsed.Status /= Posix_Tools.Numbers.Valid then
               Set_Invalid (Error, "invalid seek '" & Argument & "'");
               return False;
            end if;
            Options.Seek_Blocks := Parsed.Value;
         end;
      elsif Argument'Length >= 6
        and then Argument (Argument'First .. Argument'First + 5) = "oseek="
      then
         declare
            Parsed : constant Posix_Tools.Numbers.Parse_Result :=
              Parse_Count_Operand (Argument, 6);
         begin
            if Parsed.Status /= Posix_Tools.Numbers.Valid then
               Set_Invalid (Error, "invalid seek '" & Argument & "'");
               return False;
            end if;
            Options.Seek_Blocks := Parsed.Value;
         end;
      elsif Argument'Length >= 4
        and then Argument (Argument'First .. Argument'First + 3) = "ibs="
      then
         declare
            Parsed : constant Posix_Tools.Numbers.Parse_Result :=
              Parse_Count_Operand (Argument, 4);
         begin
            if Parsed.Status /= Posix_Tools.Numbers.Valid or else Parsed.Value = 0 then
               Set_Invalid (Error, "invalid block size '" & Argument & "'");
               return False;
            end if;
            Options.Input_Block_Size := Parsed.Value;
            Options.Conversion_Settings.Input_Block_Size := Parsed.Value;
         end;
      elsif Argument'Length >= 4
        and then Argument (Argument'First .. Argument'First + 3) = "obs="
      then
         declare
            Parsed : constant Posix_Tools.Numbers.Parse_Result :=
              Parse_Count_Operand (Argument, 4);
         begin
            if Parsed.Status /= Posix_Tools.Numbers.Valid or else Parsed.Value = 0 then
               Set_Invalid (Error, "invalid block size '" & Argument & "'");
               return False;
            end if;
            Options.Output_Block_Size := Parsed.Value;
         end;
      elsif Argument'Length >= 4
        and then Argument (Argument'First .. Argument'First + 3) = "cbs="
      then
         declare
            Parsed : constant Posix_Tools.Numbers.Parse_Result :=
              Parse_Count_Operand (Argument, 4);
         begin
            if Parsed.Status /= Posix_Tools.Numbers.Valid or else Parsed.Value = 0 then
               Set_Invalid (Error, "invalid block size '" & Argument & "'");
               return False;
            end if;
            Options.Conversion_Settings.Conversion_Block_Size := Parsed.Value;
         end;
      elsif Argument'Length >= 3
        and then Argument (Argument'First .. Argument'First + 2) = "bs="
      then
         declare
            Parsed : constant Posix_Tools.Numbers.Parse_Result :=
              Parse_Count_Operand (Argument, 3);
         begin
            if Parsed.Status /= Posix_Tools.Numbers.Valid or else Parsed.Value = 0 then
               Set_Invalid (Error, "invalid block size '" & Argument & "'");
               return False;
            end if;
            Options.Input_Block_Size := Parsed.Value;
            Options.Conversion_Settings.Input_Block_Size := Parsed.Value;
            Options.Output_Block_Size := Parsed.Value;
         end;
      elsif Argument'Length >= 5
        and then Argument (Argument'First .. Argument'First + 4) = "conv="
      then
         if Argument'Length = 5
           or else not Parse_Conversions (Argument (Argument'First + 5 .. Argument'Last), Options)
         then
            Set_Invalid (Error, "invalid conversion '" & Argument & "'");
            return False;
         end if;
      else
         Set_Invalid (Error, "invalid operand '" & Argument & "'");
         return False;
      end if;

      return True;
   end Parse_Argument;

   function Validate
     (Options : Settings;
      Error   : out Unbounded_String) return Boolean
   is
   begin
      Error := Null_Unbounded_String;

      if Options.Conversion_Settings.Block_Conversion /=
           Posix_Tools.Text.DD_Conversions.No_Block_Conversion
        and then (Options.Conversion_Settings.Conversion_Block_Size = 0
                  or else Options.Conversion_Settings.Conversion_Block_Size >
                    Posix_Tools.Numbers.Count (Natural'Last))
      then
         Set_Invalid (Error, "invalid block size 'cbs'");
         return False;
      end if;

      if Options.Conversion_Settings.Character_Set_Conversion /=
           Posix_Tools.Text.DD_Conversions.No_Character_Set_Conversion
        and then (Options.Conversion_Settings.Conversion_Block_Size = 0
                  or else Options.Conversion_Settings.Conversion_Block_Size >
                    Posix_Tools.Numbers.Count (Natural'Last))
      then
         Set_Invalid (Error, "invalid block size 'cbs'");
         return False;
      end if;

      if Options.Input_File_Count = 0 then
         Set_Invalid (Error, "invalid file count 'files'");
         return False;
      end if;

      return True;
   end Validate;
end Posix_Tools.Text.DD_Operands;
