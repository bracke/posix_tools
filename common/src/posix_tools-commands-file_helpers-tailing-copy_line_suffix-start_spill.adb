separate (Posix_Tools.Commands.File_Helpers.Tailing.Copy_Line_Suffix)
procedure Start_Spill is
begin
   Spill_Needed := True;
   Create_Status :=
     Posix_Tools.Host_Adapters.Temporary_Storage.Create
       (Store, Context.Tail_Max_Spill_Bytes);
   Store_Available :=
     Create_Status =
       Posix_Tools.Host_Adapters.Temporary_Storage.Create_Complete;
   if Store_Available then
      if Retained_Full then
         for I in Retained_Next .. Natural (Retained.Length) loop
            Append_Text_To_Store (Retained (I));
            exit when
              Spill_Status /= Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete;
         end loop;
         if Spill_Status = Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete
           and then Retained_Next > 1
         then
            for I in 1 .. Retained_Next - 1 loop
               Append_Text_To_Store (Retained (I));
               exit when
                 Spill_Status /= Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete;
            end loop;
         end if;
      else
         for Line of Retained loop
            Append_Text_To_Store (Line);
            exit when
              Spill_Status /= Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete;
         end loop;
      end if;
      if Spill_Status = Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete then
         Append_Text_To_Store (To_String (Current));
      end if;
      Flush_Spill_Buffer;
   end if;

   Retained.Clear;
   Retained_Bytes := 0;
   Retained_Next := 1;
   Retained_Full := False;
   Current := Null_Unbounded_String;
end Start_Spill;
