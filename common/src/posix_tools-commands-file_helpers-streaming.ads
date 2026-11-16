with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Host_Adapters.File_System;

package Posix_Tools.Commands.File_Helpers.Streaming is
   Bulk_Buffer_Length : constant Positive := 64 * 1024;

   --  Each chunk read from File_Name, standard input for "-", in turn. A
   --  read failure is reported. Unless Stop_On_Output_Failure is False, as
   --  for tee, which writes on to its files, a failed output ends the read.
   --  A non-null Stop_Requested is polled after each action so bounded
   --  consumers can end input promptly after reaching their own limit.
   generic
      with procedure Action
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset);
      Buffer_Length : Positive := 16 * 1024;
      Stop_On_Output_Failure : Boolean := True;
   procedure For_Each_Chunk
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Ok        : out Boolean;
      Stop_Requested : access function return Boolean := null);

   generic
      with procedure Action
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset);
      Stop_On_Output_Failure : Boolean := True;
   procedure For_Each_Follow_Chunk
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      File    : in out Posix_Tools.Host_Adapters.File_System.Follow_File;
      Ok      : out Boolean;
      Stop_Requested : access function return Boolean := null);

   --  Call Action for each LF-delimited record without retaining the whole
   --  input. Line excludes LF; Terminated distinguishes a final partial
   --  record from a newline-terminated one.
   generic
      with procedure Action
        (Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
         Line       : String;
         Terminated : Boolean);
      Buffer_Length : Positive := 16 * 1024;
   procedure For_Each_Line
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
