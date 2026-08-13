with Ada.Streams.Stream_IO;

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
      Self.Env_Vars.Clear;
      Self.Physical_Text := Ada.Strings.Unbounded.To_Unbounded_String ("/physical");
      Self.Input_Text := Ada.Strings.Unbounded.Null_Unbounded_String;
      Self.Input_Position := 1;
      Self.Input_Failure_Enabled := False;
      Self.Input_Failure_Limit := 0;
      Self.Input_Is_Terminal := False;
      Self.Output_Is_Terminal := False;
      Self.Error_Is_Terminal := False;
      Self.Logical_Pwd_Matches := True;
      Self.Output_Failure_Enabled := False;
      Self.Output_Failure_Limit := 0;
      Self.Tail_Follow_Limit := 0;
      Self.Tail_Follow_Waits := 0;
      Self.Tail_Append_Path := Ada.Strings.Unbounded.Null_Unbounded_String;
      Self.Tail_Append_Text := Ada.Strings.Unbounded.Null_Unbounded_String;
      Self.Tail_Append_After := 0;
      Self.Tail_Append_Done := True;
      Self.Tail_Append_Replaces := False;
      Self.Tail_Memory_Bytes := Posix_Tools.Numbers.Count (16 * 1024 * 1024);
      Self.Tail_Spill_Bytes := Posix_Tools.Numbers.Count (1024 * 1024 * 1024);
      Self.Date_Set_Allowed := False;
      Self.Date_Set_Done := False;
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
      Current_Length : constant Natural := Ada.Strings.Unbounded.Length (Self.Err_Text);
      Line           : constant String := Text & Character'Val (10);
      Remaining      : Natural;
   begin
      if Self.Output_Failure_Enabled then
         if Current_Length >= Self.Output_Failure_Limit then
            Posix_Tools.Commands.Contexts.Mark_Output_Failure
              (Posix_Tools.Commands.Contexts.Context (Self));
            return;
         end if;

         Remaining := Self.Output_Failure_Limit - Current_Length;
         if Line'Length > Remaining then
            if Remaining > 0 then
               Ada.Strings.Unbounded.Append (Self.Err_Text, Line (Line'First .. Line'First + Remaining - 1));
            end if;
            Posix_Tools.Commands.Contexts.Mark_Output_Failure
              (Posix_Tools.Commands.Contexts.Context (Self));
            return;
         end if;
      end if;

      Ada.Strings.Unbounded.Append (Self.Err_Text, Line);
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

   overriding function Environment_Pairs
     (Self : Capturing_Context) return Posix_Tools.Arguments.Vector is
   begin
      return Self.Env_Vars;
   end Environment_Pairs;

   overriding function Environment_Value (Self : Capturing_Context; Name : String) return String is
   begin
      for I in reverse 1 .. Natural (Self.Env_Vars.Length) loop
         declare
            Pair : constant String := Self.Env_Vars.Element (I);
         begin
            if Pair'Length > Name'Length
              and then Pair (Pair'First .. Pair'First + Name'Length - 1) = Name
              and then Pair (Pair'First + Name'Length) = '='
            then
               return Pair (Pair'First + Name'Length + 1 .. Pair'Last);
            end if;
         end;
      end loop;
      return "";
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

   overriding function Standard_Input_Is_Terminal (Self : Capturing_Context) return Boolean is
   begin
      return Self.Input_Is_Terminal;
   end Standard_Input_Is_Terminal;

   overriding function Standard_Output_Is_Terminal (Self : Capturing_Context) return Boolean is
   begin
      return Self.Output_Is_Terminal;
   end Standard_Output_Is_Terminal;

   overriding function Standard_Error_Is_Terminal (Self : Capturing_Context) return Boolean is
   begin
      return Self.Error_Is_Terminal;
   end Standard_Error_Is_Terminal;

   overriding function Tail_Follow_Poll_Limit (Self : Capturing_Context) return Natural is
   begin
      return Self.Tail_Follow_Limit;
   end Tail_Follow_Poll_Limit;

   overriding procedure Tail_Follow_Wait (Self : in out Capturing_Context) is
      package Stream_IO renames Ada.Streams.Stream_IO;
      File : Stream_IO.File_Type;
      Text : constant String := Ada.Strings.Unbounded.To_String (Self.Tail_Append_Text);
      Path : constant String := Ada.Strings.Unbounded.To_String (Self.Tail_Append_Path);
      Data : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Text'Length));
   begin
      Self.Tail_Follow_Waits := Self.Tail_Follow_Waits + 1;
      if not Self.Tail_Append_Done
        and then Self.Tail_Follow_Waits >= Self.Tail_Append_After
        and then Path /= ""
      then
         for I in Text'Range loop
            Data (Ada.Streams.Stream_Element_Offset (I - Text'First + 1)) :=
              Ada.Streams.Stream_Element (Character'Pos (Text (I)));
         end loop;
         if Self.Tail_Append_Replaces then
            Stream_IO.Create (File, Stream_IO.Out_File, Path);
         else
            Stream_IO.Open (File, Stream_IO.Append_File, Path);
         end if;
         if Text /= "" then
            Stream_IO.Write (File, Data);
         end if;
         Stream_IO.Close (File);
         Self.Tail_Append_Done := True;
      end if;
   end Tail_Follow_Wait;

   overriding function Tail_Max_Spill_Bytes (Self : Capturing_Context) return Posix_Tools.Numbers.Count is
   begin
      return Self.Tail_Spill_Bytes;
   end Tail_Max_Spill_Bytes;

   overriding function Tail_Memory_Threshold (Self : Capturing_Context) return Posix_Tools.Numbers.Count is
   begin
      return Self.Tail_Memory_Bytes;
   end Tail_Memory_Threshold;

   overriding function Set_System_Date_Time
     (Self : in out Capturing_Context;
      Time : Ada.Calendar.Time) return Boolean
   is
      pragma Unreferenced (Time);
   begin
      Self.Date_Set_Done := Self.Date_Set_Allowed;
      return Self.Date_Set_Allowed;
   end Set_System_Date_Time;

   overriding function Execute_Utility
     (Self        : in out Capturing_Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean
   is
   begin
      if Utility = "echo" then
         for I in 1 .. Natural (Arguments.Length) loop
            if I > 1 then
               Put (Self, " ");
            end if;
            Put (Self, Arguments.Element (I));
         end loop;
         Put_Line (Self, "");
         Exit_Status := 0;
         return True;
      elsif Utility = "true" then
         Exit_Status := 0;
         return True;
      elsif Utility = "false" then
         Exit_Status := 1;
         return True;
      elsif Utility = "xargs-cannot-invoke" then
         Exit_Status := 126;
         return True;
      elsif Utility = "xargs-status-127" then
         Exit_Status := 127;
         return True;
      elsif Utility = "xargs-status-255" then
         Exit_Status := 255;
         return True;
      else
         Exit_Status := 127;
         return False;
      end if;
   end Execute_Utility;

   overriding function Execute_Utility_With_Environment
     (Self        : in out Capturing_Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Environment : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean
   is
      function Environment_Value (Name : String) return String is
      begin
         for I in reverse 1 .. Natural (Environment.Length) loop
            declare
               Pair : constant String := Environment.Element (I);
            begin
               if Pair'Length > Name'Length
                 and then Pair (Pair'First .. Pair'First + Name'Length - 1) = Name
                 and then Pair (Pair'First + Name'Length) = '='
               then
                  return Pair (Pair'First + Name'Length + 1 .. Pair'Last);
               end if;
            end;
         end loop;
         return "";
      end Environment_Value;
   begin
      if Utility = "printenv" then
         for I in 1 .. Natural (Arguments.Length) loop
            Put_Line (Self, Environment_Value (Arguments.Element (I)));
         end loop;
         Exit_Status := 0;
         return True;
      else
         return Execute_Utility (Self, Utility, Arguments, Exit_Status);
      end if;
   end Execute_Utility_With_Environment;

   procedure Set_Environment_Value (Self : in out Capturing_Context; Name, Value : String) is
      Pair : constant String := Name & "=" & Value;
   begin
      for I in 1 .. Natural (Self.Env_Vars.Length) loop
         declare
            Existing : constant String := Self.Env_Vars.Element (I);
         begin
            if Existing'Length > Name'Length
              and then Existing (Existing'First .. Existing'First + Name'Length - 1) = Name
              and then Existing (Existing'First + Name'Length) = '='
            then
               Self.Env_Vars.Replace_Element (I, Pair);
               if Name = "PWD" then
                  Self.Pwd_Text := Ada.Strings.Unbounded.To_Unbounded_String (Value);
               elsif Name = "LC_ALL" then
                  Self.Locale_Text := Ada.Strings.Unbounded.To_Unbounded_String (Value);
               end if;
               return;
            end if;
         end;
      end loop;
      Self.Env_Vars.Append (Pair);
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

   procedure Set_Standard_Input_Is_Terminal (Self : in out Capturing_Context; Value : Boolean) is
   begin
      Self.Input_Is_Terminal := Value;
   end Set_Standard_Input_Is_Terminal;

   procedure Set_Standard_Output_Is_Terminal (Self : in out Capturing_Context; Value : Boolean) is
   begin
      Self.Output_Is_Terminal := Value;
   end Set_Standard_Output_Is_Terminal;

   procedure Set_Standard_Error_Is_Terminal (Self : in out Capturing_Context; Value : Boolean) is
   begin
      Self.Error_Is_Terminal := Value;
   end Set_Standard_Error_Is_Terminal;

   procedure Set_Output_Failure_After (Self : in out Capturing_Context; Byte_Count : Natural) is
   begin
      Self.Output_Failure_Enabled := True;
      Self.Output_Failure_Limit := Byte_Count;
   end Set_Output_Failure_After;

   procedure Set_Tail_Follow_Append
     (Self       : in out Capturing_Context;
      Path       : String;
      After_Wait : Natural;
      Text       : String)
   is
   begin
      Self.Tail_Append_Path := Ada.Strings.Unbounded.To_Unbounded_String (Path);
      Self.Tail_Append_Text := Ada.Strings.Unbounded.To_Unbounded_String (Text);
      Self.Tail_Append_After := After_Wait;
      Self.Tail_Append_Done := False;
      Self.Tail_Append_Replaces := False;
   end Set_Tail_Follow_Append;

   procedure Set_Tail_Follow_Replace
     (Self       : in out Capturing_Context;
      Path       : String;
      After_Wait : Natural;
      Text       : String)
   is
   begin
      Self.Tail_Append_Path := Ada.Strings.Unbounded.To_Unbounded_String (Path);
      Self.Tail_Append_Text := Ada.Strings.Unbounded.To_Unbounded_String (Text);
      Self.Tail_Append_After := After_Wait;
      Self.Tail_Append_Done := False;
      Self.Tail_Append_Replaces := True;
   end Set_Tail_Follow_Replace;

   procedure Set_Tail_Follow_Poll_Limit (Self : in out Capturing_Context; Value : Natural) is
   begin
      Self.Tail_Follow_Limit := Value;
   end Set_Tail_Follow_Poll_Limit;

   procedure Set_Tail_Resource_Limits
     (Self             : in out Capturing_Context;
      Memory_Threshold : Posix_Tools.Numbers.Count;
      Max_Spill_Bytes  : Posix_Tools.Numbers.Count)
   is
   begin
      Self.Tail_Memory_Bytes := Memory_Threshold;
      Self.Tail_Spill_Bytes := Max_Spill_Bytes;
   end Set_Tail_Resource_Limits;

   procedure Set_Date_Set_Allowed (Self : in out Capturing_Context; Value : Boolean) is
   begin
      Self.Date_Set_Allowed := Value;
   end Set_Date_Set_Allowed;

   function Date_Set_Called (Self : Capturing_Context) return Boolean is
   begin
      return Self.Date_Set_Done;
   end Date_Set_Called;

   function Output (Self : Capturing_Context) return String is
   begin
      return Ada.Strings.Unbounded.To_String (Self.Out_Text);
   end Output;

   function Error_Output (Self : Capturing_Context) return String is
   begin
      return Ada.Strings.Unbounded.To_String (Self.Err_Text);
   end Error_Output;
end Test_Contexts;
