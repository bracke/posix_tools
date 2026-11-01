with Ada.Streams;

--  Bytes read from a file or stream as the String the commands carry them
--  in, one Character per byte, nothing decoded.
package Posix_Tools.Streams.Bytes is
   use type Ada.Streams.Stream_Element_Offset;

   --  Buffer (Buffer'First .. Last) as a String indexed from 1; empty when
   --  Last is before Buffer'First.
   function To_String
     (Buffer : Ada.Streams.Stream_Element_Array;
      Last   : Ada.Streams.Stream_Element_Offset) return String
   with
     Pre  => Last <= Buffer'Last,
     Post => To_String'Result'First = 1;
end Posix_Tools.Streams.Bytes;
