separate (Posix_Tools.Commands.File_Helpers.Tailing.Copy_Line_Suffix)
procedure Emit_Suffix is
begin
   if Spill_Needed then
      if not Store_Available then
         Posix_Tools.Commands.Spill_Diagnostics.Report
           (Context, Create_Status);
         Ok := False;
      elsif Spill_Status /= Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete then
         Posix_Tools.Commands.Spill_Diagnostics.Report
           (Context, Spill_Status);
         Ok := False;
      else
         declare
            Prepare_Status : constant
              Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Outcome :=
                Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_For_Read
                  (Store);
         begin
            if Prepare_Status /=
              Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Complete
            then
               Posix_Tools.Commands.Spill_Diagnostics.Report
                 (Context, Prepare_Status);
               Ok := False;
            else
               declare
                  Start : Posix_Tools.Numbers.Count;
               begin
                  if Find_Store_Line_Start (Start) then
                     Emit_Store_From (Start);
                  else
                     Posix_Tools.Commands.Spill_Diagnostics.Report
                       (Context,
                        Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Open_Failed);
                     Ok := False;
                  end if;
               end;
            end if;
         end;
      end if;
   else
      if Retained_Full then
         for I in Retained_Next .. Natural (Retained.Length) loop
            Posix_Tools.Commands.Helpers.Buffered_Put
              (Output, Context, Retained (I));
            exit when Context.Output_Failed;
         end loop;
         if not Context.Output_Failed and then Retained_Next > 1 then
            for I in 1 .. Retained_Next - 1 loop
               Posix_Tools.Commands.Helpers.Buffered_Put
                 (Output, Context, Retained (I));
               exit when Context.Output_Failed;
            end loop;
         end if;
      else
         for Line of Retained loop
            Posix_Tools.Commands.Helpers.Buffered_Put
              (Output, Context, Line);
            exit when Context.Output_Failed;
         end loop;
      end if;
      Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
      if Context.Output_Failed then
         Ok := False;
      end if;
   end if;
end Emit_Suffix;
