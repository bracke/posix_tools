with Posix_Tools.Text.Byte_Classes;

package body Posix_Tools.Text.Portable_Paths
  with SPARK_Mode => On
is
   function Portable_Component (Text : String) return Boolean is
   begin
      for Ch of Text loop
         if not Posix_Tools.Text.Byte_Classes.Is_Portable_Filename_Character (Ch) then
            return False;
         end if;
      end loop;

      return True;
   end Portable_Component;
end Posix_Tools.Text.Portable_Paths;
