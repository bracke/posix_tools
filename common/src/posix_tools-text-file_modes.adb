with Posix_Tools.Text.Byte_Classes;

package body Posix_Tools.Text.File_Modes
  with SPARK_Mode => On
is
   function Apply_Symbolic_Mode
     (Text : String;
      Base : Natural) return Symbolic_Mode_Result is
   begin
      if Text = "" then
         return (Valid => False, Mode => Base);
      end if;

      declare
         Result_Mode : Natural := Base;
         Index       : Positive := Text'First;
      begin
         for Step in Text'Range loop
            pragma Unreferenced (Step);
            pragma Loop_Invariant
              (Result_Mode <= 8#7777#
               and then Index in Text'First .. Text'Last + 1);

            exit when Index > Text'Last;

            declare
               Who_Mask : Natural := 0;
               Perms    : Natural := 0;
               Op       : Character := Character'Val (0);
            begin
               while Index <= Text'Last and then Text (Index) in 'a' | 'u' | 'g' | 'o' loop
                  pragma Loop_Invariant
                    (Result_Mode <= 8#7777#
                     and then Who_Mask <= 8#7777#
                     and then Index in Text'First .. Text'Last + 1);
                  pragma Loop_Variant (Decreases => Text'Last - Index + 1);

                  Who_Mask := Symbolic_Who_Mask (Who_Mask, Text (Index));
                  Index := Index + 1;
               end loop;

               if Who_Mask = 0 then
                  Who_Mask := 8#7777#;
               end if;
               if Index > Text'Last or else Text (Index) not in '+' | '-' | '=' then
                  return (Valid => False, Mode => Base);
               end if;

               Op := Text (Index);
               Index := Index + 1;
               if (Index > Text'Last or else Text (Index) = ',') and then Op /= '=' then
                  return (Valid => False, Mode => Base);
               end if;

               while Index <= Text'Last and then Text (Index) /= ',' loop
                  pragma Loop_Invariant
                    (Result_Mode <= 8#7777#
                     and then Who_Mask <= 8#7777#
                     and then Perms <= 8#7777#
                     and then Index in Text'First .. Text'Last + 1);
                  pragma Loop_Variant (Decreases => Text'Last - Index + 1);

                  declare
                     Parsed : constant Symbolic_Permission_Bits_Result :=
                       Symbolic_Permission_Bits
                         (Who_Mask, Result_Mode, Text (Index));
                  begin
                     if not Parsed.Valid then
                        return (Valid => False, Mode => Base);
                     end if;
                     Perms := Set_Mode_Mask (Perms, Parsed.Bits);
                  end;
                  Index := Index + 1;
               end loop;

               declare
                  Applied : constant Symbolic_Permission_Operation_Result :=
                    Apply_Symbolic_Permission_Operation
                      (Result_Mode, Who_Mask, Perms, Op);
               begin
                  if not Applied.Valid then
                     return (Valid => False, Mode => Base);
                  end if;
                  Result_Mode := Applied.Mode;
               end;

               if Index <= Text'Last then
                  if Text (Index) /= ',' or else Index = Text'Last then
                     return (Valid => False, Mode => Base);
                  end if;
                  Index := Index + 1;
               end if;
            end;
         end loop;

         if Index <= Text'Last then
            return (Valid => False, Mode => Base);
         else
            return (Valid => True, Mode => Result_Mode);
         end if;
      end;
   end Apply_Symbolic_Mode;

   function Apply_Symbolic_Permission_Operation
     (Current_Mode, Who_Mask, Permission_Mask : Natural;
      Operation : Character) return Symbolic_Permission_Operation_Result is
      Result : Natural := Current_Mode;
   begin
      case Operation is
         when '+' =>
            Result := Set_Mode_Mask (Result, Permission_Mask);
         when '-' =>
            Result := Clear_Mode_Mask (Result, Permission_Mask);
         when '=' =>
            Result := Clear_Mode_Mask (Result, Who_Mask);
            Result := Set_Mode_Mask (Result, Permission_Mask);
         when others =>
            return (Valid => False, Mode => Current_Mode);
      end case;

      return (Valid => True, Mode => Result);
   end Apply_Symbolic_Permission_Operation;

   function Clear_Mode_Bit (Value : Natural; Bit : Mode_Bit) return Natural is
   begin
      if Has_Mode_Bit (Value, Bit) then
         return Value - Bit;
      else
         return Value;
      end if;
   end Clear_Mode_Bit;

   function Clear_Mode_Mask (Value, Mask : Natural) return Natural is
      Result : Natural := Value;
      Bit    : Mode_Bit := 8#001#;
   begin
      while Bit <= 8#4000# loop
         pragma Loop_Invariant (Result <= Value);
         pragma Loop_Variant (Increases => Bit);

         if Has_Mode_Bit (Mask, Bit) then
            Result := Clear_Mode_Bit (Result, Bit);
         end if;

         exit when Bit = 8#4000#;
         Bit := Bit * 2;
      end loop;

      return Result;
   end Clear_Mode_Mask;

   function Four_Digit_Octal_Image (Value : Natural) return String is
      Result : String (1 .. 4) := [others => '0'];
      Work   : Natural := Value mod 8#10000#;
   begin
      for Index in reverse Result'Range loop
         pragma Loop_Invariant
           (Work <= 8#7777#
            and then
              (for all I in Index + 1 .. Result'Last =>
                 Result (I) in '0' .. '7'));

         Result (Index) :=
           Posix_Tools.Text.Byte_Classes.ASCII_Octal_Digit_Character
             (Posix_Tools.Text.Byte_Classes.ASCII_Octal_Value (Work mod 8));
         Work := Work / 8;
      end loop;

      return Result;
   end Four_Digit_Octal_Image;

   function Has_All_Mode_Bits (Mode, Mask : Natural) return Boolean is
      Bit : Positive := 1;
   begin
      while Bit <= 8#4000# loop
         pragma Loop_Variant (Increases => Bit);

         if Has_Mode_Bit (Mask, Bit) and then not Has_Mode_Bit (Mode, Bit) then
            return False;
         end if;

         Bit := Bit * 2;
      end loop;

      return True;
   end Has_All_Mode_Bits;

   function Has_Any_Mode_Bit (Mode, Mask : Natural) return Boolean is
      Bit : Positive := 1;
   begin
      while Bit <= 8#4000# loop
         pragma Loop_Variant (Increases => Bit);

         if Has_Mode_Bit (Mask, Bit) and then Has_Mode_Bit (Mode, Bit) then
            return True;
         end if;

         Bit := Bit * 2;
      end loop;

      return False;
   end Has_Any_Mode_Bit;

   function Has_Mode_Bit (Value : Natural; Bit : Positive) return Boolean is
     ((Value / Bit) mod 2 = 1);

   function Parse_Find_Permission_Mode (Text : String) return Parsed_Permission_Mode is
      Parsed : constant Parsed_Permission_Mode := Parse_Permission_Mode (Text);
   begin
      case Parsed.Status is
         when Invalid_Permission_Mode | Octal_Permission_Mode =>
            return Parsed;
         when Symbolic_Permission_Mode =>
            if Parsed.Match_All then
               if Text'First = Text'Last then
                  return
                    (Status    => Invalid_Permission_Mode,
                     Mode      => 0,
                     Match_All => Parsed.Match_All);
               else
                  pragma Assert (Text'First < Positive'Last);
                  declare
                     Applied : constant Symbolic_Mode_Result :=
                       Apply_Symbolic_Mode (Text (Text'First + 1 .. Text'Last), 0);
                  begin
                     if Applied.Valid then
                        return
                          (Status    => Symbolic_Permission_Mode,
                           Mode      => Applied.Mode,
                           Match_All => Parsed.Match_All);
                     else
                        return
                          (Status    => Invalid_Permission_Mode,
                           Mode      => 0,
                           Match_All => Parsed.Match_All);
                     end if;
                  end;
               end if;
            else
               declare
                  Applied : constant Symbolic_Mode_Result := Apply_Symbolic_Mode (Text, 0);
               begin
                  if Applied.Valid then
                     return
                       (Status    => Symbolic_Permission_Mode,
                        Mode      => Applied.Mode,
                        Match_All => Parsed.Match_All);
                  else
                     return
                       (Status    => Invalid_Permission_Mode,
                        Mode      => 0,
                        Match_All => Parsed.Match_All);
                  end if;
               end;
            end if;
      end case;
   end Parse_Find_Permission_Mode;

   function Parse_Permission_Mode (Text : String) return Parsed_Permission_Mode is
   begin
      if Text = "" then
         return
           (Status => Invalid_Permission_Mode,
            Mode => 0,
            Match_All => False);
      end if;

      declare
         First     : Positive := Text'First;
         Mode      : Natural := 0;
         Match_All : Boolean := False;
         All_Octal : Boolean := True;
      begin
         if Text (First) = '-' then
            Match_All := True;
            if First = Text'Last then
               return
                 (Status => Invalid_Permission_Mode,
                  Mode => 0,
                  Match_All => Match_All);
            end if;
            First := First + 1;
         end if;

         for I in First .. Text'Last loop
            pragma Loop_Invariant (All_Octal = (for all J in First .. I - 1 =>
              Posix_Tools.Text.Byte_Classes.Is_ASCII_Octal_Digit (Text (J))));

            if not Posix_Tools.Text.Byte_Classes.Is_ASCII_Octal_Digit (Text (I)) then
               All_Octal := False;
               exit;
            end if;
         end loop;

         if not All_Octal then
            return
              (Status => Symbolic_Permission_Mode,
               Mode => 0,
               Match_All => Match_All);
         end if;

         for I in First .. Text'Last loop
            pragma Loop_Invariant (Mode <= 8#7777#);

            Mode :=
              Mode * 8
              + Posix_Tools.Text.Byte_Classes.ASCII_Octal_Digit_Value (Text (I));
            if Mode > 8#7777# then
               return
                 (Status => Invalid_Permission_Mode,
                  Mode => 0,
                  Match_All => Match_All);
            end if;
         end loop;

         return
           (Status => Octal_Permission_Mode,
            Mode => Mode,
            Match_All => Match_All);
      end;
   end Parse_Permission_Mode;

   function Permission_Matches
     (Actual, Expected : Natural;
      Match_All : Boolean) return Boolean is
   begin
      if Match_All then
         return Has_All_Mode_Bits (Actual, Expected);
      else
         return Actual = Expected;
      end if;
   end Permission_Matches;

   function Set_Mode_Bit (Value : Natural; Bit : Mode_Bit) return Natural is
   begin
      if Has_Mode_Bit (Value, Bit) then
         return Value;
      else
         return Value + Bit;
      end if;
   end Set_Mode_Bit;

   function Set_Mode_Mask (Value, Mask : Natural) return Natural is
      Result : Natural := Value;
      Bit    : Mode_Bit := 8#001#;
   begin
      while Bit <= 8#4000# loop
         pragma Loop_Invariant (Result <= 8#7777#);
         pragma Loop_Variant (Increases => Bit);

         if Has_Mode_Bit (Mask, Bit) then
            Result := Set_Mode_Bit (Result, Bit);
         end if;

         exit when Bit = 8#4000#;
         Bit := Bit * 2;
      end loop;

      return Result;
   end Set_Mode_Mask;

   function Symbolic_Permission_Bits
     (Who_Mask, Source_Mode : Natural;
      Permission : Character) return Symbolic_Permission_Bits_Result is
      Result : Natural := 0;
   begin
      case Permission is
         when 'r' =>
            if Has_Mode_Bit (Who_Mask, 8#400#) then
               Result := Set_Mode_Bit (Result, 8#400#);
            end if;
            if Has_Mode_Bit (Who_Mask, 8#040#) then
               Result := Set_Mode_Bit (Result, 8#040#);
            end if;
            if Has_Mode_Bit (Who_Mask, 8#004#) then
               Result := Set_Mode_Bit (Result, 8#004#);
            end if;
         when 'w' =>
            if Has_Mode_Bit (Who_Mask, 8#200#) then
               Result := Set_Mode_Bit (Result, 8#200#);
            end if;
            if Has_Mode_Bit (Who_Mask, 8#020#) then
               Result := Set_Mode_Bit (Result, 8#020#);
            end if;
            if Has_Mode_Bit (Who_Mask, 8#002#) then
               Result := Set_Mode_Bit (Result, 8#002#);
            end if;
         when 'x' | 'X' =>
            if Has_Mode_Bit (Who_Mask, 8#100#) then
               Result := Set_Mode_Bit (Result, 8#100#);
            end if;
            if Has_Mode_Bit (Who_Mask, 8#010#) then
               Result := Set_Mode_Bit (Result, 8#010#);
            end if;
            if Has_Mode_Bit (Who_Mask, 8#001#) then
               Result := Set_Mode_Bit (Result, 8#001#);
            end if;
         when 's' =>
            if Has_Mode_Bit (Who_Mask, 8#4000#) then
               Result := Set_Mode_Bit (Result, 8#4000#);
            end if;
            if Has_Mode_Bit (Who_Mask, 8#2000#) then
               Result := Set_Mode_Bit (Result, 8#2000#);
            end if;
         when 't' =>
            if Has_Mode_Bit (Who_Mask, 8#1000#) then
               Result := Set_Mode_Bit (Result, 8#1000#);
            end if;
         when 'u' | 'g' | 'o' =>
            declare
               Source_Read : constant Boolean :=
                 Has_Mode_Bit
                   (Source_Mode,
                    (case Permission is
                        when 'u' => 8#400#,
                        when 'g' => 8#040#,
                        when others => 8#004#));
               Source_Write : constant Boolean :=
                 Has_Mode_Bit
                   (Source_Mode,
                    (case Permission is
                        when 'u' => 8#200#,
                        when 'g' => 8#020#,
                        when others => 8#002#));
               Source_Exec : constant Boolean :=
                 Has_Mode_Bit
                   (Source_Mode,
                    (case Permission is
                        when 'u' => 8#100#,
                        when 'g' => 8#010#,
                        when others => 8#001#));
            begin
               if Source_Read then
                  if Has_Mode_Bit (Who_Mask, 8#400#) then
                     Result := Set_Mode_Bit (Result, 8#400#);
                  end if;
                  if Has_Mode_Bit (Who_Mask, 8#040#) then
                     Result := Set_Mode_Bit (Result, 8#040#);
                  end if;
                  if Has_Mode_Bit (Who_Mask, 8#004#) then
                     Result := Set_Mode_Bit (Result, 8#004#);
                  end if;
               end if;
               if Source_Write then
                  if Has_Mode_Bit (Who_Mask, 8#200#) then
                     Result := Set_Mode_Bit (Result, 8#200#);
                  end if;
                  if Has_Mode_Bit (Who_Mask, 8#020#) then
                     Result := Set_Mode_Bit (Result, 8#020#);
                  end if;
                  if Has_Mode_Bit (Who_Mask, 8#002#) then
                     Result := Set_Mode_Bit (Result, 8#002#);
                  end if;
               end if;
               if Source_Exec then
                  if Has_Mode_Bit (Who_Mask, 8#100#) then
                     Result := Set_Mode_Bit (Result, 8#100#);
                  end if;
                  if Has_Mode_Bit (Who_Mask, 8#010#) then
                     Result := Set_Mode_Bit (Result, 8#010#);
                  end if;
                  if Has_Mode_Bit (Who_Mask, 8#001#) then
                     Result := Set_Mode_Bit (Result, 8#001#);
                  end if;
               end if;
            end;
         when others =>
            return (Valid => False, Bits => 0);
      end case;

      return (Valid => True, Bits => Result);
   end Symbolic_Permission_Bits;

   function Symbolic_Who_Mask (Mask : Natural; Who : Character) return Natural is
   begin
      case Who is
         when 'a' =>
            return 8#7777#;
         when 'u' =>
            return
              Set_Mode_Bit
                (Set_Mode_Bit
                   (Set_Mode_Bit
                      (Set_Mode_Bit (Mask, 8#4000#), 8#400#),
                    8#200#),
                 8#100#);
         when 'g' =>
            return
              Set_Mode_Bit
                (Set_Mode_Bit
                   (Set_Mode_Bit
                      (Set_Mode_Bit (Mask, 8#2000#), 8#040#),
                    8#020#),
                 8#010#);
         when 'o' =>
            return
              Set_Mode_Bit
                (Set_Mode_Bit
                   (Set_Mode_Bit
                      (Set_Mode_Bit (Mask, 8#1000#), 8#004#),
                    8#002#),
                 8#001#);
         when others =>
            return Mask;
      end case;
   end Symbolic_Who_Mask;
end Posix_Tools.Text.File_Modes;
