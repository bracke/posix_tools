package body Posix_Tools.Streams.Bytes is

   function To_String
     (Buffer : Ada.Streams.Stream_Element_Array;
      Last   : Ada.Streams.Stream_Element_Offset) return String
   is
      Result : String (1 .. (if Last < Buffer'First then 0 else Natural (Last - Buffer'First + 1)));
   begin
      for I in Result'Range loop
         Result (I) := Character'Val (Buffer (Buffer'First + Ada.Streams.Stream_Element_Offset (I - 1)));
      end loop;

      return Result;
   end To_String;
end Posix_Tools.Streams.Bytes;
