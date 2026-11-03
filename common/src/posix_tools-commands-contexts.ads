with Ada.Calendar;
with Ada.Streams;
with Posix_Tools.Arguments;
with Posix_Tools.Host_Adapters.File_Watches;
with Posix_Tools.Host_Adapters.Host;
with Posix_Tools.Numbers;

package Posix_Tools.Commands.Contexts is
   use type Ada.Streams.Stream_Element_Offset;

   --  Capability interfaces keep helpers and tests from depending on the
   --  entire command runtime when they need only one service family.
   type Invocation_Context is interface;
   function Command_Name (Self : Invocation_Context) return String is abstract;
   function Argument_Count (Self : Invocation_Context) return Natural is abstract;
   function Argument
     (Self : Invocation_Context; Index : Positive) return String is abstract;
   function Argument_Vector
     (Self : Invocation_Context) return Posix_Tools.Arguments.Vector is abstract;

   type Environment_Context is interface;
   function Default_Locale (Self : Environment_Context) return String is abstract;
   function Environment_Pairs
     (Self : Environment_Context) return Posix_Tools.Arguments.Vector is abstract;
   function Environment_Defined
     (Self : Environment_Context; Name : String) return Boolean is abstract;
   function Environment_Value
     (Self : Environment_Context; Name : String) return String is abstract;
   function Effective_Locale (Self : Environment_Context) return String is abstract;

   type Stream_Context is interface;
   function Standard_Input_Is_Terminal
     (Self : Stream_Context) return Boolean is abstract;
   function Standard_Input_Terminal_Name
     (Self : Stream_Context) return String is abstract;
   function Standard_Output_Is_Terminal
     (Self : Stream_Context) return Boolean is abstract;
   function Standard_Error_Is_Terminal
     (Self : Stream_Context) return Boolean is abstract;
   procedure Read_Standard_Input
     (Self   : in out Stream_Context;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset) is abstract
     with Post'Class => Last < Buffer'First or else Last in Buffer'Range;
   function Try_Read_Standard_Input
     (Self   : in out Stream_Context;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset) return Boolean is abstract
     with Post'Class => Last < Buffer'First or else Last in Buffer'Range;
   procedure Put
     (Self : in out Stream_Context; Text : String) is abstract;
   procedure Put_Error
     (Self : in out Stream_Context; Text : String) is abstract;
   procedure Put_Line
     (Self : in out Stream_Context; Text : String) is abstract;
   procedure Put_Error_Line
     (Self : in out Stream_Context; Text : String) is abstract;
   function Output_Failed (Self : Stream_Context) return Boolean is abstract;
   procedure Mark_Output_Failure (Self : in out Stream_Context) is abstract;

   type Host_Context is interface;
   function Current_System_Name (Self : Host_Context) return String is abstract;
   function Current_Node_Name (Self : Host_Context) return String is abstract;
   function Current_Release_Name (Self : Host_Context) return String is abstract;
   function Current_Version_Name (Self : Host_Context) return String is abstract;
   function Current_Machine_Name (Self : Host_Context) return String is abstract;
   function Current_Login_Name (Self : Host_Context) return String is abstract;
   function Set_Node_Name
     (Self : in out Host_Context; Name : String) return Boolean is abstract;
   function Current_User_Id
     (Self : Host_Context; User_Id : out Natural) return Boolean is abstract;
   function Current_Group_Id
     (Self : Host_Context; Group_Id : out Natural) return Boolean is abstract;
   function Current_Supplementary_Group_Ids
     (Self   : Host_Context;
      Groups : out Posix_Tools.Host_Adapters.Host.Group_Id_List;
      Last   : out Natural) return Boolean is abstract
     with Post'Class => Last <= Groups'Length;
   function Current_Group_Ids
     (Self   : Host_Context;
      Groups : out Posix_Tools.Host_Adapters.Host.Group_Id_List;
      Last   : out Natural) return Boolean is abstract
     with Post'Class => Last <= Groups'Length;
   function User_Group_Ids
     (Self      : Host_Context;
      User_Name : String;
      Groups    : out Posix_Tools.Host_Adapters.Host.Group_Id_List;
      Last      : out Natural) return Boolean is abstract
     with Post'Class => Last <= Groups'Length;
   function User_Name_For_Id
     (Self : Host_Context; User_Id : Natural) return String is abstract;
   function Group_Name_For_Id
     (Self : Host_Context; Group_Id : Natural) return String is abstract;
   function Physical_Current_Directory
     (Self : Host_Context) return String is abstract;
   function Try_Physical_Current_Directory
     (Self : Host_Context;
      Path : out String;
      Last : out Natural) return Boolean is abstract
     with Post'Class =>
       (if Try_Physical_Current_Directory'Result then
          Last <= Path'Length
        else
          Last = 0);
   function Path_Names_Current_Directory
     (Self : Host_Context; Path : String) return Boolean is abstract;
   function Set_System_Date_Time
     (Self : in out Host_Context; Time : Ada.Calendar.Time) return Boolean is abstract;

   type Tail_Context is interface;
   function Tail_Follow_Poll_Limit
     (Self : Tail_Context) return Natural is abstract;
   procedure Tail_Follow_Wait (Self : in out Tail_Context) is abstract;
   procedure Tail_Follow_Watch_Path
     (Self : in out Tail_Context; Path : String) is abstract;
   function Tail_Follow_Watch_Active
     (Self : Tail_Context) return Boolean is abstract;
   function Tail_Follow_Watch_Changed
     (Self : in out Tail_Context) return Boolean is abstract;
   procedure Tail_Follow_Release_Watch
     (Self : in out Tail_Context) is abstract;
   function Tail_Max_Spill_Bytes
     (Self : Tail_Context) return Posix_Tools.Numbers.Count is abstract;
   function Tail_Memory_Threshold
     (Self : Tail_Context) return Posix_Tools.Numbers.Count is abstract;

   type Process_Context is interface;
   function Execute_Utility
     (Self        : in out Process_Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean is abstract
     with Post'Class => (if not Execute_Utility'Result then Exit_Status in 126 .. 127);
   function Execute_Utility_With_Environment
     (Self        : in out Process_Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Environment : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean is abstract
     with Post'Class =>
       (if not Execute_Utility_With_Environment'Result then Exit_Status in 125 .. 127);
   function Execute_Utility_With_Nice_Adjustment
     (Self        : in out Process_Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Adjustment  : Integer;
      Exit_Status : out Integer) return Boolean is abstract
     with Post'Class =>
       (if not Execute_Utility_With_Nice_Adjustment'Result then Exit_Status in 125 .. 127);
   function Execute_Utility_With_Timeout
     (Self        : in out Process_Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Timeout_Ms  : Natural;
      Exit_Status : out Integer;
      Timed_Out   : out Boolean) return Boolean is abstract
     with Post'Class =>
       (if not Execute_Utility_With_Timeout'Result then Exit_Status in 125 .. 127);
   function Execute_Utility_With_Redirected_Output
     (Self            : in out Process_Context;
      Utility         : String;
      Arguments       : Posix_Tools.Arguments.Vector;
      Output_Path     : String;
      Redirect_Output : Boolean;
      Redirect_Error  : Boolean;
      Exit_Status     : out Integer) return Boolean is abstract
     with Post'Class =>
       (if not Execute_Utility_With_Redirected_Output'Result then Exit_Status in 125 .. 127);

   type Diagnostic_Context is interface
     and Invocation_Context
     and Environment_Context
     and Stream_Context;

   type Context is new Diagnostic_Context
     and Host_Context
     and Tail_Context
     and Process_Context with private;

   --  The locale categories a command consults.
   type Locale_Category is (Character_Classification, Collation, Messages, Numeric, Time);

   procedure Initialize
     (Self         : in out Context;
      Command_Name : String;
      Arguments    : Posix_Tools.Arguments.Vector);

   function Command_Name (Self : Context) return String;
   function Argument_Count (Self : Context) return Natural;
   function Argument (Self : Context; Index : Positive) return String;
   --  All of the arguments, in order: what Argument gives one at a time.
   function Argument_Vector (Self : Context) return Posix_Tools.Arguments.Vector;
   --  The locale of Category as POSIX settles it: LC_ALL, else the
   --  category's own variable (LC_CTYPE, LC_COLLATE, LC_MESSAGES,
   --  LC_NUMERIC or LC_TIME), else LANG, else Default_Locale.
   function Category_Locale (Self : Context'Class; Category : Locale_Category) return String;
   --  The locale when no environment variable names one.
   function Default_Locale (Self : Context) return String;
   --  The locale help and diagnostics are written in: the Messages one.
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
   overriding function Current_Group_Ids
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
   overriding function Try_Physical_Current_Directory
     (Self : Context;
      Path : out String;
      Last : out Natural) return Boolean
     with Post =>
       (if Try_Physical_Current_Directory'Result then
          Last <= Path'Length
        else
          Last = 0);
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
   type Context is new Diagnostic_Context
     and Host_Context
     and Tail_Context
     and Process_Context with record
      Name : Posix_Tools.Arguments.Vectors.Vector;
      Args : Posix_Tools.Arguments.Vector;
      Out_Failed : Boolean := False;
      Tail_Watch : Posix_Tools.Host_Adapters.File_Watches.Watch;
   end record;
end Posix_Tools.Commands.Contexts;
