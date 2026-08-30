with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Octal_Parsing;

package body Posix_Tools.Text.Printf_Escapes
  with SPARK_Mode => On
is
   LF : constant Character := Character'Val (10);

   function Escape_Value (Ch : Character) return Character is
     (case Ch is
        when 'a'    => Character'Val (7),
        when 'b'    => Character'Val (8),
        when 'f'    => Character'Val (12),
        when 'n'    => LF,
        when 'r'    => Character'Val (13),
        when 't'    => Character'Val (9),
        when 'v'    => Character'Val (11),
        when '\'    => '\',
        when others => Ch);

   function Stop_Decoding (Text : String) return Boolean is
      Processed : Natural := 0;
   begin
      while Processed < Text'Length loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Variant (Increases => Processed);

         if Text (Text'First + Processed) = '\'
           and then Processed + 1 < Text'Length
         then
            if Text (Text'First + Processed + 1) = 'c' then
               return True;
            elsif Posix_Tools.Text.Byte_Classes.Is_ASCII_Octal_Digit
              (Text (Text'First + Processed + 1))
            then
               declare
                  Parsed : constant Posix_Tools.Text.Octal_Parsing.Parsed_Octal_Prefix :=
                    Posix_Tools.Text.Octal_Parsing.Prefix_Value
                      (Text (Text'First + Processed + 1 .. Text'Last), 3);
                  Step : constant Natural :=
                    Natural'Min (Parsed.Count, Text'Length - Processed - 1);
               begin
                  Processed := Processed + Step + 1;
               end;
            else
               Processed := Processed + 2;
            end if;
         else
            Processed := Processed + 1;
         end if;
      end loop;

      return False;
   end Stop_Decoding;

   function Decoded_Length (Text : String) return Natural is
      Processed : Natural := 0;
      Result    : Natural := 0;
   begin
      while Processed < Text'Length loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Invariant (Result <= Processed);
         pragma Loop_Variant (Increases => Processed);

         declare
            Ch : constant Character := Text (Text'First + Processed);
         begin
            if Ch = '\' and then Processed + 1 < Text'Length then
               declare
                  Escaped : constant Character := Text (Text'First + Processed + 1);
               begin
                  if Escaped = 'c' then
                     return Result;
                  elsif Posix_Tools.Text.Byte_Classes.Is_ASCII_Octal_Digit (Escaped) then
                     declare
                        Parsed : constant Posix_Tools.Text.Octal_Parsing.Parsed_Octal_Prefix :=
                          Posix_Tools.Text.Octal_Parsing.Prefix_Value
                            (Text (Text'First + Processed + 1 .. Text'Last), 3);
                        Step : constant Natural :=
                          Natural'Min (Parsed.Count, Text'Length - Processed - 1);
                     begin
                        Result := Result + 1;
                        Processed := Processed + Step + 1;
                     end;
                  else
                     Result := Result + 1;
                     Processed := Processed + 2;
                  end if;
               end;
            else
               Result := Result + 1;
               Processed := Processed + 1;
            end if;
         end;
      end loop;

      return Result;
   end Decoded_Length;

   function Decode_Backslash_Text (Text : String) return String is
      Result      : String (1 .. Text'Length) := [others => Character'Val (0)];
      Processed   : Natural := 0;
      Last        : Natural := 0;
   begin
      while Processed < Text'Length loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Invariant (Last <= Processed);
         pragma Loop_Variant (Increases => Processed);

         declare
            Ch : constant Character := Text (Text'First + Processed);
         begin
            if Ch = '\' and then Processed + 1 < Text'Length then
               declare
                  Escaped : constant Character := Text (Text'First + Processed + 1);
               begin
                  if Escaped = 'c' then
                     exit;
                  elsif Posix_Tools.Text.Byte_Classes.Is_ASCII_Octal_Digit (Escaped) then
                     declare
                        Parsed : constant Posix_Tools.Text.Octal_Parsing.Parsed_Octal_Prefix :=
                          Posix_Tools.Text.Octal_Parsing.Prefix_Value
                            (Text (Text'First + Processed + 1 .. Text'Last), 3);
                        Step : constant Natural :=
                          Natural'Min (Parsed.Count, Text'Length - Processed - 1);
                     begin
                        pragma Assert (Last < Text'Length);
                        Last := Last + 1;
                        Result (Last) := Character'Val (Parsed.Value mod 256);
                        Processed := Processed + Step + 1;
                     end;
                  else
                     pragma Assert (Last < Text'Length);
                     Last := Last + 1;
                     Result (Last) := Escape_Value (Escaped);
                     Processed := Processed + 2;
                  end if;
               end;
            else
               pragma Assert (Last < Text'Length);
               Last := Last + 1;
               Result (Last) := Ch;
               Processed := Processed + 1;
            end if;
         end;
      end loop;

      return Result (1 .. Last);
   end Decode_Backslash_Text;
end Posix_Tools.Text.Printf_Escapes;
