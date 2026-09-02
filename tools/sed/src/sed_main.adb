with Posix_Tools.Process_Entry;
with Sed.Application;
with Sed.Status;

--  Process entry point for the sed stream editor.
--
--  The main unit is deliberately thin: it hands control to the application
--  layer, reports the status that layer decided, and contains the last-resort
--  handler for anything the application could not contain. It is named
--  sed_main because Sed is the root package of the hierarchy; the executable
--  built from it is installed as "sed".
procedure Sed_Main is
   Status : Sed.Status.Exit_Status := Sed.Status.Status_Of
     (Sed.Status.Internal_Failure);
begin
   if Posix_Tools.Process_Entry.Is_Identity_Request then
      if not Posix_Tools.Process_Entry.Write_Identity ("sed") then
         Posix_Tools.Process_Entry.Set_Exit_Status (1);
      end if;
      return;
   end if;

   Sed.Application.Run (Status);
   Posix_Tools.Process_Entry.Set_Exit_Status (Integer (Status));
exception
   when others =>
      --  The application layer contains expected and unexpected failures
      --  alike and renders a localized internal-error diagnostic for them.
      --  Reaching here means even that failed, so the only thing left to do
      --  is report the internal-failure status without an Ada traceback.
      Posix_Tools.Process_Entry.Set_Exit_Status
        (Integer (Sed.Status.Status_Of (Sed.Status.Internal_Failure)));
end Sed_Main;
