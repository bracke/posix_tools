with Posix_Tools.Text.Line_Breaks;

package body Posix_Tools.Streams.Lines is
   LF : constant Character := Character'Val (10);

   function Split_LF_Records (Input : String) return Segment_Vector is
      Result : Segment_Vector;
      Start  : Positive := Input'First;
   begin
      if Input = "" then
         return Result;
      end if;

      for I in Input'Range loop
         if Input (I) = LF then
            Result.Append (Input (Start .. I - 1));
            Start := I + 1;
         end if;
      end loop;

      if Start <= Input'Last then
         Result.Append (Input (Start .. Input'Last));
      end if;

      return Result;
   end Split_LF_Records;

   function Split_LF_Segments (Input : String) return Segment_Vector is
      Result : Segment_Vector;
   begin
      if Input = "" then
         return Result;
      end if;

      declare
         First : Positive := Input'First;
      begin
         while First in Input'Range loop
            declare
               Last : constant Positive :=
                 Posix_Tools.Text.Line_Breaks.LF_Segment_Last_From (Input, First);
            begin
               Result.Append (Input (First .. Last));

               exit when Last = Input'Last;
               First := Last + 1;
            end;
         end loop;
      end;

      return Result;
   end Split_LF_Segments;
end Posix_Tools.Streams.Lines;
