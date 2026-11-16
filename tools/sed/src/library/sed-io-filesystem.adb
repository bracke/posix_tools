with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Unchecked_Deallocation;

package body Sed.IO.Filesystem is

   use Ada.Streams;
   package Stream_IO renames Ada.Streams.Stream_IO;

   --  Transfer size for bulk reads. Large enough that whole-file reads do not
   --  churn, small enough that a single record never forces a large stack
   --  frame; the buffer lives on the heap-free stack of one call.
   Chunk_Size : constant := 64 * 1024;

   procedure Free is new Ada.Unchecked_Deallocation
     (Ada.Streams.Stream_IO.File_Type, Stream_File_Access);

   --  Release a file that has not yet been transferred into Slots.  Open and
   --  Create may leave a handle open before a later allocation fails.
   procedure Release_Unclaimed (File : in out Stream_File_Access);

   --  Convert a String view back to raw bytes for writing.
   function To_Elements (Data : String) return Stream_Element_Array;

   --  Reserve a slot for a newly opened file and return its handle.
   procedure Claim_Slot
     (Self : in out Host_Filesystem;
      File : Stream_File_Access;
      Handle : out File_Handle);

   -----------------------
   -- Release_Unclaimed --
   -----------------------

   procedure Release_Unclaimed (File : in out Stream_File_Access) is
   begin
      if File = null then
         return;
      end if;

      begin
         if Stream_IO.Is_Open (File.all) then
            Stream_IO.Close (File.all);
         end if;
      exception
         when others =>
            --  intentional terminal exception barrier
            --  Setup already failed,
            --  so there is no useful secondary close error to report.
            null;
      end;
      Free (File);
   end Release_Unclaimed;

   -----------------
   -- To_Elements --
   -----------------

   function To_Elements (Data : String) return Stream_Element_Array is
      Result : Stream_Element_Array (1 .. Stream_Element_Offset (Data'Length));
      Target : Stream_Element_Offset := 1;
   begin
      for Item of Data loop
         Result (Target) := Stream_Element (Character'Pos (Item));
         Target := Target + 1;
      end loop;

      return Result;
   end To_Elements;

   ----------------
   -- Claim_Slot --
   ----------------

   procedure Claim_Slot
     (Self : in out Host_Filesystem;
      File : Stream_File_Access;
      Handle : out File_Handle) is
   begin
      for Index in 1 .. Natural (Self.Slots.Length) loop
         if Self.Slots (Index) = null then
            Handle := To_Handle (Index);
            Self.Slots (Index) := File;
            return;
         end if;
      end loop;

      declare
         Index : constant Positive :=
           Positive (Natural (Self.Slots.Length) + 1);
         New_Handle : constant File_Handle := To_Handle (Index);
      begin
         Self.Slots.Append (File);
         Handle := New_Handle;
      end;
   end Claim_Slot;

   ----------------
   -- Open_Input --
   ----------------

   overriding procedure Open_Input
     (Self : in out Host_Filesystem;
      Path : String;
      Handle : out File_Handle;
      Result : out IO_Result)
   is
      File : Stream_File_Access := null;
   begin
      Handle := Invalid_Handle;

      if Path'Length = 0 then
         Result := Failure (Not_Found);
         return;
      end if;

      File := new Stream_IO.File_Type;

      begin
         Stream_IO.Open (File.all, Stream_IO.In_File, Path);
      exception
         when Ada.IO_Exceptions.Name_Error =>
            Release_Unclaimed (File);
            Result := Failure (Not_Found);
            return;

         when Ada.IO_Exceptions.Use_Error =>
            Release_Unclaimed (File);
            --  Use_Error does not preserve a portable cause.  Report the
            --  actual open failure generically instead of restatting a path
            --  that may already name a different object.
            Result := Failure (IO_Failure);
            return;

         when Ada.IO_Exceptions.Status_Error =>
            Release_Unclaimed (File);
            Result := Failure (Permission_Denied);
            return;

         when Ada.IO_Exceptions.Device_Error =>
            Release_Unclaimed (File);
            Result := Failure (IO_Failure);
            return;
      end;

      Claim_Slot (Self, File, Handle);
      File := null;
      Result := Success_Result;
   exception
      when Ada.IO_Exceptions.Name_Error =>
         Release_Unclaimed (File);
         Handle := Invalid_Handle;
         Result := Failure (Not_Found);
      when Ada.IO_Exceptions.Use_Error =>
         Release_Unclaimed (File);
         Handle := Invalid_Handle;
         Result := Failure (Permission_Denied);
      when others =>
         --  intentional terminal exception barrier
         --  This is the host boundary.
         Release_Unclaimed (File);
         Handle := Invalid_Handle;
         Result := Failure (IO_Failure);
   end Open_Input;

   ----------
   -- Read --
   ----------

   overriding procedure Read
     (Self : in out Host_Filesystem;
      Handle : File_Handle;
      Into : out String;
      Last : out Natural;
      Result : out IO_Result)
   is
      Index : constant Natural := Slot_Of (Handle);
   begin
      Into := [others => ASCII.NUL];
      Last := Into'First - 1;

      if Index = 0
        or else Index > Natural (Self.Slots.Length)
        or else Self.Slots (Index) = null
      then
         Result := Failure (Already_Closed);
         return;
      end if;

      declare
         File : Stream_IO.File_Type renames Self.Slots (Index).all;
         Block : Stream_Element_Array
           (1 .. Stream_Element_Offset (Into'Length));
         Final : Stream_Element_Offset;
      begin
         Stream_IO.Read (File, Block, Final);

         if Final < Block'First then
            Result := (Status => End_Of_Data, Detail => U.Null_Unbounded_String);
            return;
         end if;

         for I in Block'First .. Final loop
            Into (Into'First + Natural (I - Block'First)) :=
              Character'Val (Block (I));
         end loop;
         Last := Into'First + Natural (Final - Block'First);

         Result := Success_Result;

      exception
         when Ada.IO_Exceptions.End_Error =>
            Result := (Status => End_Of_Data, Detail => U.Null_Unbounded_String);

         when Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.Data_Error =>
            Result := Failure (IO_Failure);

         when Ada.IO_Exceptions.Status_Error | Ada.IO_Exceptions.Mode_Error =>
            Result := Failure (Already_Closed);
      end;
   end Read;

   -----------------
   -- Close_Input --
   -----------------

   overriding procedure Close_Input
     (Self : in out Host_Filesystem;
      Handle : in out File_Handle)
   is
      Index : constant Natural := Slot_Of (Handle);
   begin
      if Index /= 0
        and then Index <= Natural (Self.Slots.Length)
        and then Self.Slots (Index) /= null
      then
         declare
            File : Stream_File_Access := Self.Slots (Index);
         begin
            begin
               if Stream_IO.Is_Open (File.all) then
                  Stream_IO.Close (File.all);
               end if;
            exception
               when others =>
                  --  intentional terminal exception barrier
                  --  Releasing an input handle has no recoverable error
                  --  channel.
                  --  Releasing a read handle cannot lose data, so a close
                  --  fault here has no observable effect to report.
                  null;
            end;

            Free (File);
            Self.Slots (Index) := null;
         end;
      end if;

      Handle := Invalid_Handle;
   end Close_Input;

   ---------------------
   -- Read_Whole_File --
   ---------------------

   overriding procedure Read_Whole_File
     (Self : in out Host_Filesystem;
      Path : String;
      Content : out U.Unbounded_String;
      Result : out IO_Result)
   is
      Handle : File_Handle;
      Buffer : String (1 .. Chunk_Size);
      Last : Natural;
      Step : IO_Result;
   begin
      Content := U.Null_Unbounded_String;
      Open_Input (Self, Path, Handle, Result);

      if Is_Failure (Result) then
         return;
      end if;

      loop
         Read (Self, Handle, Buffer, Last, Step);

         exit when Step.Status = End_Of_Data;

         if Is_Failure (Step) then
            Close_Input (Self, Handle);
            Content := U.Null_Unbounded_String;
            Result := Step;
            return;
         end if;

         if Last >= Buffer'First then
            U.Append (Content, Buffer (Buffer'First .. Last));
         end if;
      end loop;

      Close_Input (Self, Handle);
      Result := Success_Result;
   end Read_Whole_File;

   -------------------
   -- Create_Output --
   -------------------

   overriding procedure Create_Output
     (Self : in out Host_Filesystem;
      Path : String;
      Handle : out File_Handle;
      Result : out IO_Result)
   is
      File : Stream_File_Access := null;
   begin
      Handle := Invalid_Handle;

      if Path'Length = 0 then
         Result := Failure (Not_Found);
         return;
      end if;

      File := new Stream_IO.File_Type;

      begin
         Stream_IO.Create (File.all, Stream_IO.Out_File, Path);
      exception
         when Ada.IO_Exceptions.Name_Error =>
            Release_Unclaimed (File);
            Result := Failure (Not_Found);
            return;

         when Ada.IO_Exceptions.Use_Error =>
            Release_Unclaimed (File);
            --  The failed create is authoritative.  Reclassifying Path here
            --  would race with replacement and could describe another entry.
            Result := Failure (IO_Failure);
            return;

         when Ada.IO_Exceptions.Status_Error =>
            Release_Unclaimed (File);
            Result := Failure (Permission_Denied);
            return;

         when Ada.IO_Exceptions.Device_Error =>
            Release_Unclaimed (File);
            Result := Failure (IO_Failure);
            return;
      end;

      Claim_Slot (Self, File, Handle);
      File := null;
      Result := Success_Result;

   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
         Release_Unclaimed (File);
         Handle := Invalid_Handle;
         Result := Failure (Permission_Denied);
      when others =>
         --  intentional terminal exception barrier
         --  This is the host boundary.
         Release_Unclaimed (File);
         Handle := Invalid_Handle;
         Result := Failure (IO_Failure);
   end Create_Output;

   -----------
   -- Write --
   -----------

   overriding procedure Write
     (Self : in out Host_Filesystem;
      Handle : File_Handle;
      Data : String;
      Result : out IO_Result)
   is
      Index : constant Natural := Slot_Of (Handle);
   begin
      if Index = 0
        or else Index > Natural (Self.Slots.Length)
        or else Self.Slots (Index) = null
      then
         Result := Failure (Already_Closed);
         return;
      end if;

      if Data'Length = 0 then
         Result := Success_Result;
         return;
      end if;

      begin
         Stream_IO.Write (Self.Slots (Index).all, To_Elements (Data));
         Result := Success_Result;
      exception
         when Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.Use_Error =>
            Result := Failure (IO_Failure);

         when Ada.IO_Exceptions.Status_Error | Ada.IO_Exceptions.Mode_Error =>
            Result := Failure (Already_Closed);
      end;
   end Write;

   ------------------
   -- Close_Output --
   ------------------

   overriding procedure Close_Output
     (Self : in out Host_Filesystem;
      Handle : in out File_Handle;
      Result : out IO_Result)
   is
      Index : constant Natural := Slot_Of (Handle);
   begin
      Result := Success_Result;

      if Index = 0
        or else Index > Natural (Self.Slots.Length)
        or else Self.Slots (Index) = null
      then
         Handle := Invalid_Handle;
         Result := Failure (Already_Closed);
         return;
      end if;

      declare
         File : Stream_File_Access := Self.Slots (Index);
      begin
         begin
            if Stream_IO.Is_Open (File.all) then
               Stream_IO.Close (File.all);
            end if;
         exception
            when Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.Use_Error =>
               --  A close fault on an output file can mean buffered data was
               --  never written, so it must reach the caller.
               Result := Failure (IO_Failure);

            when others =>
               --  intentional terminal exception barrier
               Result := Failure (IO_Failure);
         end;

         Free (File);
         Self.Slots (Index) := null;
      end;

      Handle := Invalid_Handle;
   end Close_Output;

   ----------------
   -- Open_Count --
   ----------------

   function Open_Count (Self : Host_Filesystem) return Natural is
      Count : Natural := 0;
   begin
      for Slot of Self.Slots loop
         if Slot /= null then
            Count := Count + 1;
         end if;
      end loop;

      return Count;
   end Open_Count;

   --------------
   -- Finalize --
   --------------

   overriding procedure Finalize (Self : in out Host_Filesystem) is
   begin
      for Index in 1 .. Natural (Self.Slots.Length) loop
         if Self.Slots (Index) /= null then
            declare
               File : Stream_File_Access := Self.Slots (Index);
            begin
               begin
                  if Stream_IO.Is_Open (File.all) then
                     Stream_IO.Close (File.all);
                  end if;
               exception
                  when others =>
                     --  intentional terminal exception barrier
                     --  Finalization has no error channel and must release
                     --  the slot.
                     null;
               end;

               Free (File);
               Self.Slots (Index) := null;
            end;
         end if;
      end loop;
   end Finalize;

end Sed.IO.Filesystem;
