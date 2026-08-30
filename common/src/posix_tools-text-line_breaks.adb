package body Posix_Tools.Text.Line_Breaks
  with SPARK_Mode => On
is
   function Is_LF (Ch : Character) return Boolean is
     (Ch = Character'Val (10));

   function Ends_With_LF (Text : String) return Boolean is
     (Text /= "" and then Is_LF (Text (Text'Last)));

   function LF_Count (Text : String) return Long_Long_Integer is
      Processed : Natural := 0;
      Result    : Long_Long_Integer := 0;
   begin
      while Processed < Text'Length loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Invariant (Result >= 0);
         pragma Loop_Invariant (Result <= Long_Long_Integer (Processed));
         pragma Loop_Variant (Increases => Processed);

         if Is_LF (Text (Text'First + Processed)) then
            Result := Result + 1;
         end if;

         Processed := Processed + 1;
      end loop;

      return Result;
   end LF_Count;

   function LF_Segment_Count (Text : String) return Long_Long_Integer is
     (if Text = "" then 0
      elsif Ends_With_LF (Text) then LF_Count (Text)
      else LF_Count (Text) + 1);

   function LF_Segment_Last_From (Text : String; First : Positive) return Positive is
      Last : Positive := First;
   begin
      while Last < Text'Last
        and then not Is_LF (Text (Last))
      loop
         pragma Loop_Invariant (Last in First .. Text'Last);
         pragma Loop_Variant (Increases => Last);

         Last := Last + 1;
      end loop;

      return Last;
   end LF_Segment_Last_From;

   function Line_Number_Through (Text : String; Last : Positive) return Long_Long_Integer is
      Processed : Natural := 0;
      Result    : Long_Long_Integer := 1;
   begin
      while Processed <= Last - Text'First loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Invariant (Result >= 1);
         pragma Loop_Invariant (Result <= Long_Long_Integer (Processed) + 1);
         pragma Loop_Variant (Increases => Processed);

         if Is_LF (Text (Text'First + Processed)) then
            Result := Result + 1;
         end if;

         Processed := Processed + 1;
      end loop;

      return Result;
   end Line_Number_Through;

   function Without_Trailing_CR (Line : String) return String is
   begin
      if Line'Length > 0 and then Line (Line'Last) = Character'Val (13) then
         return Line (Line'First .. Line'Last - 1);
      else
         return Line;
      end if;
   end Without_Trailing_CR;
end Posix_Tools.Text.Line_Breaks;
