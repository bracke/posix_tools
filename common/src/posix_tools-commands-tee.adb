with Ada.Containers.Indefinite_Vectors;
with Ada.Streams;

with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Signals;

package body Posix_Tools.Commands.Tee is
   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   use type Ada.Streams.Stream_Element_Offset;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Append_Mode : Boolean := False;
      Ignore_Interrupt : Boolean := False;
      First       : Positive := 1;
      Ok          : Boolean := True;
      Written     : Boolean;
      Failed_Files : String_Vectors.Vector;
      Previous_Disposition : Posix_Tools.Host_Adapters.Signals.Disposition :=
        Posix_Tools.Host_Adapters.Signals.Default_Disposition;
      Restore_Interrupt    : Boolean := False;

      function Buffer_Text
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset) return String;

      function Is_Failed_File (Path : String) return Boolean;

      procedure Mark_File_Failed (Path : String);

      procedure Restore_Interrupt_Disposition;

      function Buffer_Text
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset) return String
      is
         Text : String (1 .. Natural (Last - Buffer'First + 1));
      begin
         for I in Text'Range loop
            Text (I) :=
              Character'Val
                (Integer (Buffer (Buffer'First + Ada.Streams.Stream_Element_Offset (I - 1))));
         end loop;
         return Text;
      end Buffer_Text;

      function Is_Failed_File (Path : String) return Boolean is
      begin
         for I in 1 .. Natural (Failed_Files.Length) loop
            if Failed_Files.Element (I) = Path then
               return True;
            end if;
         end loop;
         return False;
      end Is_Failed_File;

      procedure Mark_File_Failed (Path : String) is
      begin
         if not Is_Failed_File (Path) then
            Failed_Files.Append (Path);
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
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
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "unknown option '-" & Ch & "'");
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
         Buffer : Ada.Streams.Stream_Element_Array (1 .. 16 * 1024);
         Last   : Ada.Streams.Stream_Element_Offset;
      begin
         for I in First .. Context.Argument_Count loop
            if not Append_Mode then
               Posix_Tools.Commands.File_Helpers.Write_File
                 (Context.Argument (I), "", False, Written);
               if not Written then
                  Mark_File_Failed (Context.Argument (I));
               end if;
            end if;
         end loop;

         loop
            if not Context.Try_Read_Standard_Input (Buffer, Last) then
               Ok := False;
               exit;
            end if;
            exit when Last < Buffer'First;

            declare
               Data : constant String := Buffer_Text (Buffer, Last);
            begin
               Context.Put (Data);
               for I in First .. Context.Argument_Count loop
                  if not Is_Failed_File (Context.Argument (I)) then
                     Posix_Tools.Commands.File_Helpers.Write_File
                       (Context.Argument (I), Data, True, Written);
                     if not Written then
                        Mark_File_Failed (Context.Argument (I));
                     end if;
                  end if;
               end loop;
            end;
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
