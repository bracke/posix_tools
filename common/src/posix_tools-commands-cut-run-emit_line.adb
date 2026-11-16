separate (Posix_Tools.Commands.Cut.Run)
procedure Emit_Line (Line : String) is
   Separator : constant String := To_String (Delimiter);
   Field     : Positive := 1;
   Range_Index : Positive := Ranges.First_Index;
   Start     : Positive := Line'First;
   Index     : Positive := Line'First;
   Seen_Delimiter : Boolean := False;
   --  A field has been written, so the next one selected follows a
   --  delimiter, even when the one written was empty.
   Wrote_Field : Boolean := False;

   procedure Flush;
   procedure Put (Text : String);
   procedure Finish;
   procedure Field_Ends (Last : Natural);
   function Field_Selected return Boolean;

   procedure Flush is
   begin
      Flush_Output;
   end Flush;

   procedure Put (Text : String) is
   begin
      if Text'Length >= 64 * 1024 then
         Flush;
         if not Context.Output_Failed then
            Context.Put (Text);
         end if;
      else
         if Length (Pending_Output) > 64 * 1024 - Text'Length then
            Flush;
         end if;
         Append (Pending_Output, Text);
         if Length (Pending_Output) = 64 * 1024 then
            Flush;
         end if;
      end if;
   end Put;

   procedure Finish is
   begin
      Put ([1 => Character'Val (10)]);
   end Finish;

   function Field_Selected return Boolean is
   begin
      while Range_Index <= Ranges.Last_Index
        and then Ranges.Element (Range_Index).Last /= 0
        and then Field > Ranges.Element (Range_Index).Last
      loop
         Range_Index := Range_Index + 1;
      end loop;
      return Range_Index <= Ranges.Last_Index
        and then Field >= Ranges.Element (Range_Index).First;
   end Field_Selected;

   procedure Field_Ends (Last : Natural) is
   begin
      if Field_Selected then
         if Wrote_Field then
            Put (Separator);
         end if;
         Put (Line (Start .. Last));
         Wrote_Field := True;
      end if;
   end Field_Ends;
begin
   --  Byte and character modes are handled by the chunked paths above.
   --  With -s, no byte can be written until a delimiter is known to
   --  exist.  Find one first, then stream selected fields.
   while Index + Separator'Length - 1 <= Line'Last loop
      if Line (Index .. Index + Separator'Length - 1) = Separator then
         Seen_Delimiter := True;
         exit;
      end if;
      Index := Index + 1;
   end loop;
   if not Seen_Delimiter then
      if not Suppress then
         Put (Line);
         Finish;
      end if;
      return;
   end if;

   Index := Line'First;
   while Index + Separator'Length - 1 <= Line'Last loop
      if Line (Index .. Index + Separator'Length - 1) = Separator then
         Field_Ends (Index - 1);
         Field := Field + 1;
         Index := Index + Separator'Length;
         Start := Index;
      else
         Index := Index + 1;
      end if;
   end loop;
   Field_Ends (Line'Last);
   Finish;
end Emit_Line;
