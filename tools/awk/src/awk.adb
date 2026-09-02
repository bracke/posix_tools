with Awk_CLI;
with Awk_CLI.Diagnostics;
with Awk_CLI.Localization;
with Awk_CLI.Output;
with Awk_CLI.Platform;
with Posix_Tools.Host_Adapters.Streams;
with Posix_Tools.Process_Entry;

procedure Awk is
   Context : Awk_CLI.Invocation_Context;
   Status  : Awk_CLI.Exit_Code := Awk_CLI.Exit_Code (Awk_CLI.Diagnostics.Internal_Exit);
begin
   if Posix_Tools.Process_Entry.Is_Identity_Request then
      if not Posix_Tools.Process_Entry.Write_Identity ("awk") then
         Posix_Tools.Process_Entry.Set_Exit_Status (1);
      end if;
      return;
   end if;

   Awk_CLI.Initialize_From_Process (Context);
   Status := Awk_CLI.Run (Context);
   Posix_Tools.Process_Entry.Set_Exit_Status (Integer (Status));
exception
   when others =>
      declare
         Catalog : Awk_CLI.Localization.Catalog;
      begin
         Awk_CLI.Localization.Initialize
           (Catalog, Awk_CLI.Platform.Catalog_Path, Awk_CLI.Platform.Locale);
         declare
            Ignored : constant Boolean :=
              Posix_Tools.Host_Adapters.Streams.Write_Standard_Error
                (Awk_CLI.Output.Diagnostic_Text
                   (Catalog,
                    Awk_CLI.Diagnostics.Make
                      ("awk.internal.unexpected_exception",
                       Awk_CLI.Diagnostics.Internal_Error,
                       Awk_CLI.Diagnostics.Internal),
                    Awk_CLI.Platform.Standard_Error_Is_Terminal,
                    Awk_CLI.Platform.No_Color_Active));
         begin
            null;
         end;
      exception
         when others =>
            null;
      end;
      Posix_Tools.Process_Entry.Set_Exit_Status (70);
end Awk;
