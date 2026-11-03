package body Basic_Tests.Text_Algorithms is
   function Same_Text (Left, Right : String) return Boolean is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;

      for I in Left'Range loop
         if Left (I) /= Right (Right'First + (I - Left'First)) then
            return False;
         end if;
      end loop;

      return True;
   end Same_Text;
end Basic_Tests.Text_Algorithms;
