separate (Awk_CLI.Context_IO)
function Write_Standard_Output
  (Context : in out Invocation_Context;
   Content : String) return Boolean
is
begin
   if Context.IO.Stdout_Fails then
      return False;
   end if;

   U.Append (Context.IO.Standard_Out, Content);
   if Context.Config.Use_Process then
      return Awk_CLI.Platform.Write_Standard_Output (Content);
   end if;

   return True;
end Write_Standard_Output;
