with Ada.Streams;
with Posix_Tools.Arguments;
with Posix_Tools.Numbers;

package Posix_Tools.Commands.Contexts is
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
   function Environment_Value (Self : Context; Name : String) return String;
   function Standard_Input_Is_Terminal (Self : Context) return Boolean;
   function Standard_Output_Is_Terminal (Self : Context) return Boolean;
   function Standard_Error_Is_Terminal (Self : Context) return Boolean;
   function Physical_Current_Directory (Self : Context) return String;
   function Try_Physical_Current_Directory
     (Self : Context;
      Path : out String;
      Last : out Natural) return Boolean;
   function Path_Names_Current_Directory (Self : Context; Path : String) return Boolean;
   function Tail_Max_Spill_Bytes (Self : Context) return Posix_Tools.Numbers.Count;
   function Tail_Memory_Threshold (Self : Context) return Posix_Tools.Numbers.Count;
   function Execute_Utility
     (Self        : in out Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean;
   function Execute_Utility_With_Environment
     (Self        : in out Context;
      Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Environment : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean;

   procedure Read_Standard_Input
     (Self   : in out Context;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset);
   function Try_Read_Standard_Input
     (Self   : in out Context;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset) return Boolean;

   procedure Put (Self : in out Context; Text : String);
   procedure Put_Line (Self : in out Context; Text : String);
   procedure Put_Error_Line (Self : in out Context; Text : String);
   function Output_Failed (Self : Context) return Boolean;
   procedure Mark_Output_Failure (Self : in out Context);

private
   type Context is tagged record
      Name : Posix_Tools.Arguments.Vectors.Vector;
      Args : Posix_Tools.Arguments.Vector;
      Out_Failed : Boolean := False;
   end record;
end Posix_Tools.Commands.Contexts;
