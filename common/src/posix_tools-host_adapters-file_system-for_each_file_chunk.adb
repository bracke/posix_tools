separate (Posix_Tools.Host_Adapters.File_System)
procedure For_Each_File_Chunk
  (Path   : String;
   Ok     : out Boolean)
is
   use Hostkit.Descriptors;
   File   : Descriptor := Invalid;
   Buffer : Ada.Streams.Stream_Element_Array
     (1 .. Ada.Streams.Stream_Element_Offset (Buffer_Length));
   Last   : Ada.Streams.Stream_Element_Offset;
   Stop   : Boolean := False;
   Outcome : Transfer_Outcome;
   Callback_Active : aliased Boolean := False;

   procedure Close_Safely;

   procedure Invoke_Action is new Invoke_Chunk_Callback
     (Callback => Action);

   procedure Close_Safely is
   begin
      Close (File);
   exception
      when others =>
         --  intentional terminal exception barrier
         --  Cleanup must not replace an exception raised by client code.
         null;
   end Close_Safely;
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
               Invoke_Action (Buffer, Last, Stop, Callback_Active'Access);
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
      Close_Safely;
      if Callback_Active then
         raise;
      end if;
      Ok := False;
end For_Each_File_Chunk;
