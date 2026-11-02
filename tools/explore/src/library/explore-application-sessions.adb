
package body Explore.Application.Sessions is
   procedure Ask (State : in out Session; Mode : Question_Mode; Question : String) is
   begin
      Explore.Modes.Ask (State.Interaction.Mode, State.Interaction.Resume, Mode);
      State.Frame.Question := Unbounded.To_Unbounded_String (Question);
   end Ask;

   procedure Complain (State : in out Session; Path : String; Error : Posix_Tools.File_Operations.Operation_Error) is
   begin
      Warn (State, Explore.Words.Error_Text (Unbounded.To_String (State.Config.Locale), Path, Error));
   end Complain;

   procedure Leave_Mode (State : in out Session) is
   begin
      Explore.Modes.Leave (State.Interaction.Mode, State.Interaction.Resume);
      State.Frame.Question := Unbounded.Null_Unbounded_String;
   end Leave_Mode;

   procedure Lose_Terminal (State : in out Session) is
   begin
      State.Terminal_Lost := True;
      State.Quit := True;
   end Lose_Terminal;

   procedure Open_Prompt
     (State   : in out Session;
      Mode    : Prompt_Mode;
      Label   : Unbounded.Unbounded_String;
      Initial : String := "")
   is
   begin
      State.Interaction.Mode := Mode;
      State.Frame.Prompt_Label := Label;
      State.Frame.Prompt_Text := Unbounded.To_Unbounded_String (Initial);
   end Open_Prompt;

   procedure Say (State : in out Session; Text : String) is
   begin
      State.Frame.Message := Unbounded.To_Unbounded_String (Text);
      State.Frame.Message_Is_Error := False;
   end Say;

   procedure Send (State : in out Session; Text : String) is
   begin
      if not Write (Text) then
         Lose_Terminal (State);
      end if;
   end Send;

   procedure Show_Mode (State : in out Session) is
      Mode   : constant Interaction_Mode := State.Interaction.Mode;
      Resume : constant Interaction_Mode := State.Interaction.Resume;
   begin
      State.Frame.Prompting := Explore.Modes.Prompting (Mode);
      State.Frame.Panel_Open := Explore.Modes.Panel_Open (Mode, Resume);
      State.Frame.Editing := Explore.Modes.Editing (Mode, Resume);
   end Show_Mode;

   procedure Warn (State : in out Session; Text : String) is
   begin
      State.Frame.Message := Unbounded.To_Unbounded_String (Text);
      State.Frame.Message_Is_Error := True;
   end Warn;
end Explore.Application.Sessions;
