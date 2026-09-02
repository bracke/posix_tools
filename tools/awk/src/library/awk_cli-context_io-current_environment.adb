separate (Awk_CLI.Context_IO)
function Current_Environment
  (Context : Invocation_Context) return Awk_CLI.Environment.Entry_Vectors.Vector
is
   Result : Awk_CLI.Environment.Entry_Vectors.Vector;
begin
   if Context.Config.Use_Process and then Context.IO.Environment.Is_Empty then
      return Awk_CLI.Platform.Process_Environment;
   end if;

   for Item of Context.IO.Environment loop
      Result.Append
        (Awk_CLI.Environment.Env_Entry'
           (Name => Item.Name, Value => Item.Value));
   end loop;

   return Awk_CLI.Environment.Normalize (Result);
end Current_Environment;
