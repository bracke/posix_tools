with Posix_Tools.Host_Adapters.Environment;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Host_Adapters.Streams;
with Posix_Tools.Host_Adapters.Terminals;

package body Posix_Tools.Commands.Contexts is
   use type Posix_Tools.Numbers.Count;

   procedure Initialize
     (Self         : in out Context;
      Command_Name : String;
      Arguments    : Posix_Tools.Arguments.Vector)
   is
   begin
      Self.Name.Clear;
      Self.Name.Append (Command_Name);
      Self.Args := Arguments;
      Self.Out_Failed := False;
   end Initialize;

   function Command_Name (Self : Context) return String is
   begin
      if Self.Name.Is_Empty then
         return "";
      end if;

      return Self.Name.First_Element;
   end Command_Name;

   function Argument_Count (Self : Context) return Natural is
   begin
      return Natural (Self.Args.Length);
   end Argument_Count;

   function Argument (Self : Context; Index : Positive) return String is
   begin
      return Self.Args.Element (Index);
   end Argument;

   function Environment_Value (Self : Context; Name : String) return String is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Environment.Value (Name);
   end Environment_Value;

   function Effective_Locale (Self : Context) return String is
      LC_All      : constant String := Self.Environment_Value ("LC_ALL");
      LC_Messages : constant String := Self.Environment_Value ("LC_MESSAGES");
      Lang        : constant String := Self.Environment_Value ("LANG");
   begin
      if LC_All /= "" then
         return LC_All;
      elsif LC_Messages /= "" then
         return LC_Messages;
      elsif Lang /= "" then
         return Lang;
      else
         return "en";
      end if;
   end Effective_Locale;

   function Physical_Current_Directory (Self : Context) return String is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.File_System.Physical_Current_Directory;
   end Physical_Current_Directory;

   function Try_Physical_Current_Directory
     (Self : Context;
      Path : out String;
      Last : out Natural) return Boolean
   is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.File_System.Try_Physical_Current_Directory (Path, Last);
   end Try_Physical_Current_Directory;

   function Path_Names_Current_Directory (Self : Context; Path : String) return Boolean is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.File_System.Path_Names_Current_Directory (Path);
   end Path_Names_Current_Directory;

   function Tail_Max_Spill_Bytes (Self : Context) return Posix_Tools.Numbers.Count is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Numbers.Count (1024) * Posix_Tools.Numbers.Count (1024) * Posix_Tools.Numbers.Count (1024);
   end Tail_Max_Spill_Bytes;

   function Tail_Memory_Threshold (Self : Context) return Posix_Tools.Numbers.Count is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Numbers.Count (16) * Posix_Tools.Numbers.Count (1024) * Posix_Tools.Numbers.Count (1024);
   end Tail_Memory_Threshold;

   function Tail_Follow_Max_Polls (Self : Context) return Natural is
      pragma Unreferenced (Self);
   begin
      return Natural'Last;
   end Tail_Follow_Max_Polls;

   procedure Wait_For_Tail_Follow_Poll (Self : in out Context) is
      pragma Unreferenced (Self);
   begin
      delay 1.0;
   end Wait_For_Tail_Follow_Poll;

   function Standard_Output_Is_Terminal (Self : Context) return Boolean is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Terminals.Standard_Output_Is_Terminal;
   end Standard_Output_Is_Terminal;

   function Standard_Error_Is_Terminal (Self : Context) return Boolean is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Terminals.Standard_Error_Is_Terminal;
   end Standard_Error_Is_Terminal;

   procedure Read_Standard_Input
     (Self   : in out Context;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is
      pragma Unreferenced (Self);
   begin
      Posix_Tools.Host_Adapters.Streams.Read_Standard_Input (Buffer, Last);
   end Read_Standard_Input;

   function Try_Read_Standard_Input
     (Self   : in out Context;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset) return Boolean
   is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Streams.Try_Read_Standard_Input (Buffer, Last);
   end Try_Read_Standard_Input;

   procedure Put (Self : in out Context; Text : String) is
   begin
      if not Posix_Tools.Host_Adapters.Streams.Write_Standard_Output (Text) then
         Self.Out_Failed := True;
      end if;
   end Put;

   procedure Put_Line (Self : in out Context; Text : String) is
      Ok : Boolean;
   begin
      Posix_Tools.Host_Adapters.Streams.Write_Standard_Output_Line (Text, Ok);
      if not Ok then
         Self.Out_Failed := True;
      end if;
   end Put_Line;

   procedure Put_Error_Line (Self : in out Context; Text : String) is
      pragma Unreferenced (Self);
   begin
      Posix_Tools.Host_Adapters.Streams.Write_Standard_Error_Line (Text);
   end Put_Error_Line;

   function Output_Failed (Self : Context) return Boolean is
   begin
      return Self.Out_Failed;
   end Output_Failed;

   procedure Mark_Output_Failure (Self : in out Context) is
   begin
      Self.Out_Failed := True;
   end Mark_Output_Failure;
end Posix_Tools.Commands.Contexts;
