with GNAT.OS_Lib;

package body E2E_Files is
   use type GNAT.OS_Lib.File_Descriptor;

   procedure Write (Path, Text : String) is
      Handle  : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Written : Natural := 0;
      Count   : Integer;
   begin
      Handle := GNAT.OS_Lib.Create_File (Path, GNAT.OS_Lib.Binary);
      if Handle = GNAT.OS_Lib.Invalid_FD then
         raise Program_Error with "could not create " & Path;
      end if;

      while Written < Text'Length loop
         Count :=
           GNAT.OS_Lib.Write
             (Handle, Text (Text'First + Written)'Address,
              Text'Length - Written);
         if Count <= 0 then
            raise Program_Error with "could not write " & Path;
         end if;
         Written := Written + Natural (Count);
      end loop;

      GNAT.OS_Lib.Close (Handle);
      Handle := GNAT.OS_Lib.Invalid_FD;
   exception
      when others =>
         --  intentional terminal exception barrier
         if Handle /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Handle);
         end if;
         raise;
   end Write;
end E2E_Files;
