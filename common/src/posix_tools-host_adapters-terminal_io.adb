with Hostkit.Descriptors;

package body Posix_Tools.Host_Adapters.Terminal_IO is
   use type Hostkit.Descriptors.Transfer_Outcome;

   function Enter_Raw (Saved : out Saved_Mode) return Boolean is
      Terminal : constant Hostkit.Descriptors.Descriptor := Hostkit.Descriptors.Standard_Input;
      Mode     : Hostkit.Terminal_Control.Mode;
   begin
      Saved.Valid := False;

      if not Hostkit.Terminal_Control.Save_Mode (Terminal, Mode) then
         return False;
      end if;

      if not Hostkit.Terminal_Control.Set_Raw (Terminal) then
         --  Set_Raw may have applied part of its change before refusing, so
         --  the saved settings go back whatever it reports.
         declare
            Restored : constant Boolean := Hostkit.Terminal_Control.Restore_Mode (Terminal, Mode);
            pragma Unreferenced (Restored);
         begin
            return False;
         end;
      end if;

      Saved := (Valid => True, Mode => Mode);
      return True;
   end Enter_Raw;

   function Is_Interactive return Boolean is
   begin
      return Hostkit.Descriptors.Is_Terminal (Hostkit.Descriptors.Standard_Input)
        and then Hostkit.Descriptors.Is_Terminal (Hostkit.Descriptors.Standard_Output);
   exception
      when others =>
         return False;
   end Is_Interactive;

   procedure Read
     (Into       : out Ada.Streams.Stream_Element_Array;
      Last       : out Ada.Streams.Stream_Element_Offset;
      Timeout_Ms : Integer;
      Outcome    : out Read_Outcome)
   is
      Input : constant Hostkit.Descriptors.Descriptor := Hostkit.Descriptors.Standard_Input;
   begin
      Last := Into'First - 1;

      if not Hostkit.Descriptors.Wait_Readable (Input, Timeout_Ms) then
         Outcome := Read_Timeout;
         return;
      end if;

      case Hostkit.Descriptors.Read (Input, Into, Last) is
         when Hostkit.Descriptors.Transfer_Ok =>
            Outcome := (if Last >= Into'First then Read_Data else Read_Timeout);
         when Hostkit.Descriptors.Transfer_Would_Block | Hostkit.Descriptors.Transfer_Interrupted =>
            Outcome := Read_Timeout;
         when Hostkit.Descriptors.Transfer_End_Of_File =>
            Outcome := Read_End_Of_File;
         when Hostkit.Descriptors.Transfer_Broken_Pipe | Hostkit.Descriptors.Transfer_Error =>
            Outcome := Read_Failed;
      end case;

      if Outcome /= Read_Data then
         Last := Into'First - 1;
      end if;
   end Read;

   procedure Restore (Saved : Saved_Mode) is
   begin
      if Saved.Valid then
         declare
            --  Nothing further can be done about a terminal that refuses its
            --  own saved settings; the caller is already on its way out.
            Restored : constant Boolean :=
              Hostkit.Terminal_Control.Restore_Mode (Hostkit.Descriptors.Standard_Input, Saved.Mode);
            pragma Unreferenced (Restored);
         begin
            null;
         end;
      end if;
   end Restore;

   function Size (Into : out Window_Size) return Boolean is
      Host_Size : Hostkit.Terminal_Control.Window_Size;
   begin
      Into := (Rows => 0, Columns => 0);

      if not Hostkit.Terminal_Control.Size (Hostkit.Descriptors.Standard_Output, Host_Size) then
         return False;
      end if;

      Into := (Rows => Host_Size.Rows, Columns => Host_Size.Columns);
      return Into.Rows > 0 and then Into.Columns > 0;
   end Size;

   function Write (Data : String) return Boolean is
      Output : constant Hostkit.Descriptors.Descriptor := Hostkit.Descriptors.Standard_Output;
      Bytes  : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Data'Length));
      First  : Ada.Streams.Stream_Element_Offset := Bytes'First;
      Last   : Ada.Streams.Stream_Element_Offset;
   begin
      for I in Data'Range loop
         Bytes (Ada.Streams.Stream_Element_Offset (I - Data'First + 1)) := Character'Pos (Data (I));
      end loop;

      while First <= Bytes'Last loop
         case Hostkit.Descriptors.Write (Output, Bytes (First .. Bytes'Last), Last) is
            when Hostkit.Descriptors.Transfer_Ok =>
               First := Last + 1;
            when Hostkit.Descriptors.Transfer_Interrupted =>
               null;
            when Hostkit.Descriptors.Transfer_Would_Block =>
               --  A terminal that would block takes its output once its
               --  reader catches up; give it a moment and try again.
               delay 0.001;
            when Hostkit.Descriptors.Transfer_End_Of_File
               | Hostkit.Descriptors.Transfer_Broken_Pipe
               | Hostkit.Descriptors.Transfer_Error
            =>
               return False;
         end case;
      end loop;

      return True;
   end Write;
end Posix_Tools.Host_Adapters.Terminal_IO;
