package body Posix_Tools.Text.Whitespace_Data is
   function Is_Whitespace (Code_Point : Long_Long_Integer) return Boolean is
   begin
      for Range_Value of White_Space_Ranges loop
         if Code_Point in Range_Value.First .. Range_Value.Last then
            return True;
         end if;
      end loop;

      return False;
   end Is_Whitespace;
end Posix_Tools.Text.Whitespace_Data;
