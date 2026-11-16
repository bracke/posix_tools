package body Posix_Tools.Host_Adapters.Input_Files is
   use Hostkit.Descriptors;

   procedure Advance_After_Error
     (File    : Input_File;
      Count   : Posix_Tools.Numbers.Count;
      Outcome : out Recovery_Outcome) is
   begin
      Outcome :=
        (case Hostkit.Descriptors.Advance
           (File.Descriptor, Long_Long_Integer (Count)) is
            when Hostkit.Descriptors.Advance_Complete     => Recovery_Advanced,
            when Hostkit.Descriptors.Advance_Not_Seekable => Recovery_Not_Seekable,
            when Hostkit.Descriptors.Advance_Failed       => Recovery_Failed);
   exception
      when others =>
         --  intentional terminal exception barrier
         Outcome := Recovery_Failed;
   end Advance_After_Error;

   procedure Close (File : in out Input_File; Ok : out Boolean) is
   begin
      Ok := Close (File.Descriptor);
   end Close;

   overriding procedure Finalize (File : in out Input_File) is
      Closed : Boolean;
   begin
      Close (File, Closed);
   end Finalize;

   function Is_Open (File : Input_File) return Boolean is
     (Is_Valid (File.Descriptor));

   procedure Open (File : in out Input_File; Path : String; Ok : out Boolean) is
   begin
      Close (File.Descriptor);
      Ok := Open_File (Path, Open_Read, File.Descriptor);
      if not Ok then
         Close (File.Descriptor);
      end if;
   exception
      when others =>
         --  intentional terminal exception barrier
         Close (File.Descriptor);
         Ok := False;
   end Open;

   procedure Read
     (File    : Input_File;
      Buffer  : out Ada.Streams.Stream_Element_Array;
      Last    : out Ada.Streams.Stream_Element_Offset;
      Outcome : out Read_Outcome) is
   begin
      loop
         case Hostkit.Descriptors.Read (File.Descriptor, Buffer, Last) is
            when Transfer_Ok =>
               Outcome := Read_Complete;
               return;
            when Transfer_Interrupted =>
               null;
            when Transfer_End_Of_File =>
               Last := Buffer'First - 1;
               Outcome := Read_End;
               return;
            when others =>
               Last := Buffer'First - 1;
               Outcome := Read_Failed;
               return;
         end case;
      end loop;
   exception
      when others =>
         --  intentional terminal exception barrier
         Last := Buffer'First - 1;
         Outcome := Read_Failed;
   end Read;
end Posix_Tools.Host_Adapters.Input_Files;
