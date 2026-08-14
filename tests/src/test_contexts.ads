with Ada.Calendar;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Host_Adapters.Host;
with Posix_Tools.Numbers;

package Test_Contexts is
   type Capturing_Context is new Posix_Tools.Commands.Contexts.Context with private;

   procedure Initialize
     (Self         : in out Capturing_Context;
      Command_Name : String;
      Arguments    : Posix_Tools.Arguments.Vector);

   overriding procedure Put (Self : in out Capturing_Context; Text : String);
   overriding procedure Put_Error (Self : in out Capturing_Context; Text : String);
   overriding procedure Put_Line (Self : in out Capturing_Context; Text : String);
   overriding procedure Put_Error_Line (Self : in out Capturing_Context; Text : String);
   overriding procedure Read_Standard_Input
     (Self   : in out Capturing_Context;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset);
   overriding function Try_Read_Standard_Input
     (Self   : in out Capturing_Context;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset) return Boolean;
   overriding function Environment_Pairs
     (Self : Capturing_Context) return Posix_Tools.Arguments.Vector;
   overriding function Environment_Value (Self : Capturing_Context; Name : String) return String;
   overriding function Effective_Locale (Self : Capturing_Context) return String;
   overriding function Physical_Current_Directory (Self : Capturing_Context) return String;
   overriding function Try_Physical_Current_Directory
     (Self : Capturing_Context;
      Path : out String;
      Last : out Natural) return Boolean;
   overriding function Path_Names_Current_Directory (Self : Capturing_Context; Path : String) return Boolean;
   overriding function Standard_Input_Is_Terminal (Self : Capturing_Context) return Boolean;
   overriding function Standard_Input_Terminal_Name (Self : Capturing_Context) return String;
   overriding function Standard_Output_Is_Terminal (Self : Capturing_Context) return Boolean;
   overriding function Standard_Error_Is_Terminal (Self : Capturing_Context) return Boolean;
   overriding function Current_Node_Name (Self : Capturing_Context) return String;
   overriding function Set_Node_Name (Self : in out Capturing_Context; Name : String) return Boolean;
   overriding function Current_Group_Ids
     (Self   : Capturing_Context;
      Groups : out Posix_Tools.Host_Adapters.Host.Group_Id_List;
      Last   : out Natural) return Boolean;
   overriding function User_Group_Ids
     (Self      : Capturing_Context;
      User_Name : String;
      Groups    : out Posix_Tools.Host_Adapters.Host.Group_Id_List;
      Last      : out Natural) return Boolean;
   overriding function Tail_Follow_Poll_Limit (Self : Capturing_Context) return Natural;
   overriding procedure Tail_Follow_Wait (Self : in out Capturing_Context);
   overriding function Tail_Max_Spill_Bytes (Self : Capturing_Context) return Posix_Tools.Numbers.Count;
   overriding function Tail_Memory_Threshold (Self : Capturing_Context) return Posix_Tools.Numbers.Count;
   overriding function Set_System_Date_Time
     (Self : in out Capturing_Context;
      Time : Ada.Calendar.Time) return Boolean;
   overriding function Execute_Utility
     (Self        : in out Capturing_Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean;
   overriding function Execute_Utility_With_Environment
     (Self        : in out Capturing_Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Environment : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean;
   overriding function Execute_Utility_With_Timeout
     (Self        : in out Capturing_Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Timeout_Ms  : Natural;
      Exit_Status : out Integer;
      Timed_Out   : out Boolean) return Boolean;
   overriding function Execute_Utility_With_Redirected_Output
     (Self            : in out Capturing_Context;
      Utility         : String;
      Arguments       : Posix_Tools.Arguments.Vector;
      Output_Path     : String;
      Redirect_Output : Boolean;
      Redirect_Error  : Boolean;
      Exit_Status     : out Integer) return Boolean;

   procedure Set_Environment_Value (Self : in out Capturing_Context; Name, Value : String);
   procedure Set_Locale (Self : in out Capturing_Context; Value : String);
   procedure Set_Logical_Pwd_Matches_Current_Directory (Self : in out Capturing_Context; Value : Boolean);
   procedure Set_Physical_Current_Directory (Self : in out Capturing_Context; Value : String);
   procedure Set_Standard_Input (Self : in out Capturing_Context; Value : String);
   procedure Set_Standard_Input_Failure_After (Self : in out Capturing_Context; Byte_Count : Natural);
   procedure Set_Standard_Input_Is_Terminal (Self : in out Capturing_Context; Value : Boolean);
   procedure Set_Standard_Output_Is_Terminal (Self : in out Capturing_Context; Value : Boolean);
   procedure Set_Standard_Error_Is_Terminal (Self : in out Capturing_Context; Value : Boolean);
   procedure Set_Node_Name_Allowed (Self : in out Capturing_Context; Value : Boolean);
   function Node_Name_Set_Called (Self : Capturing_Context) return Boolean;
   function Captured_Node_Name (Self : Capturing_Context) return String;
   function Redirected_Output_Path (Self : Capturing_Context) return String;
   function Redirected_Output_Enabled (Self : Capturing_Context) return Boolean;
   function Redirected_Error_Enabled (Self : Capturing_Context) return Boolean;
   procedure Set_Output_Failure_After (Self : in out Capturing_Context; Byte_Count : Natural);
   procedure Set_Tail_Follow_Append
     (Self       : in out Capturing_Context;
      Path       : String;
      After_Wait : Natural;
      Text       : String);
   procedure Set_Tail_Follow_Replace
     (Self       : in out Capturing_Context;
      Path       : String;
      After_Wait : Natural;
      Text       : String);
   procedure Set_Tail_Follow_Poll_Limit (Self : in out Capturing_Context; Value : Natural);
   procedure Set_Tail_Resource_Limits
     (Self             : in out Capturing_Context;
      Memory_Threshold : Posix_Tools.Numbers.Count;
      Max_Spill_Bytes  : Posix_Tools.Numbers.Count);
   procedure Set_Date_Set_Allowed (Self : in out Capturing_Context; Value : Boolean);
   function Date_Set_Called (Self : Capturing_Context) return Boolean;

   function Output (Self : Capturing_Context) return String;
   function Error_Output (Self : Capturing_Context) return String;

private
   type Capturing_Context is new Posix_Tools.Commands.Contexts.Context with record
      Out_Text : Ada.Strings.Unbounded.Unbounded_String;
      Err_Text : Ada.Strings.Unbounded.Unbounded_String;
      Pwd_Text : Ada.Strings.Unbounded.Unbounded_String;
      Locale_Text : Ada.Strings.Unbounded.Unbounded_String;
      Env_Vars : Posix_Tools.Arguments.Vector;
      Physical_Text : Ada.Strings.Unbounded.Unbounded_String;
      Input_Text : Ada.Strings.Unbounded.Unbounded_String;
      Input_Position : Natural := 1;
      Input_Failure_Enabled : Boolean := False;
      Input_Failure_Limit : Natural := 0;
      Input_Is_Terminal : Boolean := False;
      Input_Terminal_Name : Ada.Strings.Unbounded.Unbounded_String;
      Output_Is_Terminal : Boolean := False;
      Error_Is_Terminal : Boolean := False;
      Node_Name_Text : Ada.Strings.Unbounded.Unbounded_String;
      Node_Name_Set_Allowed : Boolean := False;
      Node_Name_Set_Done : Boolean := False;
      Redirect_Path : Ada.Strings.Unbounded.Unbounded_String;
      Redirect_Output : Boolean := False;
      Redirect_Error : Boolean := False;
      Logical_Pwd_Matches : Boolean := True;
      Output_Failure_Enabled : Boolean := False;
      Output_Failure_Limit : Natural := 0;
      Tail_Follow_Limit : Natural := 0;
      Tail_Follow_Waits : Natural := 0;
      Tail_Append_Path : Ada.Strings.Unbounded.Unbounded_String;
      Tail_Append_Text : Ada.Strings.Unbounded.Unbounded_String;
      Tail_Append_After : Natural := 0;
      Tail_Append_Done : Boolean := True;
      Tail_Append_Replaces : Boolean := False;
      Tail_Memory_Bytes : Posix_Tools.Numbers.Count := Posix_Tools.Numbers.Count (16 * 1024 * 1024);
      Tail_Spill_Bytes : Posix_Tools.Numbers.Count := Posix_Tools.Numbers.Count (1024 * 1024 * 1024);
      Date_Set_Allowed : Boolean := False;
      Date_Set_Done : Boolean := False;
   end record;
end Test_Contexts;
