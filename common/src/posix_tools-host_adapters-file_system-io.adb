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

   procedure Copy_Regular_File_With_Progress
     (Source : String;
      Target : String;
      Status : out Copy_File_Status)
   is
      use Hostkit.Descriptors;

      Copied  : Long_Long_Integer := 0;
      Stop    : Boolean := False;

      Input   : Descriptor := Invalid;
      Output  : Descriptor := Invalid;
      Buffer  : Byte_Buffer;
      Last    : Ada.Streams.Stream_Element_Offset;
      First   : Ada.Streams.Stream_Element_Offset;
      Written : Ada.Streams.Stream_Element_Offset;
      Outcome : Transfer_Outcome;

      --  Close both, the copy having ended as Ending: a target whose close
      --  fails may not hold what was written to it, and a copy that would
      --  otherwise have ended well ends as a failed write instead.
      procedure Finish (Ending : Copy_File_Status);

      procedure Finish (Ending : Copy_File_Status) is
         Closed : Boolean;
      begin
         Close (Input);
         Closed := Close (Output);
         Status := (if Ending = Copy_Ok and then not Closed then Target_Write_Failed else Ending);
      end Finish;
   begin
      --  The source is only read: its times are what reading leaves them,
      --  and a copy that keeps them takes them before it starts.
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
                              Finish (Target_Write_Failed);
                              return;
                           end if;

                           First := Written + 1;

                        when Transfer_Interrupted =>
                           null;

                        when others =>
                           Finish (Target_Write_Failed);
                           return;
                     end case;
                  end loop;

                  Copied := Copied + Long_Long_Integer (Last - Buffer'First + 1);
                  Progress (Copied, Stop);

                  if Stop then
                     Finish (Copy_Stopped);
                     return;
                  end if;
               end if;

            when Transfer_Interrupted =>
               null;

            when Transfer_End_Of_File =>
               Finish (Copy_Ok);
               return;

            when others =>
               Finish (Source_Read_Failed);
               return;
         end case;
      end loop;
   exception
      when others =>
         Close (Input);
         Close (Output);
         Status := Source_Read_Failed;
   end Copy_Regular_File_With_Progress;

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

      Ok := Close (Output);
   exception
      when others =>
         Close (Output);
         Ok := False;
   end Write_File;
end Posix_Tools.Host_Adapters.File_System.IO;
