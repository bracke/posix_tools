with Posix_Tools.Commands.Helpers;
with Posix_Tools.Counts;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Commands.Df is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First : Positive := 1;
      Ok    : Boolean := True;

      procedure Print_Capacity (Path : String);

      procedure Print_Capacity (Path : String) is
         Capacity : constant FS.Volume_Capacity := FS.File_System_Capacity (Path);
         Total    : Long_Long_Integer;
         Free     : Long_Long_Integer;
         Used     : Long_Long_Integer;
      begin
         if not Capacity.Available then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Ok := False;
            return;
         end if;

         Total := Posix_Tools.Counts.Rounded_Units (Capacity.Capacity_Bytes, 512);
         Free := Posix_Tools.Counts.Rounded_Units (Capacity.Free_Bytes, 512);
         Used := Long_Long_Integer'Max (0, Total - Free);
         Context.Put_Line
           (Path & " "
            & Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Total) & " "
            & Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Used) & " "
            & Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Free));
      end Print_Capacity;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count > 0 and then Context.Argument (1) = "--" then
         First := 2;
      end if;

      Context.Put_Line ("Filesystem 512-blocks Used Available");
      if First > Context.Argument_Count then
         Print_Capacity (".");
      else
         for I in First .. Context.Argument_Count loop
            Print_Capacity (Context.Argument (I));
            exit when Context.Output_Failed;
         end loop;
      end if;

      Result.Status :=
        (if Context.Output_Failed or else not Ok then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Df;
