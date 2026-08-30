with Ada.Strings.Unbounded;

with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Checksums;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Commands.Cksum is
   use Ada.Strings.Unbounded;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      All_Ok : Boolean := True;
      First  : Positive := 1;

      procedure Emit (Name : String);

      procedure Emit (Name : String) is
         Data : Unbounded_String;
         Ok   : Boolean;
      begin
         Posix_Tools.Commands.File_Helpers.Read_All (Context, Name, Data, Ok);
         if Ok then
            Context.Put_Line
              (Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                 (Long_Long_Integer
                    (Posix_Tools.Text.Checksums.POSIX_Cksum_CRC_32 (To_String (Data)))) & " "
               & Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                   (Long_Long_Integer (Length (Data)))
               & (if Name = "-" then "" else " " & Name));
         else
            All_Ok := False;
         end if;
      end Emit;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count >= 1 and then Context.Argument (1) = "--" then
         First := 2;
      end if;

      if Context.Argument_Count < First then
         Emit ("-");
      else
         for I in First .. Context.Argument_Count loop
            Emit (Context.Argument (I));
         end loop;
      end if;

      Result.Status :=
        (if All_Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Cksum;
