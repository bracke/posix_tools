with Ada.Strings.Unbounded;

package body Posix_Tools.Streams.Lines is
   function Split_LF_Segments (Input : String) return Segment_Vector is
      use Ada.Strings.Unbounded;
      Result  : Segment_Vector;
      Current : Unbounded_String;
   begin
      for Ch of Input loop
         Append (Current, Ch);
         if Ch = Character'Val (10) then
            Result.Append (To_String (Current));
            Current := Null_Unbounded_String;
         end if;
      end loop;

      if Length (Current) > 0 then
         Result.Append (To_String (Current));
      end if;

      return Result;
   end Split_LF_Segments;
end Posix_Tools.Streams.Lines;
