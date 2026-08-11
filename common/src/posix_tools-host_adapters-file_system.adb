with Hostkit.Descriptors;
with Hostkit.Metadata;
with Ada.Directories;

package body Posix_Tools.Host_Adapters.File_System is
   use type Ada.Streams.Stream_Element_Offset;

   Buffer_Size : constant := 16 * 1024;
   subtype Byte_Buffer is Ada.Streams.Stream_Element_Array (1 .. Buffer_Size);

   function Can_Open_For_Read (Path : String) return Boolean is
      use Hostkit.Descriptors;
      File : Descriptor := Invalid;
   begin
      if not Open_File (Path, Open_Read, File) then
         return False;
      end if;

      Close (File);
      return True;
   exception
      when others =>
         Close (File);
         return False;
   end Can_Open_For_Read;

   procedure For_Each_File_Chunk
     (Path   : String;
      Ok     : out Boolean)
   is
      use Hostkit.Descriptors;
      File   : Descriptor := Invalid;
      Buffer : Byte_Buffer;
      Last   : Ada.Streams.Stream_Element_Offset;
      Stop   : Boolean := False;
      Outcome : Transfer_Outcome;
   begin
      Ok := Open_File (Path, Open_Read, File);
      if not Ok then
         return;
      end if;

      while not Stop loop
         Outcome := Read (File, Buffer, Last);
         case Outcome is
            when Transfer_Ok =>
               if Last >= Buffer'First then
                  Action (Buffer, Last, Stop);
               end if;

            when Transfer_Interrupted =>
               null;

            when Transfer_End_Of_File =>
               exit;

            when others =>
               Ok := False;
               exit;
         end case;
      end loop;

      Close (File);
   exception
      when others =>
         Close (File);
         Ok := False;
   end For_Each_File_Chunk;

   function Physical_Current_Directory return String is
   begin
      return Ada.Directories.Current_Directory;
   end Physical_Current_Directory;

   function Try_Physical_Current_Directory (Path : out String; Last : out Natural) return Boolean is
      Current : constant String := Physical_Current_Directory;
   begin
      if Current'Length > Path'Length then
         Last := 0;
         return False;
      end if;

      Last := Current'Length;
      if Last > 0 then
         Path (Path'First .. Path'First + Last - 1) := Current;
      end if;

      return True;
   exception
      when others =>
         Last := 0;
         return False;
   end Try_Physical_Current_Directory;

   function Path_Names_Current_Directory (Path : String) return Boolean is
   begin
      return Hostkit.Metadata.Same_File (Path, Physical_Current_Directory);
   exception
      when others =>
         return False;
   end Path_Names_Current_Directory;
end Posix_Tools.Host_Adapters.File_System;
