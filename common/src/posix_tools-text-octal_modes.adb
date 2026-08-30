with Posix_Tools.Text.Byte_Classes;

package body Posix_Tools.Text.Octal_Modes
  with SPARK_Mode => On
is
   function Parse_Mode (Text : String) return Parsed_Mode is
   begin
      if Valid_Mode (Text) then
         return (Valid => True, Value => Mode_Value (Text));
      else
         return (Valid => False, Value => 0);
      end if;
   end Parse_Mode;

   function Valid_Mode (Text : String) return Boolean
   is
      Processed : Natural := 0;
   begin
      if Text'Length = 0 or else Text'Length > 4 then
         return False;
      end if;

      while Processed < Text'Length loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Invariant (Text'Length <= 4);
         pragma Loop_Variant (Increases => Processed);

         if not Posix_Tools.Text.Byte_Classes.Is_ASCII_Octal_Digit
             (Text (Text'First + Processed))
         then
            return False;
         end if;

         Processed := Processed + 1;
      end loop;

      return True;
   end Valid_Mode;

   function Mode_Value (Text : String) return Natural
   is
      Value     : Natural := 0;
      Processed : Natural := 0;
   begin
      if Text'Length = 0 or else Text'Length > 4 then
         return 0;
      end if;

      while Processed < Text'Length loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Invariant (Text'Length <= 4);
         pragma Loop_Invariant (Processed <= 4);
         pragma Loop_Invariant (if Processed = 0 then Value = 0);
         pragma Loop_Invariant (if Processed = 1 then Value <= 8#7#);
         pragma Loop_Invariant (if Processed = 2 then Value <= 8#77#);
         pragma Loop_Invariant (if Processed = 3 then Value <= 8#777#);
         pragma Loop_Invariant (if Processed = 4 then Value <= 8#7777#);
         pragma Loop_Invariant (Value <= 8#7777#);
         pragma Loop_Variant (Increases => Processed);

         if not Posix_Tools.Text.Byte_Classes.Is_ASCII_Octal_Digit
             (Text (Text'First + Processed))
         then
            return 0;
         end if;

         Value :=
           Value * 8
           + Posix_Tools.Text.Byte_Classes.ASCII_Octal_Digit_Value
             (Text (Text'First + Processed));
         Processed := Processed + 1;
      end loop;

      return Value;
   end Mode_Value;
end Posix_Tools.Text.Octal_Modes;
