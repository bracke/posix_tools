separate (Awk_CLI.Execution.Callbacks)
procedure Read_Text
  (User_Data    : System.Address;
   Filename     : out U.Unbounded_String;
   Text         : out U.Unbounded_String;
   End_Of_Input : out Boolean)
is
   State : constant Stream_State_Access.Object_Pointer :=
     Stream_State_Access.To_Pointer (User_Data);
begin
   if State.Has_Failure then
      Filename := U.Null_Unbounded_String;
      Text := U.Null_Unbounded_String;
      End_Of_Input := True;
      return;
   end if;

   if State.Input_Index >= Natural (State.Inputs.Length) then
      Filename := U.Null_Unbounded_String;
      Text := U.Null_Unbounded_String;
      End_Of_Input := True;
   else
      State.Input_Index := State.Input_Index + 1;
      Filename := State.Inputs.Element (State.Input_Index).Name;
      Text := State.Inputs.Element (State.Input_Index).Content;
      End_Of_Input := False;
   end if;
end Read_Text;
