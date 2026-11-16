separate (Posix_Tools.Host_Adapters.File_System)
procedure Refresh_Follow_File
  (Path     : String;
   File     : in out Follow_File;
   Reopened : out Boolean;
   Status   : out Follow_Open_Status)
is
   use type Hostkit.Metadata.Entry_Identity;
   Current : Hostkit.Metadata.Entry_Identity;
begin
   Reopened := False;
   Status := Path_Identity (Path, Current);
   if Status /= Follow_Ready then
      return;
   end if;

   if Current.Available and then not File.Identity.Available then
      --  The open object was not identity-verified. Reopen it now rather
      --  than assigning the pathname's identity to an unrelated handle.
      Open_Follow_File
        (Path, File, Status, Require_Identity => True);
      Reopened := Status = Follow_Ready;
      return;
   elsif File.Identity.Available
     and then Current.Available
     and then File.Identity /= Current
   then
      Open_Follow_File
        (Path, File, Status, Require_Identity => True);
      Reopened := Status = Follow_Ready;
      return;
   end if;

   if not Follow_File_Is_Open (File) then
      Open_Follow_File
        (Path, File, Status, Require_Identity => True);
      Reopened := Status = Follow_Ready;
      return;
   end if;

   if Current.Available then
      File.Identity := Current;
   end if;
exception
   when Ada.IO_Exceptions.Name_Error =>
      Status := Follow_Missing;
   when others =>
      --  intentional terminal exception barrier
      Status := Follow_Error;
end Refresh_Follow_File;
