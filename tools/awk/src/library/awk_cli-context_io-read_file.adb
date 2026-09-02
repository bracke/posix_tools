separate (Awk_CLI.Context_IO)
function Read_File
  (Context : Invocation_Context;
   Path    : String;
   Content : out U.Unbounded_String) return Awk_CLI.Platform.Read_Status
is
   Found  : Boolean;
   Status : Awk_CLI.Platform.Read_Status;
begin
   Status := Read_Virtual_File (Context, Path, Content, Found);
   if Found then
      return Status;
   end if;

   if Context.Config.Use_Process then
      return Awk_CLI.Platform.Read_File (Path, Content);
   end if;

   Content := U.Null_Unbounded_String;
   return Awk_CLI.Platform.Open_Failed;
end Read_File;
