separate (Awk_CLI.Context_IO)
function Write_Standard_Error
  (Context : in out Invocation_Context;
   Content : String) return Boolean
is
begin
   if Context.IO.Stderr_Fails then
      return False;
   end if;

   U.Append (Context.IO.Standard_Err, Content);
   if Context.Config.Use_Process then
      return Awk_CLI.Platform.Write_Standard_Error (Content);
   end if;

   return True;
end Write_Standard_Error;
