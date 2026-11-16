separate (Posix_Tools.Host_Adapters.File_System)
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
   Buffer  : Bulk_Byte_Buffer;
   Last    : Ada.Streams.Stream_Element_Offset;
   First   : Ada.Streams.Stream_Element_Offset;
   Written : Ada.Streams.Stream_Element_Offset;
   Outcome : Transfer_Outcome;
   Callback_Active : aliased Boolean := False;

   procedure Close_Safely (File : in out Descriptor);
   procedure Report_Progress;

   procedure Close_Safely (File : in out Descriptor) is
   begin
      Close (File);
   exception
      when others =>
         --  intentional terminal exception barrier
         --  Cleanup must not replace the exception raised by client code.
         null;
   end Close_Safely;

   procedure Report_Progress is
   begin
      Callback_Active := True;
      Progress (Copied, Stop);
      Callback_Active := False;
   end Report_Progress;

   --  Close both, the copy having ended as Ending: a target whose close
   --  fails may not hold what was written to it, and a copy that would
   --  otherwise have ended well ends as a failed write instead.
   procedure Finish (Ending : Copy_File_Status);

   procedure Finish (Ending : Copy_File_Status) is
      Closed : Boolean;
   begin
      Close (Input);
      Closed := Close (Output);
      Status :=
        (if Ending = Copy_Ok and then not Closed
         then Target_Write_Failed
         else Ending);
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

               Copied := Copied
                 + Long_Long_Integer (Last - Buffer'First + 1);
               Report_Progress;

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
      declare
         Callback_Failed : constant Boolean := Callback_Active;
      begin
         Close_Safely (Input);
         Close_Safely (Output);

         if Callback_Failed then
            raise;
         end if;

         Status := Source_Read_Failed;
      end;
end Copy_Regular_File_With_Progress;
