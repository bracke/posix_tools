separate (Awk_CLI.Inputs.Live)
function Read
  (User_Data    : System.Address;
   Operand_Index : Positive;
   Filename     : out U.Unbounded_String;
   Text         : out U.Unbounded_String;
   End_Of_Input : out Boolean) return Awk_CLI.Platform.Read_Status
is
   State  : constant State_Access.Object_Pointer :=
     State_Access.To_Pointer (User_Data);
   Status : Awk_CLI.Platform.Read_Status;
begin
   Filename := U.Null_Unbounded_String;
   Text := U.Null_Unbounded_String;
   End_Of_Input := False;

   loop
      if State.Active and then State.Operand_Index /= Operand_Index then
         Awk_CLI.Inputs.Live.Activation.Close_Active_Input (State.all);
      end if;

      if not State.Active then
         if State.Operand_Index = Operand_Index then
            End_Of_Input := True;
            return Awk_CLI.Platform.Read_Success;
         end if;

         Status := Awk_CLI.Inputs.Live.Activation.Activate_Operand
           (State.all, Operand_Index);
         if Status /= Awk_CLI.Platform.Read_Success then
            Filename := State.Active_Name;
            End_Of_Input := True;
            return Status;
         end if;

         if not State.Active then
            End_Of_Input := True;
            return Awk_CLI.Platform.Read_Success;
         end if;
      end if;

      Status := Awk_CLI.Inputs.Live.Reading.Read_Active
        (State.all, Filename, Text, End_Of_Input);
      if Status /= Awk_CLI.Platform.Read_Success or else U.Length (Text) > 0 then
         return Status;
      elsif Filename /= U.Null_Unbounded_String and then not State.Active then
         return Awk_CLI.Platform.Read_Success;
      end if;
   end loop;
end Read;
