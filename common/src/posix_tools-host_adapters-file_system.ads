with Ada.Streams;

package Posix_Tools.Host_Adapters.File_System is
   function Can_Open_For_Read (Path : String) return Boolean;

   function Path_Names_Current_Directory (Path : String) return Boolean;

   generic
      with procedure Action
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);
   procedure For_Each_File_Chunk
     (Path   : String;
      Ok     : out Boolean);

   function Physical_Current_Directory return String;
   function Try_Physical_Current_Directory (Path : out String; Last : out Natural) return Boolean;
end Posix_Tools.Host_Adapters.File_System;
