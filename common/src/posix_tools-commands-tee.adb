with Ada.Streams;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Output_Files;
with Posix_Tools.Host_Adapters.Signals;
with Posix_Tools.Streams.Bytes;

package body Posix_Tools.Commands.Tee is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Append_Mode : Boolean := False;
      Ignore_Interrupt : Boolean := False;
      First       : Positive := 1;
      Ok          : Boolean := True;
      Written     : Boolean;
      Previous_Disposition : Posix_Tools.Host_Adapters.Signals.Disposition :=
        Posix_Tools.Host_Adapters.Signals.Default_Disposition;
      Restore_Interrupt    : Boolean := False;

      --  Reports a file that could not be opened, or written once open, and
      --  sets the failure status; tee goes on with the other files.
      procedure Mark_File_Failed (Path : String; Opening : Boolean);

      procedure Restore_Interrupt_Disposition;

      procedure Mark_File_Failed (Path : String; Opening : Boolean) is
      begin
         if Opening then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         else
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.write_failed", "cannot write file");
         end if;
         Ok := False;
      end Mark_File_Failed;

      procedure Restore_Interrupt_Disposition is
      begin
         if Restore_Interrupt then
            Ok :=
              Posix_Tools.Host_Adapters.Signals.Set_Disposition
                (Posix_Tools.Host_Adapters.Signals.Interrupt, Previous_Disposition)
              and then Ok;
            Restore_Interrupt := False;
         end if;
      end Restore_Interrupt_Disposition;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First)'Length > 1
           and then Context.Argument (First) (1) = '-'
         then
            for Ch of Context.Argument (First) (2 .. Context.Argument (First)'Last) loop
               case Ch is
                  when 'a' =>
                     Append_Mode := True;
                  when 'i' =>
                     Ignore_Interrupt := True;
                  when others =>
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Unknown_Option, "-" & Ch);
                     return;
               end case;
            end loop;
            First := First + 1;
         else
            exit;
         end if;
      end loop;

      if Ignore_Interrupt
        and then Posix_Tools.Host_Adapters.Signals.Is_Supported
          (Posix_Tools.Host_Adapters.Signals.Interrupt)
      then
         if Posix_Tools.Host_Adapters.Signals.Current_Disposition
             (Posix_Tools.Host_Adapters.Signals.Interrupt, Previous_Disposition)
           and then Posix_Tools.Host_Adapters.Signals.Set_Disposition
             (Posix_Tools.Host_Adapters.Signals.Interrupt,
              Posix_Tools.Host_Adapters.Signals.Ignore_Disposition)
         then
            Restore_Interrupt := True;
         else
            Ok := False;
         end if;
      end if;

      declare
         Files  : array (First .. Context.Argument_Count) of Posix_Tools.Host_Adapters.Output_Files.Output_File;
         Closed : Boolean;
         Read   : Boolean;

         --  Standard input as it arrives, to standard output and each file
         --  still open; a file that fails is closed and the rest go on.
         procedure Copy_Chunk
           (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset);

         procedure Copy_Chunk
           (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset)
         is
            Data : constant String := Posix_Tools.Streams.Bytes.To_String (Buffer, Last);
         begin
            Context.Put (Data);
            for I in Files'Range loop
               if Posix_Tools.Host_Adapters.Output_Files.Is_Open (Files (I)) then
                  Posix_Tools.Host_Adapters.Output_Files.Write (Files (I), Data, Written);
                  if not Written then
                     Posix_Tools.Host_Adapters.Output_Files.Close (Files (I), Closed);
                     Mark_File_Failed (Context.Argument (I), Opening => False);
                  end if;
               end if;
            end loop;
         end Copy_Chunk;

         procedure Copy_Input is new Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
           (Copy_Chunk, Stop_On_Output_Failure => False);
      begin
         --  Each file is opened once and written as input arrives.
         for I in Files'Range loop
            Posix_Tools.Host_Adapters.Output_Files.Open (Files (I), Context.Argument (I), Append_Mode, Written);
            if not Written then
               Mark_File_Failed (Context.Argument (I), Opening => True);
            end if;
         end loop;

         Copy_Input (Context, "-", Read);
         Ok := Read and then Ok;

         for I in Files'Range loop
            if Posix_Tools.Host_Adapters.Output_Files.Is_Open (Files (I)) then
               Posix_Tools.Host_Adapters.Output_Files.Close (Files (I), Closed);
               if not Closed then
                  Mark_File_Failed (Context.Argument (I), Opening => False);
               end if;
            end if;
         end loop;

         Restore_Interrupt_Disposition;
         Result.Status :=
           (if Ok and then not Context.Output_Failed
            then Posix_Tools.Exit_Status.Success
            else Posix_Tools.Exit_Status.Operational_Failure);
      end;
   exception
      when others =>
         Restore_Interrupt_Disposition;
         raise;
   end Run;
end Posix_Tools.Commands.Tee;
