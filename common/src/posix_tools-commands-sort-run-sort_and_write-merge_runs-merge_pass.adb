separate (Posix_Tools.Commands.Sort.Run.Sort_And_Write.Merge_Runs)
procedure Merge_Pass (Items : in out Run_Vectors.Vector) is
   Next_Runs : Run_Vectors.Vector;
   First_Run : Positive := Items.First_Index;

   procedure Release (First, Last : Positive) is
   begin
      for I in First .. Last loop
         declare
            Ref : constant Run_Vectors.Reference_Type := Items.Reference (I);
         begin
            Release_Run (Ref.Element.all);
         end;
      end loop;
   end Release;

   procedure Cleanup_Next is
   begin
      for I in Next_Runs.First_Index .. Next_Runs.Last_Index loop
         declare
            Ref : constant Run_Vectors.Reference_Type := Next_Runs.Reference (I);
         begin
            Release_Run (Ref.Element.all);
         end;
      end loop;
      Next_Runs.Clear;
   end Cleanup_Next;
begin
   while Ok and then First_Run <= Items.Last_Index loop
      declare
         Last_Run : constant Positive :=
           Positive'Min (Items.Last_Index, First_Run + Merge_Fan_In - 1);
      begin
         if First_Run = Last_Run then
            Next_Runs.Append (Items.Element (First_Run));
            declare
               Ref : constant Run_Vectors.Reference_Type := Items.Reference (First_Run);
            begin
               Ref.Element.all.Store := null;
               Ref.Element.all.Buffer := null;
            end;
         else
            declare
               Target        : Run_State;
               Create_Status : Storage.Create_Outcome;
               Finish_Status : Storage.Finish_Outcome;
               Buffer        : Spill_Byte_Buffer;
               Buffered_Last : Ada.Streams.Stream_Element_Offset := Buffer'First - 1;

               procedure Flush_Buffer is
               begin
                  if Ok and then Buffered_Last >= Buffer'First then
                     declare
                        Outcome : constant Storage.Append_Outcome :=
                          Storage.Append (Target.Store.all, Buffer, Buffered_Last);
                     begin
                        if Outcome /= Storage.Append_Complete then
                           Storage_Error (Outcome);
                        end if;
                     end;
                     Buffered_Last := Buffer'First - 1;
                  end if;
               end Flush_Buffer;

               procedure Append_Text (Text : String) is
               begin
                  for Ch of Text loop
                     exit when not Ok;
                     Buffered_Last := Buffered_Last + 1;
                     Buffer (Buffered_Last) := Ada.Streams.Stream_Element (Character'Pos (Ch));
                     if Buffered_Last = Buffer'Last then
                        Flush_Buffer;
                     end if;
                  end loop;
               end Append_Text;

               procedure Take (Line : Unbounded_String; Prepared : Sort_Keys.Prepared_Line) is
                  pragma Unreferenced (Prepared);
               begin
                  Append_Text (To_String (Line));
                  Append_Text ([1 => LF]);
               end Take;

               procedure Merge is new Merge_Group (Take);
            begin
               Target.Store := new Storage.Store;
               Create_Status :=
                 Storage.Create
                   (Target.Store.all,
                    Posix_Tools.Numbers.Count'Last);
               if Create_Status /= Storage.Create_Complete then
                  Storage_Error (Create_Status);
               else
                  Merge (Items, First_Run, Last_Run);
                  Flush_Buffer;
                  if Ok then
                     Finish_Status := Storage.Finish_Writing (Target.Store.all);
                     if Finish_Status /= Storage.Finish_Complete then
                        Storage_Error (Finish_Status);
                     end if;
                  end if;
               end if;
               if Ok then
                  Next_Runs.Append (Target);
                  Target.Store := null;
                  Release (First_Run, Last_Run);
               end if;
               Release_Run (Target);
            exception
               when others =>
                  Release_Run (Target);
                  raise;
            end;
         end if;
         First_Run := Last_Run + 1;
      end;
   end loop;

   if Ok then
      Items.Clear;
      Items.Move (Next_Runs);
   else
      Cleanup_Next;
   end if;
exception
   when others =>
      Cleanup_Next;
      raise;
end Merge_Pass;
