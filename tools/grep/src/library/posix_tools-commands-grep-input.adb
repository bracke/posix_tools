with Ada.IO_Exceptions;

package body Posix_Tools.Commands.Grep.Input is
   overriding procedure Read
     (Stream : in out Standard_Input_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset) is
   begin
      if not Stream.Context.Try_Read_Standard_Input (Item, Last) then
         raise Ada.IO_Exceptions.Device_Error with "standard input read failed";
      end if;
   end Read;

   overriding procedure Write
     (Stream : in out Standard_Input_Stream;
      Item   : Ada.Streams.Stream_Element_Array)
   is
      pragma Unreferenced (Stream, Item);
   begin
      raise Ada.IO_Exceptions.Mode_Error with "standard input is not written";
   end Write;
end Posix_Tools.Commands.Grep.Input;
