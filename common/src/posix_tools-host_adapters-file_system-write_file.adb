separate (Posix_Tools.Host_Adapters.File_System)
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
        (if Append_Mode and then Exists (Path)
         then Open_Write_Append
         else Open_Write_Truncate),
        Output);
   if not Ok then
      return;
   end if;

   if Text'Length > 0 then
      for Ch of Text loop
         Buffer (Target) :=
           Ada.Streams.Stream_Element (Character'Pos (Ch));
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
