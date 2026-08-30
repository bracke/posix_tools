package body Posix_Tools.Text.Matching
  with SPARK_Mode => On
is
   function Contains (Text, Pattern : String) return Boolean is
   begin
      if Pattern = "" then
         return True;
      elsif Pattern'Length > Text'Length then
         return False;
      end if;

      for Offset in 0 .. Text'Length - Pattern'Length loop
         if Starts_With_At (Text, Pattern, Text'First + Offset) then
            return True;
         end if;
      end loop;

      return False;
   end Contains;

   function Ends_With (Text, Suffix : String) return Boolean is
      Start : Positive;
   begin
      if Suffix = "" then
         return True;
      elsif Suffix'Length > Text'Length then
         return False;
      end if;

      Start := Text'Last - Suffix'Length + 1;
      for Offset in 0 .. Suffix'Length - 1 loop
         if Text (Start + Offset) /= Suffix (Suffix'First + Offset) then
            return False;
         end if;
      end loop;

      return True;
   end Ends_With;

   function Starts_With (Text, Prefix : String) return Boolean is
   begin
      if Prefix = "" then
         return True;
      elsif Prefix'Length > Text'Length then
         return False;
      end if;

      for Offset in 0 .. Prefix'Length - 1 loop
         if Text (Text'First + Offset) /= Prefix (Prefix'First + Offset) then
            return False;
         end if;
      end loop;

      return True;
   end Starts_With;

   function Starts_With_At
     (Text    : String;
      Pattern : String;
      Index   : Positive) return Boolean
   is
   begin
      if Pattern = "" or else Index not in Text'Range then
         return False;
      elsif Pattern'Length > Text'Last - Index + 1 then
         return False;
      end if;

      for Offset in 0 .. Pattern'Length - 1 loop
         if Text (Index + Offset) /= Pattern (Pattern'First + Offset) then
            return False;
         end if;
      end loop;

      return True;
   end Starts_With_At;

end Posix_Tools.Text.Matching;
