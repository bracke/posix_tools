with Ada.Streams;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Numbers;

package Posix_Tools.Commands.File_Helpers is
   type Line_Action is access procedure
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Line    : String);
   --  Line is a byte-preserving segment. For file operands it includes the
   --  LF delimiter when one was read, and omits it for a final partial line.

   procedure For_Each_Line
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Action    : Line_Action;
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

   procedure Copy_File
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Ok        : out Boolean);

   procedure Copy_Line_Prefix
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Lines     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean);

   procedure Copy_Byte_Prefix
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Bytes     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean);

   procedure Copy_Line_Suffix
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Lines     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean);

   procedure Copy_Lines_From
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      First     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean);

   procedure Copy_Standard_Input
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Ok      : out Boolean);
end Posix_Tools.Commands.File_Helpers;
