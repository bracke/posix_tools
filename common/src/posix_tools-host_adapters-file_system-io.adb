with Ada.Streams;
with Hostkit.Descriptors;

package body Posix_Tools.Host_Adapters.File_System.IO is
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

   procedure Copy_Regular_File (Source : String; Target : String; Status : out Copy_File_Status) is
      use Hostkit.Descriptors;

      Input   : Descriptor := Invalid;
      Output  : Descriptor := Invalid;
      Buffer  : Byte_Buffer;
      Last    : Ada.Streams.Stream_Element_Offset;
      First   : Ada.Streams.Stream_Element_Offset;
      Written : Ada.Streams.Stream_Element_Offset;
      Outcome : Transfer_Outcome;
      Source_Access_Time       : File_Time;
      Source_Modification_Time : File_Time;
      Source_Times_Available   : constant Boolean :=
        File_Access_Time_From_File (Source, Source_Access_Time)
        and then File_Time_From_File (Source, Source_Modification_Time);

      procedure Close_All is
      begin
         Close (Input);
         Close (Output);
      end Close_All;

      procedure Restore_Source_Times is
      begin
         if Source_Times_Available then
            if not Set_File_Times (Source, Source_Access_Time, Source_Modification_Time) then
               null;
            end if;
         end if;
      end Restore_Source_Times;
   begin
      if not Open_File (Source, Open_Read, Input) then
         Status := Source_Open_Failed;
         return;
      end if;

      if not Open_File (Target, Open_Write_Truncate, Output) then
         Close (Input);
         Status := Target_Open_Failed;
         return;
      end if;

      loop
         Outcome := Read (Input, Buffer, Last);
         case Outcome is
            when Transfer_Ok =>
               if Last >= Buffer'First then
                  First := Buffer'First;
                  while First <= Last loop
                     Outcome := Write (Output, Buffer (First .. Last), Written);
                     case Outcome is
                        when Transfer_Ok =>
                           if Written < First then
                              Close_All;
                              Status := Target_Write_Failed;
                              return;
                           end if;

                           First := Written + 1;

                        when Transfer_Interrupted =>
                           null;

                        when others =>
                           Close_All;
                           Status := Target_Write_Failed;
                           return;
                     end case;
                  end loop;
               end if;

            when Transfer_Interrupted =>
               null;

            when Transfer_End_Of_File =>
               Close_All;
               Restore_Source_Times;
               Status := Copy_Ok;
               return;

            when others =>
               Close_All;
               Restore_Source_Times;
               Status := Source_Read_Failed;
               return;
         end case;
      end loop;
   exception
      when others =>
         Close_All;
         Status := Source_Read_Failed;
   end Copy_Regular_File;

   procedure Write_File
     (Path        : String;
      Text        : String;
      Append_Mode : Boolean;
      Ok          : out Boolean)
   is
      use Hostkit.Descriptors;

      Output  : Descriptor := Invalid;
      Buffer  : Ada.Streams.Stream_Element_Array
        (1 .. Ada.Streams.Stream_Element_Offset (Text'Length));
      Target  : Ada.Streams.Stream_Element_Offset := Buffer'First;
      First   : Ada.Streams.Stream_Element_Offset;
      Written : Ada.Streams.Stream_Element_Offset;
      Outcome : Transfer_Outcome;
   begin
      Ok :=
        Open_File
          (Path,
           (if Append_Mode and then Exists (Path) then Open_Write_Append else Open_Write_Truncate),
           Output);
      if not Ok then
         return;
      end if;

      if Text'Length > 0 then
         for Ch of Text loop
            Buffer (Target) := Ada.Streams.Stream_Element (Character'Pos (Ch));
            Target := Target + 1;
         end loop;

         First := Buffer'First;
         while First <= Buffer'Last loop
            Outcome := Write (Output, Buffer (First .. Buffer'Last), Written);
            case Outcome is
               when Transfer_Ok =>
                  if Written < First then
                     Close (Output);
                     Ok := False;
                     return;
                  end if;

                  First := Written + 1;

               when Transfer_Interrupted =>
                  null;

               when others =>
                  Close (Output);
                  Ok := False;
                  return;
            end case;
         end loop;
      end if;

      Close (Output);
      Ok := True;
   exception
      when others =>
         Close (Output);
         Ok := False;
   end Write_File;
end Posix_Tools.Host_Adapters.File_System.IO;
