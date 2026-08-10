with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Contexts;

package Test_Contexts is
   type Capturing_Context is new Posix_Tools.Commands.Contexts.Context with private;

   procedure Initialize
     (Self         : in out Capturing_Context;
      Command_Name : String;
      Arguments    : Posix_Tools.Arguments.Vector);

   overriding procedure Put (Self : in out Capturing_Context; Text : String);
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
   overriding function Environment_Value (Self : Capturing_Context; Name : String) return String;
   overriding function Effective_Locale (Self : Capturing_Context) return String;
   overriding function Physical_Current_Directory (Self : Capturing_Context) return String;
   overriding function Try_Physical_Current_Directory
     (Self : Capturing_Context;
      Path : out String;
      Last : out Natural) return Boolean;
   overriding function Path_Names_Current_Directory (Self : Capturing_Context; Path : String) return Boolean;
   overriding function Standard_Output_Is_Terminal (Self : Capturing_Context) return Boolean;

   procedure Set_Environment_Value (Self : in out Capturing_Context; Name, Value : String);
   procedure Set_Locale (Self : in out Capturing_Context; Value : String);
   procedure Set_Logical_Pwd_Matches_Current_Directory (Self : in out Capturing_Context; Value : Boolean);
   procedure Set_Physical_Current_Directory (Self : in out Capturing_Context; Value : String);
   procedure Set_Standard_Input (Self : in out Capturing_Context; Value : String);
   procedure Set_Standard_Input_Failure_After (Self : in out Capturing_Context; Byte_Count : Natural);
   procedure Set_Standard_Output_Is_Terminal (Self : in out Capturing_Context; Value : Boolean);
   procedure Set_Output_Failure_After (Self : in out Capturing_Context; Byte_Count : Natural);

   function Output (Self : Capturing_Context) return String;
   function Error_Output (Self : Capturing_Context) return String;

private
   type Capturing_Context is new Posix_Tools.Commands.Contexts.Context with record
      Out_Text : Ada.Strings.Unbounded.Unbounded_String;
      Err_Text : Ada.Strings.Unbounded.Unbounded_String;
      Pwd_Text : Ada.Strings.Unbounded.Unbounded_String;
      Locale_Text : Ada.Strings.Unbounded.Unbounded_String;
      Physical_Text : Ada.Strings.Unbounded.Unbounded_String;
      Input_Text : Ada.Strings.Unbounded.Unbounded_String;
      Input_Position : Natural := 1;
      Input_Failure_Enabled : Boolean := False;
      Input_Failure_Limit : Natural := 0;
      Output_Is_Terminal : Boolean := False;
      Logical_Pwd_Matches : Boolean := True;
      Output_Failure_Enabled : Boolean := False;
      Output_Failure_Limit : Natural := 0;
   end record;
end Test_Contexts;
