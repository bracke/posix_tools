package body Posix_Tools.Text.Paste_Delimiters
  with SPARK_Mode => On
is
   LF  : constant Character := Character'Val (10);
   HT  : constant Character := Character'Val (9);
   NUL : constant Character := Character'Val (0);

   function Decoded_Escape (Ch : Character) return Character is
     (if Ch = 'n' then LF
      elsif Ch = 't' then HT
      elsif Ch = '\' then '\'
      elsif Ch = '0' then NUL
      else Ch);

   function Decoded_Delimiter_Length (Text : String) return Natural is
      Processed : Natural := 0;
      Length    : Natural := 0;
   begin
      while Processed < Text'Length loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Invariant (Length <= Processed);
         pragma Loop_Variant (Increases => Processed);

         Length := Length + 1;
         pragma Assert (Length <= Text'Length);

         declare
            Index : constant Positive := Text'First + Processed;
         begin
            pragma Assert (Index in Text'Range);
            if Text (Index) = '\' and then Processed + 1 < Text'Length then
               Processed := Processed + 2;
            else
               Processed := Processed + 1;
            end if;
         end;

         if Processed > Text'Length then
            Processed := Text'Length;
         end if;
      end loop;

      return Length;
   end Decoded_Delimiter_Length;

   function Decode_Delimiters (Text : String) return String is
      Result    : String (1 .. Text'Length) := [others => NUL];
      Last      : Natural := 0;
      Processed : Natural := 0;
   begin
      while Processed < Text'Length loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Invariant (Last <= Result'Length);
         pragma Loop_Invariant (Last <= Processed);
         pragma Loop_Variant (Increases => Processed);

         Last := Last + 1;
         pragma Assert (Last <= Result'Length);

         declare
            Index : constant Positive := Text'First + Processed;
         begin
            pragma Assert (Index in Text'Range);
            if Text (Index) = '\' and then Processed + 1 < Text'Length then
               Result (Last) := Decoded_Escape (Text (Index + 1));
               Processed := Processed + 2;
            else
               Result (Last) := Text (Index);
               Processed := Processed + 1;
            end if;
         end;

         if Processed > Text'Length then
            Processed := Text'Length;
         end if;
      end loop;

      return Result (1 .. Last);
   end Decode_Delimiters;

   function Delimiter (Text : String; Position : Positive) return String is
      Ch : Character;
   begin
      if Text = "" then
         return "";
      else
         Ch := Text (((Position - 1) mod Text'Length) + 1);
         return (if Ch = NUL then "" else Ch & "");
      end if;
   end Delimiter;
end Posix_Tools.Text.Paste_Delimiters;
