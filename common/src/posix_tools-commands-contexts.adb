with Posix_Tools.Host_Adapters.Clock;
with Posix_Tools.Host_Adapters.Environment;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Host_Adapters.Host;
with Posix_Tools.Host_Adapters.Processes;
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

   function Environment_Pairs (Self : Context) return Posix_Tools.Arguments.Vector is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Environment.Pairs;
   end Environment_Pairs;

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

   function Tail_Follow_Poll_Limit (Self : Context) return Natural is
      pragma Unreferenced (Self);
   begin
      return 0;
   end Tail_Follow_Poll_Limit;

   procedure Tail_Follow_Wait (Self : in out Context) is
      pragma Unreferenced (Self);
   begin
      delay 0.1;
   end Tail_Follow_Wait;

   procedure Tail_Follow_Watch_Path (Self : in out Context; Path : String) is
   begin
      Posix_Tools.Host_Adapters.File_Watches.Watch_Path (Self.Tail_Watch, Path);
   end Tail_Follow_Watch_Path;

   function Tail_Follow_Watch_Active (Self : Context) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_Watches.Is_Active (Self.Tail_Watch);
   end Tail_Follow_Watch_Active;

   function Tail_Follow_Watch_Changed (Self : in out Context) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_Watches.Changed (Self.Tail_Watch);
   end Tail_Follow_Watch_Changed;

   procedure Tail_Follow_Release_Watch (Self : in out Context) is
   begin
      Posix_Tools.Host_Adapters.File_Watches.Release (Self.Tail_Watch);
   end Tail_Follow_Release_Watch;

   function Tail_Memory_Threshold (Self : Context) return Posix_Tools.Numbers.Count is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Numbers.Count (16) * Posix_Tools.Numbers.Count (1024) * Posix_Tools.Numbers.Count (1024);
   end Tail_Memory_Threshold;

   function Set_System_Date_Time (Self : in out Context; Time : Ada.Calendar.Time) return Boolean is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Clock.Set_System_Time (Time);
   end Set_System_Date_Time;

   function Execute_Utility
     (Self        : in out Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean
   is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Processes.Run (Utility, Arguments, Exit_Status);
   end Execute_Utility;

   function Execute_Utility_With_Environment
     (Self        : in out Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Environment : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean
   is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Processes.Run_With_Environment
        (Utility, Arguments, Environment, Exit_Status);
   end Execute_Utility_With_Environment;

   function Execute_Utility_With_Timeout
     (Self        : in out Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Timeout_Ms  : Natural;
      Exit_Status : out Integer;
      Timed_Out   : out Boolean) return Boolean
   is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Processes.Run_With_Timeout
        (Utility, Arguments, Timeout_Ms, Exit_Status, Timed_Out);
   end Execute_Utility_With_Timeout;

   function Execute_Utility_With_Redirected_Output
     (Self            : in out Context;
      Utility         : String;
      Arguments       : Posix_Tools.Arguments.Vector;
      Output_Path     : String;
      Redirect_Output : Boolean;
      Redirect_Error  : Boolean;
      Exit_Status     : out Integer) return Boolean
   is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Processes.Run_With_Redirected_Output
        (Utility, Arguments, Output_Path, Redirect_Output, Redirect_Error, Exit_Status);
   end Execute_Utility_With_Redirected_Output;

   function Standard_Input_Is_Terminal (Self : Context) return Boolean is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Terminals.Standard_Input_Is_Terminal;
   end Standard_Input_Is_Terminal;

   function Standard_Input_Terminal_Name (Self : Context) return String is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Terminals.Standard_Input_Terminal_Name;
   end Standard_Input_Terminal_Name;

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

   function Current_System_Name (Self : Context) return String is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Host.System_Name;
   end Current_System_Name;

   function Current_Node_Name (Self : Context) return String is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Host.Node_Name;
   end Current_Node_Name;

   function Current_Release_Name (Self : Context) return String is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Host.Release_Name;
   end Current_Release_Name;

   function Current_Version_Name (Self : Context) return String is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Host.Version_Name;
   end Current_Version_Name;

   function Current_Machine_Name (Self : Context) return String is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Host.Machine_Name;
   end Current_Machine_Name;

   function Current_Login_Name (Self : Context) return String is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Host.Login_Name;
   end Current_Login_Name;

   function Set_Node_Name (Self : in out Context; Name : String) return Boolean is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Host.Set_Node_Name (Name);
   end Set_Node_Name;

   function Current_User_Id (Self : Context; User_Id : out Natural) return Boolean is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Host.Current_User_Id (User_Id);
   end Current_User_Id;

   function Current_Group_Id (Self : Context; Group_Id : out Natural) return Boolean is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Host.Current_Group_Id (Group_Id);
   end Current_Group_Id;

   function Current_Supplementary_Group_Ids
     (Self   : Context;
      Groups : out Posix_Tools.Host_Adapters.Host.Group_Id_List;
      Last   : out Natural) return Boolean
   is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Host.Current_Supplementary_Group_Ids (Groups, Last);
   end Current_Supplementary_Group_Ids;

   function Current_Group_Ids
     (Self   : Context;
      Groups : out Posix_Tools.Host_Adapters.Host.Group_Id_List;
      Last   : out Natural) return Boolean
   is
      Primary : Natural := 0;

      procedure Append_Group (Id : Natural) is
      begin
         for Index in 1 .. Last loop
            if Groups (Groups'First + Index - 1) = Id then
               return;
            end if;
         end loop;

         if Last < Groups'Length then
            Last := Last + 1;
            Groups (Groups'First + Last - 1) := Id;
         end if;
      end Append_Group;
   begin
      for Index in Groups'Range loop
         Groups (Index) := 0;
      end loop;
      Last := 0;

      if Self.Current_Group_Id (Primary) then
         Append_Group (Primary);
      end if;

      declare
         Raw_Groups : Posix_Tools.Host_Adapters.Host.Group_Id_List (1 .. Groups'Length);
         Raw_Last   : Natural := 0;
      begin
         if Self.Current_Supplementary_Group_Ids (Raw_Groups, Raw_Last) then
            for Index in 1 .. Raw_Last loop
               Append_Group (Raw_Groups (Index));
            end loop;
         end if;
      end;

      return Last > 0;
   end Current_Group_Ids;

   function User_Group_Ids
     (Self      : Context;
      User_Name : String;
      Groups    : out Posix_Tools.Host_Adapters.Host.Group_Id_List;
      Last      : out Natural) return Boolean
   is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.Host.User_Group_Ids (User_Name, Groups, Last);
   end User_Group_Ids;

   function User_Name_For_Id (Self : Context; User_Id : Natural) return String is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.File_System.User_Name_For_Id (User_Id);
   end User_Name_For_Id;

   function Group_Name_For_Id (Self : Context; Group_Id : Natural) return String is
      pragma Unreferenced (Self);
   begin
      return Posix_Tools.Host_Adapters.File_System.Group_Name_For_Id (Group_Id);
   end Group_Name_For_Id;

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

   procedure Put_Error (Self : in out Context; Text : String) is
   begin
      if not Posix_Tools.Host_Adapters.Streams.Write_Standard_Error (Text) then
         Self.Out_Failed := True;
      end if;
   end Put_Error;

   procedure Put_Line (Self : in out Context; Text : String) is
      Ok : Boolean;
   begin
      Posix_Tools.Host_Adapters.Streams.Write_Standard_Output_Line (Text, Ok);
      if not Ok then
         Self.Out_Failed := True;
      end if;
   end Put_Line;

   procedure Put_Error_Line (Self : in out Context; Text : String) is
      Ok : Boolean;
   begin
      Posix_Tools.Host_Adapters.Streams.Write_Standard_Error_Line (Text, Ok);
      if not Ok then
         Self.Out_Failed := True;
      end if;
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
