with Posix_Tools.Commands.Contexts;
with Posix_Tools.Numbers;

--  Line and chunk streaming of operands is in the Streaming child, and
--  line suffixes in the Tailing child.
package Posix_Tools.Commands.File_Helpers is
   type Line_Action is access procedure
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Line    : String);
   --  Line is a byte-preserving segment. For file operands it includes the
   --  LF delimiter when one was read, and omits it for a final partial line.

   function Simple_Name (Path : String) return String;

   function Target_Path
     (Source              : String;
      Target              : String;
      Target_Is_Directory : Boolean) return String;

   function Is_Directory (Path : String) return Boolean;

   function Remove_Non_Directory_Target (Path : String) return Boolean;

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
