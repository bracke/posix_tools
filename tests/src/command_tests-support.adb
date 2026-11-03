package body Command_Tests.Support is
   function Expected_Verify_Status
     (Output_Text : String) return Posix_Tools.Exit_Status.Code
   is
      LF    : constant Character := Character'Val (10);
      First : Positive := Output_Text'First;
   begin
      for I in Output_Text'Range loop
         if Output_Text (I) = LF then
            declare
               Line : constant String := Output_Text (First .. I - 1);
            begin
               if Line'Length < 4
                 or else Line (Line'Last - 3 .. Line'Last) /= ": ok"
               then
                  return Posix_Tools.Exit_Status.Operational_Failure;
               end if;
            end;
            First := I + 1;
         end if;
      end loop;
      return Posix_Tools.Exit_Status.Success;
   end Expected_Verify_Status;
end Command_Tests.Support;
