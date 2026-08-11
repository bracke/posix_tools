with Ada.Streams;
with Posix_Tools.Numbers;

package Posix_Tools.Host_Adapters.File_System is
   function Can_Open_For_Read (Path : String) return Boolean;

   function File_Size
     (Path : String;
      Size : out Posix_Tools.Numbers.Count) return Boolean;

   function Path_Names_Current_Directory (Path : String) return Boolean;

   generic
      with procedure Action
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);
   procedure For_Each_File_Chunk
     (Path   : String;
      Ok     : out Boolean);

   generic
      with procedure Action
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);
   procedure For_Each_File_Chunk_From
     (Path       : String;
      Start_Byte : Posix_Tools.Numbers.Count;
      New_Size   : out Posix_Tools.Numbers.Count;
      Ok         : out Boolean);

   function Physical_Current_Directory return String;
   function Try_Physical_Current_Directory (Path : out String; Last : out Natural) return Boolean;
end Posix_Tools.Host_Adapters.File_System;
