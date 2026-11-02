with Ada.Streams;
with Posix_Tools.Commands.Contexts;

--  Standard input, read through the command context, as the Ada stream
--  greplib searches. Each read returns what one read of the context
--  delivers, so lines arriving on a pipe are searched as they arrive.
package Posix_Tools.Commands.Grep.Input is
   type Standard_Input_Stream (Context : not null access Posix_Tools.Commands.Contexts.Context'Class) is
     new Ada.Streams.Root_Stream_Type with null record;

   --  A failed read raises Ada.IO_Exceptions.Device_Error, which greplib
   --  reports as a read failure of the source.
   overriding procedure Read
     (Stream : in out Standard_Input_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset);

   --  Standard input is not written: raises Ada.IO_Exceptions.Mode_Error.
   overriding procedure Write
     (Stream : in out Standard_Input_Stream;
      Item   : Ada.Streams.Stream_Element_Array);
end Posix_Tools.Commands.Grep.Input;
