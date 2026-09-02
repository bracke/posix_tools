separate (Awk_CLI.Inputs.Live)
function Write_Redirection
  (User_Data : System.Address;
   Path      : String;
   Content   : String;
   Append    : Boolean) return Awk_CLI.Redirections.Write_Status
is
   State : constant State_Access.Object_Pointer :=
     State_Access.To_Pointer (User_Data);
begin
   return
     Awk_CLI.Live_Context_Callbacks.Write_Redirection
       (State.Context.all, Path, Content, Append);
end Write_Redirection;
