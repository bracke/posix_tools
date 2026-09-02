with Ada.Command_Line;
with Ada.Text_IO;
with Awk_CLI;
with Awk_CLI.Diagnostics;
with Awk_CLI.Localization;
with Awk_CLI.Output;
with Awk_CLI.Platform;
with Posix_Tools.Version;

procedure Awk is
   Context : Awk_CLI.Invocation_Context;
   Status  : Awk_CLI.Exit_Code := Awk_CLI.Exit_Code (Awk_CLI.Diagnostics.Internal_Exit);
begin
   if Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) = "--posix-tools-identify"
   then
      Ada.Text_IO.Put_Line ("schema=1");
      Ada.Text_IO.Put_Line ("project=" & Posix_Tools.Version.Project_Name);
      Ada.Text_IO.Put_Line ("command=awk");
      Ada.Text_IO.Put_Line ("version=" & Posix_Tools.Version.Version_String);
      return;
   end if;

   Awk_CLI.Initialize_From_Process (Context);
   Status := Awk_CLI.Run (Context);
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (Status));
exception
   when others =>
      declare
         Catalog : Awk_CLI.Localization.Catalog;
      begin
         Awk_CLI.Localization.Initialize
           (Catalog, Awk_CLI.Platform.Catalog_Path, Awk_CLI.Platform.Locale);
         Ada.Text_IO.Put
           (Ada.Text_IO.Standard_Error,
            Awk_CLI.Output.Diagnostic_Text
              (Catalog,
               Awk_CLI.Diagnostics.Make
                 ("awk.internal.unexpected_exception",
                  Awk_CLI.Diagnostics.Internal_Error,
                  Awk_CLI.Diagnostics.Internal),
               Awk_CLI.Platform.Standard_Error_Is_Terminal,
               Awk_CLI.Platform.No_Color_Active));
      exception
         when others =>
            null;
      end;
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (70));
end Awk;
