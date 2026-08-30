package body Posix_Tools.Text.DD_Conversions
  with SPARK_Mode => On
is
   function Invalid_Conversions return Parsed_Conversions;

   function Parse_Factor (Factor : String) return Posix_Tools.Numbers.Parse_Result;

   function Safe_Product
     (Left  : Posix_Tools.Numbers.Count;
      Right : Posix_Tools.Numbers.Count) return Posix_Tools.Numbers.Count
     with
       Pre => Left = 0 or else Right <= Posix_Tools.Numbers.Count'Last / Left;

   function Safe_Product
     (Left  : Posix_Tools.Numbers.Count;
      Right : Posix_Tools.Numbers.Count) return Posix_Tools.Numbers.Count is
   begin
      return Left * Right;
   end Safe_Product;

   function Invalid_Conversions return Parsed_Conversions is
   begin
      return (Valid => False,
              Case_Conversion => No_Case_Conversion,
              Block_Conversion => No_Block_Conversion,
              Character_Set_Conversion => No_Character_Set_Conversion,
              Swap_Adjacent_Bytes => False,
              Sync_Conversion => False,
              No_Truncate_Output => False,
              Continue_After_Read_Error => False);
   end Invalid_Conversions;

   function Parse_Conversions (Value : String) return Parsed_Conversions is
   begin
      if Value = "" or else Value (Value'Last) = ',' then
         return Invalid_Conversions;
      end if;

      declare
         Start  : Positive := Value'First;
         Stop   : Positive;
         Parsed : Parsed_Conversions := Invalid_Conversions;
      begin
         Parsed.Valid := True;

         loop
            pragma Loop_Invariant (Start in Value'Range);
            pragma Loop_Variant (Decreases => Value'Last - Start);

            Stop := Start;
            while Stop < Value'Last and then Value (Stop) /= ',' loop
               pragma Loop_Invariant (Stop in Start .. Value'Last);
               pragma Loop_Variant (Decreases => Value'Last - Stop);

               Stop := Stop + 1;
            end loop;

            if Stop = Start and then Value (Stop) = ',' then
               return Invalid_Conversions;
            end if;

            declare
               Token_Last : constant Natural :=
                 (if Value (Stop) = ',' then Stop - 1 else Stop);
               Token      : constant String := Value (Start .. Token_Last);
            begin
               if Token = "ucase" then
                  Parsed.Case_Conversion := Uppercase_Conversion;
               elsif Token = "lcase" then
                  Parsed.Case_Conversion := Lowercase_Conversion;
               elsif Token = "swab" then
                  Parsed.Swap_Adjacent_Bytes := True;
               elsif Token = "sync" then
                  Parsed.Sync_Conversion := True;
               elsif Token = "notrunc" then
                  Parsed.No_Truncate_Output := True;
               elsif Token = "noerror" then
                  Parsed.Continue_After_Read_Error := True;
               elsif Token = "block" then
                  Parsed.Block_Conversion := Block_Conversion;
               elsif Token = "unblock" then
                  Parsed.Block_Conversion := Unblock_Conversion;
               elsif Token = "ascii" then
                  Parsed.Character_Set_Conversion := To_Ascii_Conversion;
               elsif Token = "ebcdic" or else Token = "ibm" then
                  Parsed.Character_Set_Conversion := To_Ebcdic_Conversion;
               else
                  return Invalid_Conversions;
               end if;
            end;

            if Stop = Value'Last then
               return Parsed;
            end if;

            Start := Stop + 1;
         end loop;
      end;
   end Parse_Conversions;

   function Parse_Factor (Factor : String) return Posix_Tools.Numbers.Parse_Result is
      Multiplier : Posix_Tools.Numbers.Count := 1;
      Last       : Natural := Factor'Last;
      Parsed     : Posix_Tools.Numbers.Parse_Result;
   begin
      if Factor'Length = 0 then
         return (Status => Posix_Tools.Numbers.Empty, Value => 0);
      elsif Factor (Factor'Last) = 'c' then
         Multiplier := 1;
         Last := Factor'Last - 1;
      elsif Factor (Factor'Last) = 'b' then
         Multiplier := 512;
         Last := Factor'Last - 1;
      elsif Factor (Factor'Last) = 'k' then
         Multiplier := 1_024;
         Last := Factor'Last - 1;
      elsif Factor (Factor'Last) = 'K' then
         Multiplier := 1_024;
         Last := Factor'Last - 1;
      elsif Factor (Factor'Last) = 'M' then
         Multiplier := 1_024 * 1_024;
         Last := Factor'Last - 1;
      elsif Factor (Factor'Last) = 'G' then
         Multiplier := 1_024 * 1_024 * 1_024;
         Last := Factor'Last - 1;
      elsif Factor (Factor'Last) = 'w' then
         Multiplier := 2;
         Last := Factor'Last - 1;
      end if;

      if Last < Factor'First then
         return (Status => Posix_Tools.Numbers.Empty, Value => 0);
      end if;

      Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Factor (Factor'First .. Last));
      if Parsed.Status /= Posix_Tools.Numbers.Valid then
         return Parsed;
      elsif Parsed.Value > Posix_Tools.Numbers.Count'Last / Multiplier then
         return (Status => Posix_Tools.Numbers.Overflow, Value => 0);
      else
         return
           (Status => Posix_Tools.Numbers.Valid,
            Value  => Parsed.Value * Multiplier);
      end if;
   end Parse_Factor;

   function Parse_Nonnegative (Value : String) return Posix_Tools.Numbers.Parse_Result is
   begin
      if Value'Length = 0 then
         return (Status => Posix_Tools.Numbers.Empty, Value => 0);
      end if;

      declare
         Start   : Positive := Value'First;
         Stop    : Positive;
         Product : Posix_Tools.Numbers.Count := 1;
      begin
         loop
            pragma Loop_Invariant (Start in Value'Range);
            pragma Loop_Variant (Decreases => Value'Last - Start);

            Stop := Start;
            while Stop < Value'Last and then Value (Stop) /= 'x' loop
               pragma Loop_Invariant (Stop in Start .. Value'Last);
               pragma Loop_Variant (Decreases => Value'Last - Stop);

               Stop := Stop + 1;
            end loop;

            declare
               Token_Last : constant Natural :=
                 (if Value (Stop) = 'x' then Stop - 1 else Stop);
            begin
               if Token_Last < Start then
                  return (Status => Posix_Tools.Numbers.Empty, Value => 0);
               end if;

               declare
                  Parsed : constant Posix_Tools.Numbers.Parse_Result :=
                    Parse_Factor (Value (Start .. Token_Last));
               begin
                  if Parsed.Status /= Posix_Tools.Numbers.Valid then
                     return Parsed;
                  elsif Parsed.Value = 0 then
                     Product := 0;
                  elsif Product = 0 then
                     null;
                  elsif Parsed.Value > Posix_Tools.Numbers.Count'Last / Product
                  then
                     return (Status => Posix_Tools.Numbers.Overflow, Value => 0);
                  else
                     pragma Assert (Product > 0);
                     pragma Assert (Parsed.Value > 0);
                     pragma Assert (Parsed.Value <= Posix_Tools.Numbers.Count'Last / Product);
                     Product := Safe_Product (Product, Parsed.Value);
                  end if;
               end;
            end;

            if Stop = Value'Last then
               if Value (Stop) = 'x' then
                  return (Status => Posix_Tools.Numbers.Empty, Value => 0);
               else
                  return (Status => Posix_Tools.Numbers.Valid, Value => Product);
               end if;
            end if;

            Start := Stop + 1;
         end loop;
      end;
   end Parse_Nonnegative;
end Posix_Tools.Text.DD_Conversions;
