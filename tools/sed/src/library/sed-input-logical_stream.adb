package body Sed.Input.Logical_Stream is

   package D renames Sed.Diagnostics;

   package Delivery renames Sed.Input.Delivery;
   package Cursors renames Sed.Input.Cursor;

   use type Sed.IO.IO_Status;

   --  Transfer size for pulling bytes out of an operand.
   Chunk_Size : constant := 64 * 1024;

   --  Try to produce one more line from the operand sequence, opening later
   --  operands as needed. Produced is False only when every operand is
   --  exhausted or the stream has become unusable.
   procedure Read_Raw
     (Self : in out Stream;
      Item : out Input_Line;
      Produced : out Boolean);

   --  Advance to the next operand, closing the current one.
   procedure Advance_Operand (Self : in out Stream);

   --  Pull more bytes from the current operand into the buffer.
   procedure Refill (Self : in out Stream; Progressed : out Boolean);

   --  Record a recoverable or fatal operand failure.
   procedure Report
     (Self : in out Stream;
      Code : D.Diagnostic_Code;
      Path : String;
      Detail : String);

   ------------
   -- Report --
   ------------

   procedure Report
     (Self : in out Stream;
      Code : D.Diagnostic_Code;
      Path : String;
      Detail : String)
   is
      Item : D.Diagnostic := D.Make (Code, D.Path_At (Path));
   begin
      D.Set (Item, D.Path, Path);

      if Detail'Length > 0 then
         D.Set (Item, D.Detail, Detail);
      end if;

      D.Append (Self.Diagnostics, Item);
   end Report;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Self : in out Stream;
      Files : not null access Sed.IO.Filesystem_Interface'Class;
      Standard_In : not null access Sed.IO.Input_Source_Interface'Class) is
   begin
      Self.Files := Files;
      Self.Standard_In := Standard_In;
      Self.Operands := Operand_Vectors.Empty_Vector;
      Self.Cursor := Cursors.Starting (0);
      Self.Handle := Sed.IO.Invalid_Handle;
      Self.Buffer := U.Null_Unbounded_String;
      Self.Buffer_First := 1;
      Self.Scan_At := 1;
      Self.Source_Drained := False;
      Self.Counters := Delivery.Start;
      Self.Local := 0;
      Self.Have_Pending := False;
      Self.Fatal := False;
      Self.Diagnostics := D.Empty_List;
   end Initialize;

   -----------------
   -- Add_Operand --
   -----------------

   procedure Add_Operand (Self : in out Stream; Item : Operand) is
   begin
      Self.Operands.Append (Item);
      Self.Cursor := Cursors.Starting (Natural (Self.Operands.Length));
   end Add_Operand;

   ---------------------
   -- Advance_Operand --
   ---------------------

   procedure Advance_Operand (Self : in out Stream) is
   begin
      if Self.Cursor.Opened
        and then Sed.IO.Is_Open (Self.Handle)
      then
         Self.Files.Close_Input (Self.Handle);
      end if;

      Self.Handle := Sed.IO.Invalid_Handle;
      Self.Buffer := U.Null_Unbounded_String;
      Self.Buffer_First := 1;
      Self.Scan_At := 1;
      Self.Source_Drained := False;
      Self.Local := 0;
      Cursors.Advance (Self.Cursor);
   end Advance_Operand;

   ------------
   -- Refill --
   ------------

   procedure Refill (Self : in out Stream; Progressed : out Boolean) is
      Block : String (1 .. Chunk_Size);
      Last : Natural;
      Result : Sed.IO.IO_Result;
      Item : constant Operand := Self.Operands (Self.Cursor.Index);
      Name : constant String := U.To_String (Item.Name);
   begin
      Progressed := False;

      --  Drop consumed storage at chunk boundaries. This is at most one
      --  bounded copy per refill, rather than one suffix copy per line.
      if Self.Buffer_First > 1 then
         declare
            Last_Buffered : constant Natural := U.Length (Self.Buffer);
         begin
            if Self.Buffer_First > Last_Buffered then
               Self.Buffer := U.Null_Unbounded_String;
               Self.Buffer_First := 1;
               Self.Scan_At := 1;
            else
               Self.Buffer := U.To_Unbounded_String
                 (U.Slice (Self.Buffer, Self.Buffer_First, Last_Buffered));
               Self.Scan_At := Self.Scan_At - Self.Buffer_First + 1;
               Self.Buffer_First := 1;
            end if;
         end;
      end if;

      case Item.Kind is
         when Standard_Input =>
            Self.Standard_In.Read (Block, Last, Result);

         when Named_File =>
            Self.Files.Read (Self.Handle, Block, Last, Result);
      end case;

      if Result.Status = Sed.IO.End_Of_Data then
         Self.Source_Drained := True;
         return;
      end if;

      if Sed.IO.Is_Failure (Result) then
         Report (Self, D.Input_Read_Failed, Name, U.To_String (Result.Detail));
         Self.Source_Drained := True;

         if Item.Kind = Standard_Input then
            --  Standard input cannot be reopened or repositioned, so a read
            --  fault there ends the whole stream rather than skipping ahead.
            Self.Fatal := True;
         end if;

         return;
      end if;

      if Last >= Block'First then
         U.Append (Self.Buffer, Block (Block'First .. Last));
         Progressed := True;
      end if;
   end Refill;

   --------------
   -- Read_Raw --
   --------------

   procedure Read_Raw
     (Self : in out Stream;
      Item : out Input_Line;
      Produced : out Boolean) is
   begin
      Item := (others => <>);
      Produced := False;

      loop
         if Self.Fatal then
            return;
         end if;

         if Self.Cursor.Index = 0 then
            Cursors.Begin_Sequence (Self.Cursor);
         end if;

         if Cursors.Exhausted (Self.Cursor) then
            return;
         end if;

         declare
            Current : constant Operand := Self.Operands (Self.Cursor.Index);
            Name : constant String := U.To_String (Current.Name);
         begin
            --  Open the operand the first time it is needed, never earlier.
            if not Self.Cursor.Opened then
               case Current.Kind is
                  when Standard_Input =>
                     Cursors.Open (Self.Cursor);

                  when Named_File =>
                     declare
                        Result : Sed.IO.IO_Result;
                     begin
                        Self.Files.Open_Input (Name, Self.Handle, Result);

                        if Sed.IO.Is_Failure (Result) then
                           Report
                             (Self,
                              D.Input_Open_Failed,
                              Name,
                              U.To_String (Result.Detail));
                           Advance_Operand (Self);
                           goto Continue_Loop;
                        end if;

                        Cursors.Open (Self.Cursor);
                     end;
               end case;
            end if;

            --  Split a line out of whatever is buffered, pulling more bytes
            --  until a newline appears or the operand is drained.
            loop
               declare
                  Last_Buffered : constant Natural := U.Length (Self.Buffer);
                  Newline : Natural := 0;
               begin
                  for Index in Self.Scan_At .. Last_Buffered loop
                     if U.Element (Self.Buffer, Index) = ASCII.LF then
                        Newline := Index;
                        exit;
                     end if;
                  end loop;

                  if Newline /= 0 then
                     Delivery.Assign (Self.Counters);
                     Self.Local := Self.Local + 1;

                     if Self.Buffer_First = 1
                       and then Newline = Last_Buffered
                     then
                        --  The record occupies the whole buffer. Remove its
                        --  separator in place and share the allocation with
                        --  the delivered value instead of slicing a second
                        --  record-sized string.
                        U.Delete (Self.Buffer, Newline, Newline);
                        Item :=
                          (Data => Self.Buffer,
                           Has_Terminator => True,
                           Global_Line => Self.Counters.Assigned,
                           Local_Line => Self.Local,
                           Source_Name => Current.Name,
                           Source_Kind => Current.Kind,
                           Is_Final => False);
                        Self.Buffer := U.Null_Unbounded_String;
                        Self.Buffer_First := 1;
                        Self.Scan_At := 1;
                     else
                        Item :=
                          (Data =>
                             (if Newline = Self.Buffer_First
                              then U.Null_Unbounded_String
                              else U.To_Unbounded_String
                                (U.Slice
                                   (Self.Buffer,
                                    Self.Buffer_First,
                                    Newline - 1))),
                           Has_Terminator => True,
                           Global_Line => Self.Counters.Assigned,
                           Local_Line => Self.Local,
                           Source_Name => Current.Name,
                           Source_Kind => Current.Kind,
                           Is_Final => False);
                        Self.Buffer_First := Newline + 1;
                        Self.Scan_At := Self.Buffer_First;
                     end if;
                     Produced := True;
                     return;
                  end if;

                  Self.Scan_At := Last_Buffered + 1;

                  if Self.Source_Drained then
                     if Self.Buffer_First <= Last_Buffered then
                        --  A final line without a terminator.
                        Delivery.Assign (Self.Counters);
                        Self.Local := Self.Local + 1;

                        Item :=
                          (Data =>
                             (if Self.Buffer_First = 1
                              then Self.Buffer
                              else U.To_Unbounded_String
                                (U.Slice
                                   (Self.Buffer,
                                    Self.Buffer_First,
                                    Last_Buffered))),
                           Has_Terminator => False,
                           Global_Line => Self.Counters.Assigned,
                           Local_Line => Self.Local,
                           Source_Name => Current.Name,
                           Source_Kind => Current.Kind,
                           Is_Final => False);

                        Self.Buffer := U.Null_Unbounded_String;
                        Self.Buffer_First := 1;
                        Self.Scan_At := 1;
                        Produced := True;
                        return;
                     end if;

                     --  An empty operand contributes no line at all.
                     Advance_Operand (Self);
                     exit;
                  end if;
               end;

               declare
                  Progressed : Boolean;
               begin
                  Refill (Self, Progressed);

                  if Self.Fatal then
                     return;
                  end if;
               end;
            end loop;
         end;

         <<Continue_Loop>>
      end loop;
   end Read_Raw;

   ----------
   -- Next --
   ----------

   procedure Next
     (Self : in out Stream;
      Item : out Input_Line;
      Status : out Record_Status)
   is
      Following : Input_Line;
      Have_Following : Boolean;
   begin
      Item := (others => <>);

      if not Self.Have_Pending then
         declare
            First : Input_Line;
            Produced : Boolean;
         begin
            Read_Raw (Self, First, Produced);

            if not Produced then
               Status := (if Self.Fatal then Read_Failed else End_Of_Input);
               return;
            end if;

            Self.Pending := First;
            Self.Have_Pending := True;
         end;
      end if;

      Item := Self.Pending;
      Self.Have_Pending := False;

      --  Look one line ahead so that the delivered line can be marked final
      --  exactly when nothing follows it anywhere in the operand sequence.
      Read_Raw (Self, Following, Have_Following);

      if Have_Following then
         Self.Pending := Following;
         Self.Have_Pending := True;
      else
         Item.Is_Final := True;
      end if;

      --  The delivery contract requires a record that was read and not yet
      --  handed over, and refuses any delivery once the final line has gone
      --  out, so a second final line cannot be produced here.
      Delivery.Deliver (Self.Counters, Item.Is_Final);
      Status := Record_Available;
   end Next;

   -----------------------
   -- Take_Diagnostics --
   -----------------------

   procedure Take_Diagnostics
     (Self : in out Stream;
      Into : out D.Diagnostic_List) is
   begin
      Into := Self.Diagnostics;
      Self.Diagnostics := D.Empty_List;
   end Take_Diagnostics;

   ---------------------
   -- Delivered_Count --
   ---------------------

   function Delivered_Count (Self : Stream) return Line_Number is
   begin
      return Self.Counters.Delivered;
   end Delivered_Count;

   --------------------------
   -- Final_Line_Delivered --
   --------------------------

   function Final_Line_Delivered (Self : Stream) return Boolean is
   begin
      return Self.Counters.Final_Seen;
   end Final_Line_Delivered;

   -----------
   -- Close --
   -----------

   procedure Close (Self : in out Stream) is
   begin
      if Self.Files /= null
        and then Sed.IO.Is_Open (Self.Handle)
      then
         Self.Files.Close_Input (Self.Handle);
      end if;

      Self.Handle := Sed.IO.Invalid_Handle;
      Self.Buffer := U.Null_Unbounded_String;
      Self.Buffer_First := 1;
      Self.Scan_At := 1;
      Self.Have_Pending := False;
   end Close;

   --------------
   -- Finalize --
   --------------

   overriding procedure Finalize (Self : in out Stream) is
   begin
      Close (Self);
   end Finalize;

end Sed.Input.Logical_Stream;
