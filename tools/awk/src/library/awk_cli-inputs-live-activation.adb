with Awk_CLI.Context_IO;

package body Awk_CLI.Inputs.Live.Activation is
   use type Awk_CLI.Operands.Operand_Kind;
   use type Awk_CLI.Platform.Read_Status;

   procedure Reset_Active
     (State : in out Live_Input_State;
      Name  : String) is
   begin
      State.Active := True;
      State.Active_Process := False;
      State.Active_Name := U.To_Unbounded_String (Name);
      State.Active_Content := U.Null_Unbounded_String;
      State.Active_Position := 1;
   end Reset_Active;

   function Activate_Standard_Input
     (State : in out Live_Input_State) return Awk_CLI.Platform.Read_Status
   is
   begin
      Reset_Active (State, "-");

      if State.Context.IO.Stdin_Fails then
         State.Active := False;
         return Awk_CLI.Platform.Read_Failed;
      elsif State.Context.Config.Use_Process then
         State.Active_Process := True;
         return Awk_CLI.Platform.Open_Standard_Input (State.Process_Stream);
      else
         State.Active_Content := State.Context.IO.Standard_In;
         return Awk_CLI.Platform.Read_Success;
      end if;
   end Activate_Standard_Input;

   function Activate_Named_Input
     (State : in out Live_Input_State;
      Path  : String) return Awk_CLI.Platform.Read_Status
   is
      Found  : Boolean;
      Status : Awk_CLI.Platform.Read_Status;
   begin
      Reset_Active (State, Path);

      Status :=
        Awk_CLI.Context_IO.Read_Virtual_File
          (State.Context.all, Path, State.Active_Content, Found);
      if Found then
         if Status /= Awk_CLI.Platform.Read_Success then
            State.Active := False;
         end if;
         return Status;
      end if;

      if State.Context.Config.Use_Process then
         State.Active_Process := True;
         return Awk_CLI.Platform.Open_Input_File (Path, State.Process_Stream);
      end if;

      State.Active := False;
      State.Active_Process := False;
      return Awk_CLI.Platform.Open_Failed;
   end Activate_Named_Input;

   procedure Close_Active_Input (State : in out Live_Input_State) is
   begin
      Awk_CLI.Platform.Close_Input (State.Process_Stream);
      State.Active := False;
      State.Active_Process := False;
   end Close_Active_Input;

   procedure Activate_Empty_Standard_Input (State : in out Live_Input_State) is
   begin
      Reset_Active (State, "-");
   end Activate_Empty_Standard_Input;

   function Activate_Operand
     (State         : in out Live_Input_State;
      Operand_Index : Positive) return Awk_CLI.Platform.Read_Status
   is
   begin
      State.Operand_Index := Operand_Index;
      if Operand_Index > Natural (State.Operands.Length) then
         State.Implicit_Stdin_Used := True;
         declare
            Status : constant Awk_CLI.Platform.Read_Status :=
              Activate_Standard_Input (State);
         begin
            State.Active_Name := U.Null_Unbounded_String;
            return Status;
         end;
      end if;

      declare
         Item : constant Awk_CLI.Operands.Classified_Operand :=
           State.Operands.Element (Operand_Index);
      begin
         case Item.Kind is
            when Awk_CLI.Operands.Named_File =>
               return Activate_Named_Input (State, U.To_String (Item.Text));
            when Awk_CLI.Operands.Standard_Input =>
               if State.Implicit_Stdin_Used then
                  Activate_Empty_Standard_Input (State);
                  return Awk_CLI.Platform.Read_Success;
               else
                  State.Implicit_Stdin_Used := True;
                  return Activate_Standard_Input (State);
               end if;
            when Awk_CLI.Operands.Runtime_Assignment =>
               return Awk_CLI.Platform.Read_Success;
         end case;
      end;
   end Activate_Operand;
end Awk_CLI.Inputs.Live.Activation;
