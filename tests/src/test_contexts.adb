package body Test_Contexts is
   use type Ada.Streams.Stream_Element_Offset;

   procedure Initialize
     (Self         : in out Capturing_Context;
      Command_Name : String;
      Arguments    : Posix_Tools.Arguments.Vector)
   is
   begin
      Posix_Tools.Commands.Contexts.Initialize
        (Posix_Tools.Commands.Contexts.Context (Self), Command_Name, Arguments);
      Self.Out_Text := Ada.Strings.Unbounded.Null_Unbounded_String;
      Self.Err_Text := Ada.Strings.Unbounded.Null_Unbounded_String;
      Self.Pwd_Text := Ada.Strings.Unbounded.Null_Unbounded_String;
      Self.Locale_Text := Ada.Strings.Unbounded.To_Unbounded_String ("en");
      Self.Physical_Text := Ada.Strings.Unbounded.To_Unbounded_String ("/physical");
      Self.Input_Text := Ada.Strings.Unbounded.Null_Unbounded_String;
      Self.Input_Position := 1;
      Self.Input_Failure_Enabled := False;
      Self.Input_Failure_Limit := 0;
      Self.Output_Is_Terminal := False;
      Self.Logical_Pwd_Matches := True;
      Self.Output_Failure_Enabled := False;
      Self.Output_Failure_Limit := 0;
   end Initialize;

   overriding procedure Put (Self : in out Capturing_Context; Text : String) is
      Current_Length : constant Natural := Ada.Strings.Unbounded.Length (Self.Out_Text);
      Remaining      : Natural;
   begin
      if Self.Output_Failure_Enabled then
         if Current_Length >= Self.Output_Failure_Limit then
            Posix_Tools.Commands.Contexts.Mark_Output_Failure
              (Posix_Tools.Commands.Contexts.Context (Self));
            return;
         end if;

         Remaining := Self.Output_Failure_Limit - Current_Length;
         if Text'Length > Remaining then
            if Remaining > 0 then
               Ada.Strings.Unbounded.Append (Self.Out_Text, Text (Text'First .. Text'First + Remaining - 1));
            end if;
            Posix_Tools.Commands.Contexts.Mark_Output_Failure
              (Posix_Tools.Commands.Contexts.Context (Self));
            return;
         end if;
      end if;

      Ada.Strings.Unbounded.Append (Self.Out_Text, Text);
   end Put;

   overriding procedure Put_Line (Self : in out Capturing_Context; Text : String) is
   begin
      Put (Self, Text & Character'Val (10));
   end Put_Line;

   overriding procedure Put_Error_Line (Self : in out Capturing_Context; Text : String) is
   begin
      Ada.Strings.Unbounded.Append (Self.Err_Text, Text & Character'Val (10));
   end Put_Error_Line;

   overriding procedure Read_Standard_Input
     (Self   : in out Capturing_Context;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is
      Input  : constant String := Ada.Strings.Unbounded.To_String (Self.Input_Text);
      Target : Ada.Streams.Stream_Element_Offset := Buffer'First;
   begin
      if Self.Input_Position > Input'Length then
         Last := Buffer'First - Ada.Streams.Stream_Element_Offset (1);
         return;
      end if;

      while Target <= Buffer'Last and then Self.Input_Position <= Input'Length loop
         Buffer (Target) := Ada.Streams.Stream_Element (Character'Pos (Input (Self.Input_Position)));
         Target := Target + Ada.Streams.Stream_Element_Offset (1);
         Self.Input_Position := Self.Input_Position + 1;
      end loop;

      Last := Target - Ada.Streams.Stream_Element_Offset (1);
   end Read_Standard_Input;

   overriding function Try_Read_Standard_Input
     (Self   : in out Capturing_Context;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset) return Boolean
   is
      Input  : constant String := Ada.Strings.Unbounded.To_String (Self.Input_Text);
      Target : Ada.Streams.Stream_Element_Offset := Buffer'First;
   begin
      if Self.Input_Failure_Enabled and then Self.Input_Position > Self.Input_Failure_Limit then
         Last := Buffer'First - Ada.Streams.Stream_Element_Offset (1);
         return False;
      end if;

      if not Self.Input_Failure_Enabled then
         Read_Standard_Input (Self, Buffer, Last);
         return True;
      end if;

      if Self.Input_Position > Input'Length then
         Last := Buffer'First - Ada.Streams.Stream_Element_Offset (1);
         return True;
      end if;

      while Target <= Buffer'Last
        and then Self.Input_Position <= Input'Length
        and then Self.Input_Position <= Self.Input_Failure_Limit
      loop
         Buffer (Target) := Ada.Streams.Stream_Element (Character'Pos (Input (Self.Input_Position)));
         Target := Target + Ada.Streams.Stream_Element_Offset (1);
         Self.Input_Position := Self.Input_Position + 1;
      end loop;

      Last := Target - Ada.Streams.Stream_Element_Offset (1);
      return True;
   end Try_Read_Standard_Input;

   overriding function Environment_Value (Self : Capturing_Context; Name : String) return String is
   begin
      if Name = "PWD" then
         return Ada.Strings.Unbounded.To_String (Self.Pwd_Text);
      elsif Name = "LC_ALL" then
         return Ada.Strings.Unbounded.To_String (Self.Locale_Text);
      else
         return "";
      end if;
   end Environment_Value;

   overriding function Effective_Locale (Self : Capturing_Context) return String is
   begin
      return Ada.Strings.Unbounded.To_String (Self.Locale_Text);
   end Effective_Locale;

   overriding function Physical_Current_Directory (Self : Capturing_Context) return String is
   begin
      if Ada.Strings.Unbounded.To_String (Self.Physical_Text) = "__raise_current_directory__" then
         raise Constraint_Error;
      end if;

      return Ada.Strings.Unbounded.To_String (Self.Physical_Text);
   end Physical_Current_Directory;

   overriding function Try_Physical_Current_Directory
     (Self : Capturing_Context;
      Path : out String;
      Last : out Natural) return Boolean
   is
      Physical : constant String := Ada.Strings.Unbounded.To_String (Self.Physical_Text);
   begin
      if Physical = "__raise_current_directory__" or else Physical'Length > Path'Length then
         Last := 0;
         return False;
      end if;

      Last := Physical'Length;
      if Last > 0 then
         Path (Path'First .. Path'First + Last - 1) := Physical;
      end if;

      return True;
   end Try_Physical_Current_Directory;

   overriding function Path_Names_Current_Directory (Self : Capturing_Context; Path : String) return Boolean is
      pragma Unreferenced (Path);
   begin
      return Self.Logical_Pwd_Matches;
   end Path_Names_Current_Directory;

   overriding function Standard_Output_Is_Terminal (Self : Capturing_Context) return Boolean is
   begin
      return Self.Output_Is_Terminal;
   end Standard_Output_Is_Terminal;

   procedure Set_Environment_Value (Self : in out Capturing_Context; Name, Value : String) is
   begin
      if Name = "PWD" then
         Self.Pwd_Text := Ada.Strings.Unbounded.To_Unbounded_String (Value);
      elsif Name = "LC_ALL" then
         Self.Locale_Text := Ada.Strings.Unbounded.To_Unbounded_String (Value);
      end if;
   end Set_Environment_Value;

   procedure Set_Locale (Self : in out Capturing_Context; Value : String) is
   begin
      Self.Locale_Text := Ada.Strings.Unbounded.To_Unbounded_String (Value);
   end Set_Locale;

   procedure Set_Logical_Pwd_Matches_Current_Directory (Self : in out Capturing_Context; Value : Boolean) is
   begin
      Self.Logical_Pwd_Matches := Value;
   end Set_Logical_Pwd_Matches_Current_Directory;

   procedure Set_Physical_Current_Directory (Self : in out Capturing_Context; Value : String) is
   begin
      Self.Physical_Text := Ada.Strings.Unbounded.To_Unbounded_String (Value);
   end Set_Physical_Current_Directory;

   procedure Set_Standard_Input (Self : in out Capturing_Context; Value : String) is
   begin
      Self.Input_Text := Ada.Strings.Unbounded.To_Unbounded_String (Value);
      Self.Input_Position := 1;
   end Set_Standard_Input;

   procedure Set_Standard_Input_Failure_After (Self : in out Capturing_Context; Byte_Count : Natural) is
   begin
      Self.Input_Failure_Enabled := True;
      Self.Input_Failure_Limit := Byte_Count;
   end Set_Standard_Input_Failure_After;

   procedure Set_Standard_Output_Is_Terminal (Self : in out Capturing_Context; Value : Boolean) is
   begin
      Self.Output_Is_Terminal := Value;
   end Set_Standard_Output_Is_Terminal;

   procedure Set_Output_Failure_After (Self : in out Capturing_Context; Byte_Count : Natural) is
   begin
      Self.Output_Failure_Enabled := True;
      Self.Output_Failure_Limit := Byte_Count;
   end Set_Output_Failure_After;

   function Output (Self : Capturing_Context) return String is
   begin
      return Ada.Strings.Unbounded.To_String (Self.Out_Text);
   end Output;

   function Error_Output (Self : Capturing_Context) return String is
   begin
      return Ada.Strings.Unbounded.To_String (Self.Err_Text);
   end Error_Output;
end Test_Contexts;
