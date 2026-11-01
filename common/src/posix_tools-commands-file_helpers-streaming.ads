with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Contexts;

package Posix_Tools.Commands.File_Helpers.Streaming is
   --  Each chunk read from File_Name, standard input for "-", in turn. A
   --  read failure is reported. Unless Stop_On_Output_Failure is False, as
   --  for tee, which writes on to its files, a failed output ends the read.
   generic
      with procedure Action
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset);
      Stop_On_Output_Failure : Boolean := True;
   procedure For_Each_Chunk
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Ok        : out Boolean);

   procedure Read_All
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Data      : out Ada.Strings.Unbounded.Unbounded_String;
      Ok        : out Boolean);

   --  The whole of File_Name, standard input for "-". Ok is False, and a
   --  read failure has been reported, when it could not all be read.
   function Read_File
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Ok        : out Boolean) return String;

   procedure Copy_Standard_Input
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Ok      : out Boolean);
end Posix_Tools.Commands.File_Helpers.Streaming;
