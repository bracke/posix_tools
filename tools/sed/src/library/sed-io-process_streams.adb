with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Text_IO.Text_Streams;
with Posix_Tools.Host_Adapters.Streams;
with Posix_Tools.Host_Adapters.Terminals;

package body Sed.IO.Process_Streams is

   use Ada.Streams;

   ---------------------------
   -- Descriptor_Is_Terminal --
   ---------------------------

   function Descriptor_Is_Terminal (Descriptor : Natural) return Boolean is
   begin
      case Descriptor is
         when 0 =>
            return Posix_Tools.Host_Adapters.Terminals.Standard_Input_Is_Terminal;
         when 1 =>
            return Posix_Tools.Host_Adapters.Terminals.Standard_Output_Is_Terminal;
         when 2 =>
            return Posix_Tools.Host_Adapters.Terminals.Standard_Error_Is_Terminal;
         when others =>
            return False;
      end case;
   end Descriptor_Is_Terminal;

   -----------
   -- Write --
   -----------

   overriding procedure Write
     (Self : in out Process_Output;
      Data : String;
      Result : out IO_Result) is
      Written : Boolean;
   begin
      if Data'Length = 0 then
         Result := Success_Result;
         return;
      end if;

      case Self.Channel is
         when Output_Channel =>
            Written :=
              Posix_Tools.Host_Adapters.Streams.Write_Standard_Output (Data);

         when Error_Channel =>
            Written :=
              Posix_Tools.Host_Adapters.Streams.Write_Standard_Error (Data);
      end case;

      if Written then
         Result := Success_Result;
      else
         Result := Failure (IO_Failure);
      end if;

   exception
      when Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.Use_Error =>
         --  A closed pipe or a full device reaches the caller as a structured
         --  failure; it never escapes as an unhandled exception with a
         --  traceback.
         Result := Failure (IO_Failure);

      when Ada.IO_Exceptions.Status_Error | Ada.IO_Exceptions.Mode_Error =>
         Result := Failure (Already_Closed);
   end Write;

   -----------
   -- Flush --
   -----------

   overriding procedure Flush
     (Self : in out Process_Output;
      Result : out IO_Result) is
   begin
      case Self.Channel is
         when Output_Channel =>
            Ada.Text_IO.Flush (Ada.Text_IO.Standard_Output);

         when Error_Channel =>
            Ada.Text_IO.Flush (Ada.Text_IO.Standard_Error);
      end case;

      Result := Success_Result;

   exception
      when Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.Use_Error =>
         Result := Failure (IO_Failure);

      when Ada.IO_Exceptions.Status_Error | Ada.IO_Exceptions.Mode_Error =>
         Result := Failure (Already_Closed);
   end Flush;

   -----------------
   -- Is_Terminal --
   -----------------

   overriding function Is_Terminal (Self : Process_Output) return Boolean is
   begin
      return Descriptor_Is_Terminal
        ((case Self.Channel is
            when Output_Channel => 1,
            when Error_Channel  => 2));
   end Is_Terminal;

   ----------
   -- Read --
   ----------

   overriding procedure Read
     (Self : in out Process_Input;
      Into : out String;
      Last : out Natural;
      Result : out IO_Result)
   is
      Block : Stream_Element_Array (1 .. Stream_Element_Offset (Into'Length));
      Final : Stream_Element_Offset;
   begin
      Into := [others => ASCII.NUL];
      Last := Into'First - 1;

      if Self.Exhausted then
         --  Standard input is a single stream: a second "-" operand observes
         --  end of file rather than rewinding.
         Result := (Status => End_Of_Data, Detail => U.Null_Unbounded_String);
         return;
      end if;

      Ada.Streams.Read
        (Ada.Text_IO.Text_Streams.Stream (Ada.Text_IO.Standard_Input).all,
         Block,
         Final);

      if Final < Block'First then
         Self.Exhausted := True;
         Result := (Status => End_Of_Data, Detail => U.Null_Unbounded_String);
         return;
      end if;

      for Offset in Block'First .. Final loop
         Into (Into'First + Natural (Offset - Block'First)) :=
           Character'Val (Block (Offset));
      end loop;

      Last := Into'First + Natural (Final - Block'First);
      Result := Success_Result;

   exception
      when Ada.IO_Exceptions.End_Error =>
         Self.Exhausted := True;
         Result := (Status => End_Of_Data, Detail => U.Null_Unbounded_String);

      when Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.Data_Error =>
         Result := Failure (IO_Failure);

      when Ada.IO_Exceptions.Status_Error | Ada.IO_Exceptions.Mode_Error =>
         Result := Failure (Already_Closed);
   end Read;

end Sed.IO.Process_Streams;
