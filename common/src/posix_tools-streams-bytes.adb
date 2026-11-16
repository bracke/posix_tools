package body Posix_Tools.Streams.Bytes is

   function To_String
     (Buffer : Ada.Streams.Stream_Element_Array;
      Last   : Ada.Streams.Stream_Element_Offset) return String
   is
   begin
      if Last < Buffer'First then
         return "";
      end if;

      declare
         Result : constant String
           (1 .. Natural (Last - Buffer'First + 1))
           with Import, Address => Buffer (Buffer'First)'Address;
      begin
         return Result;
      end;
   end To_String;
end Posix_Tools.Streams.Bytes;
