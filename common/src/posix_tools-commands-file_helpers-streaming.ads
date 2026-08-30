with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Contexts;

package Posix_Tools.Commands.File_Helpers.Streaming is
   procedure For_Each_Line
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Action    : Posix_Tools.Commands.File_Helpers.Line_Action;
      Ok        : out Boolean);

   generic
      with procedure Action
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset);
   procedure For_Each_Chunk
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Ok        : out Boolean);

   procedure Read_All
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Data      : out Ada.Strings.Unbounded.Unbounded_String;
      Ok        : out Boolean);

   function Read_File
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Ok        : out Boolean) return String;

   function Read_Standard_Input
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class) return String;

   procedure Copy_Standard_Input
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Ok      : out Boolean);

   procedure Write_File
     (Path        : String;
      Text        : String;
      Append_Mode : Boolean;
      Ok          : out Boolean);
end Posix_Tools.Commands.File_Helpers.Streaming;
