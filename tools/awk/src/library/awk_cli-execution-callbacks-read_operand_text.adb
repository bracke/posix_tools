separate (Awk_CLI.Execution.Callbacks)
procedure Read_Operand_Text
  (User_Data     : System.Address;
   Operand_Index : Positive;
   Filename      : out U.Unbounded_String;
   Text          : out U.Unbounded_String;
   End_Of_Input  : out Boolean)
is
   State : constant Stream_State_Access.Object_Pointer :=
     Stream_State_Access.To_Pointer (User_Data);
   Status : Awk_CLI.Platform.Read_Status;
begin
   if State.Has_Failure then
      Filename := U.Null_Unbounded_String;
      Text := U.Null_Unbounded_String;
      End_Of_Input := True;
      return;
   end if;

   Status :=
     State.Live_Input.all
       (State.Live_User_Data, Operand_Index, Filename, Text, End_Of_Input);
   case Status is
      when Awk_CLI.Platform.Read_Success =>
         null;
      when Awk_CLI.Platform.Open_Failed | Awk_CLI.Platform.Read_Failed =>
         Set_Failure (State.all, Make_Input_Failure (Status, Filename));
         Filename := U.Null_Unbounded_String;
         Text := U.Null_Unbounded_String;
         End_Of_Input := True;
   end case;
end Read_Operand_Text;
