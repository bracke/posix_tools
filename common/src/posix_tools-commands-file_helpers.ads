with Posix_Tools.Commands.Contexts;
with Posix_Tools.Numbers;

--  Line and chunk streaming of operands is in the Streaming child, and
--  line suffixes in the Tailing child.
package Posix_Tools.Commands.File_Helpers is
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
end Posix_Tools.Commands.File_Helpers;
