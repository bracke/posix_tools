with Ada.Calendar;
with Ada.Streams;
with Posix_Tools.Arguments;
with Posix_Tools.Host_Adapters.File_Watches;
with Posix_Tools.Host_Adapters.Host;
with Posix_Tools.Numbers;

package Posix_Tools.Commands.Contexts is
   use type Ada.Streams.Stream_Element_Offset;

   type Context is tagged private;

   procedure Initialize
     (Self         : in out Context;
      Command_Name : String;
      Arguments    : Posix_Tools.Arguments.Vector);

   function Command_Name (Self : Context) return String;
   function Argument_Count (Self : Context) return Natural;
   function Argument (Self : Context; Index : Positive) return String;
   function Effective_Locale (Self : Context) return String;
   function Environment_Pairs (Self : Context) return Posix_Tools.Arguments.Vector;
   function Environment_Defined (Self : Context; Name : String) return Boolean;
   function Environment_Value (Self : Context; Name : String) return String;
   function Standard_Input_Is_Terminal (Self : Context) return Boolean;
   function Standard_Input_Terminal_Name (Self : Context) return String;
   function Standard_Output_Is_Terminal (Self : Context) return Boolean;
   function Standard_Error_Is_Terminal (Self : Context) return Boolean;
   function Current_System_Name (Self : Context) return String;
   function Current_Node_Name (Self : Context) return String;
   function Current_Release_Name (Self : Context) return String;
   function Current_Version_Name (Self : Context) return String;
   function Current_Machine_Name (Self : Context) return String;
   function Current_Login_Name (Self : Context) return String;
   function Set_Node_Name (Self : in out Context; Name : String) return Boolean;
   function Current_User_Id (Self : Context; User_Id : out Natural) return Boolean;
   function Current_Group_Id (Self : Context; Group_Id : out Natural) return Boolean;
   function Current_Supplementary_Group_Ids
     (Self   : Context;
      Groups : out Posix_Tools.Host_Adapters.Host.Group_Id_List;
      Last   : out Natural) return Boolean
     with Post => Last <= Groups'Length;
   function Current_Group_Ids
     (Self   : Context;
      Groups : out Posix_Tools.Host_Adapters.Host.Group_Id_List;
      Last   : out Natural) return Boolean
     with Post => Last <= Groups'Length;
   function User_Group_Ids
     (Self      : Context;
      User_Name : String;
      Groups    : out Posix_Tools.Host_Adapters.Host.Group_Id_List;
      Last      : out Natural) return Boolean
     with Post => Last <= Groups'Length;
   function User_Name_For_Id (Self : Context; User_Id : Natural) return String;
   function Group_Name_For_Id (Self : Context; Group_Id : Natural) return String;
   function Physical_Current_Directory (Self : Context) return String;
   function Try_Physical_Current_Directory
     (Self : Context;
      Path : out String;
      Last : out Natural) return Boolean;
   function Path_Names_Current_Directory (Self : Context; Path : String) return Boolean;
   function Tail_Follow_Poll_Limit (Self : Context) return Natural;
   procedure Tail_Follow_Wait (Self : in out Context);
   procedure Tail_Follow_Watch_Path (Self : in out Context; Path : String);
   function Tail_Follow_Watch_Active (Self : Context) return Boolean;
   function Tail_Follow_Watch_Changed (Self : in out Context) return Boolean;
   procedure Tail_Follow_Release_Watch (Self : in out Context);
   function Tail_Max_Spill_Bytes (Self : Context) return Posix_Tools.Numbers.Count;
   function Tail_Memory_Threshold (Self : Context) return Posix_Tools.Numbers.Count;
   function Set_System_Date_Time (Self : in out Context; Time : Ada.Calendar.Time) return Boolean;
   function Execute_Utility
     (Self        : in out Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean
     with
       Post =>
         (if not Execute_Utility'Result then
            Exit_Status in 126 .. 127);
   function Execute_Utility_With_Environment
     (Self        : in out Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Environment : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean
     with
       Post =>
       (if not Execute_Utility_With_Environment'Result then
          Exit_Status in 125 .. 127);
   function Execute_Utility_With_Nice_Adjustment
     (Self        : in out Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Adjustment  : Integer;
      Exit_Status : out Integer) return Boolean
     with
       Post =>
         (if not Execute_Utility_With_Nice_Adjustment'Result then
            Exit_Status in 125 .. 127);
   function Execute_Utility_With_Timeout
     (Self        : in out Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Timeout_Ms  : Natural;
      Exit_Status : out Integer;
      Timed_Out   : out Boolean) return Boolean
     with
       Post =>
         (if not Execute_Utility_With_Timeout'Result then
            Exit_Status in 125 .. 127);
   function Execute_Utility_With_Redirected_Output
     (Self            : in out Context;
      Utility         : String;
      Arguments       : Posix_Tools.Arguments.Vector;
      Output_Path     : String;
      Redirect_Output : Boolean;
      Redirect_Error  : Boolean;
      Exit_Status     : out Integer) return Boolean
     with
       Post =>
         (if not Execute_Utility_With_Redirected_Output'Result then
            Exit_Status in 125 .. 127);

   procedure Read_Standard_Input
     (Self   : in out Context;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
     with Post => Last < Buffer'First or else Last in Buffer'Range;
   function Try_Read_Standard_Input
     (Self   : in out Context;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset) return Boolean
     with Post => Last < Buffer'First or else Last in Buffer'Range;

   procedure Put (Self : in out Context; Text : String);
   procedure Put_Error (Self : in out Context; Text : String);
   procedure Put_Line (Self : in out Context; Text : String);
   procedure Put_Error_Line (Self : in out Context; Text : String);
   function Output_Failed (Self : Context) return Boolean;
   procedure Mark_Output_Failure (Self : in out Context);

private
   type Context is tagged record
      Name : Posix_Tools.Arguments.Vectors.Vector;
      Args : Posix_Tools.Arguments.Vector;
      Out_Failed : Boolean := False;
      Tail_Watch : Posix_Tools.Host_Adapters.File_Watches.Watch;
   end record;
end Posix_Tools.Commands.Contexts;
