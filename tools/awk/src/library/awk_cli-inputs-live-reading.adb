with Awk_CLI.Inputs.Live.Activation;

package body Awk_CLI.Inputs.Live.Reading is
   use type Awk_CLI.Platform.Read_Status;

   Chunk_Size : constant Natural := 8192;

   function Read_Active_In_Memory
     (State        : in out Live_Input_State;
      Filename     : out U.Unbounded_String;
      Text         : out U.Unbounded_String;
      End_Of_Input : out Boolean) return Awk_CLI.Platform.Read_Status
   is
      Content_Length : constant Natural := U.Length (State.Active_Content);
   begin
      Filename := State.Active_Name;
      Text := U.Null_Unbounded_String;
      End_Of_Input := False;

      if Content_Length = 0 then
         State.Active := False;
         End_Of_Input := True;
         return Awk_CLI.Platform.Read_Success;
      elsif State.Active_Position <= Content_Length then
         declare
            Last : constant Natural :=
              Natural'Min (Content_Length, State.Active_Position + Chunk_Size - 1);
         begin
            Text :=
              U.To_Unbounded_String
                (U.Slice (State.Active_Content, State.Active_Position, Last));
            State.Active_Position := Last + 1;
            if State.Active_Position > Content_Length then
               State.Active := False;
            end if;
            return Awk_CLI.Platform.Read_Success;
         end;
      else
         State.Active := False;
      end if;

      return Awk_CLI.Platform.Read_Success;
   end Read_Active_In_Memory;

   function Read_Active_Process
     (State        : in out Live_Input_State;
      Filename     : out U.Unbounded_String;
      Text         : out U.Unbounded_String;
      End_Of_Input : out Boolean) return Awk_CLI.Platform.Read_Status
   is
      EOF    : Boolean;
      Status : Awk_CLI.Platform.Read_Status;
   begin
      End_Of_Input := False;
      Status :=
        Awk_CLI.Platform.Read_Input_Chunk
          (State.Process_Stream, Text, EOF);
      Filename := State.Active_Name;

      if Status /= Awk_CLI.Platform.Read_Success then
         Awk_CLI.Inputs.Live.Activation.Close_Active_Input (State);
         End_Of_Input := True;
         return Status;
      elsif EOF then
         Awk_CLI.Inputs.Live.Activation.Close_Active_Input (State);
         End_Of_Input := True;
      end if;

      return Awk_CLI.Platform.Read_Success;
   end Read_Active_Process;

   function Read_Active
     (State        : in out Live_Input_State;
      Filename     : out U.Unbounded_String;
      Text         : out U.Unbounded_String;
      End_Of_Input : out Boolean) return Awk_CLI.Platform.Read_Status
   is
   begin
      if State.Active_Process then
         return Read_Active_Process (State, Filename, Text, End_Of_Input);
      else
         return Read_Active_In_Memory (State, Filename, Text, End_Of_Input);
      end if;
   end Read_Active;
end Awk_CLI.Inputs.Live.Reading;
