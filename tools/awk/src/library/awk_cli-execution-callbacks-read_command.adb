separate (Awk_CLI.Execution.Callbacks)
procedure Read_Command
  (User_Data : System.Address;
   Command   : String;
   Text      : out U.Unbounded_String;
   Available : out Boolean)
is
   State : constant Stream_State_Access.Object_Pointer :=
     Stream_State_Access.To_Pointer (User_Data);
begin
   if State.Has_Failure then
      Text := U.Null_Unbounded_String;
      Available := False;
   elsif State.Live_Command /= null then
      Available := State.Live_Command.all (State.Live_User_Data, Command, Text);
   else
      Text := U.Null_Unbounded_String;
      Available := False;
   end if;
end Read_Command;
