with Ada.Streams;

package Posix_Tools.Host_Adapters.Streams is
   use type Ada.Streams.Stream_Element_Offset;

   procedure Read_Standard_Input
     (Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   with
     Post =>
       Last < Buffer'First
       or else Last in Buffer'Range;

   function Try_Read_Standard_Input
     (Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset) return Boolean
   with
     Post =>
       Last < Buffer'First
       or else Last in Buffer'Range;

   function Write_Standard_Output (Text : String) return Boolean;
   function Write_Standard_Error (Text : String) return Boolean;

   procedure Write_Standard_Output_Line (Text : String; Ok : out Boolean);

   procedure Write_Standard_Error_Line (Text : String; Ok : out Boolean);
end Posix_Tools.Host_Adapters.Streams;
