package body Posix_Tools.Commands.Rg.Input is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element;
   use type Posix_Tools.Host_Adapters.Input_Files.Read_Outcome;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Append_Outcome;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Create_Outcome;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Outcome;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Read_Outcome;
   use type Posix_Tools.Text.UTF_8.Decode_Status;
   use type Encoding.Encoding_Mode;

   function Encoding_Has_Structural_Nuls
     (Encoding : Encoding_Mode;
      Prefix   : Prefix_Array;
      Count    : Natural) return Boolean;
   procedure Initialize_Reader (Self : in out Reader; Encoding : Encoding_Mode);

   function Encoding_Has_Structural_Nuls
     (Encoding : Encoding_Mode;
      Prefix   : Prefix_Array;
      Count    : Natural) return Boolean
   is
   begin
      return
        Encoding in UTF_16_Encoding | UTF_16LE_Encoding | UTF_16BE_Encoding
        or else
          (Encoding = Automatic_Encoding
           and then Count >= 2
           and then
             ((Prefix (1) = 16#FF# and then Prefix (2) = 16#FE#)
              or else (Prefix (1) = 16#FE# and then Prefix (2) = 16#FF#)));
   end Encoding_Has_Structural_Nuls;

   procedure Initialize_Reader (Self : in out Reader; Encoding : Encoding_Mode) is
   begin
      Self.Next := Self.Buffer'First;
      Self.Last := Self.Buffer'First - 1;
      Self.At_End := False;
      Self.Requested_Encoding := Encoding;
      Self.Active := Encoding_Undetermined;
      Self.Prefix_Count := 0;
      Self.Prefix_Next := 1;
      Self.Decoded_Next := 1;
      Self.Decoded_Last := 0;
      Self.UTF_8_Length := 0;
      Self.Has_Retry_Byte := False;
      Self.Pending_High := 0;
      Self.Has_Retry_Unit := False;
      Self.Pushback_Count := 0;
      Self.ISO_State := ISO_ASCII;
      Self.ISO_Output_Flag := False;
      Self.Replacement_Emitted := False;
   end Initialize_Reader;

   procedure Open_Spooled_Standard_Input
     (Self       : in out Reader;
      Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Encoding   : Encoding_Mode;
      Nul_Offset : out Natural;
      Outcome    : out Spool_Outcome)
   is
      Buffer : Ada.Streams.Stream_Element_Array (1 .. Buffer_Length);
      Last   : Ada.Streams.Stream_Element_Offset;
      Offset : Natural := 0;
      Prefix : Prefix_Array := [others => 0];
      Prefix_Count : Natural range 0 .. 3 := 0;

      procedure Abandon;

      procedure Abandon is
      begin
         if not Posix_Tools.Host_Adapters.Temporary_Storage.Cleanup_Or_Defer
           (Self.Spool)
         then
            null;
         end if;
      end Abandon;
   begin
      Initialize_Reader (Self, Encoding);
      Self.Source := Spooled_Standard_Input;
      Nul_Offset := No_Nul_Byte;

      if Posix_Tools.Host_Adapters.Temporary_Storage.Create
           (Self.Spool, Maximum_Standard_Input_Bytes)
        /= Posix_Tools.Host_Adapters.Temporary_Storage.Create_Complete
      then
         Outcome := Spool_Create_Failed;
         Abandon;
         return;
      end if;

      loop
         if not Context.Try_Read_Standard_Input (Buffer, Last) then
            Outcome := Spool_Read_Failed;
            Abandon;
            return;
         end if;
         exit when Last < Buffer'First;

         for Index in Buffer'First .. Last loop
            exit when Prefix_Count = Prefix'Length;
            Prefix_Count := Prefix_Count + 1;
            Prefix (Prefix_Count) := Buffer (Index);
         end loop;

         if Nul_Offset = No_Nul_Byte then
            for Index in Buffer'First .. Last loop
               if Buffer (Index) = 0 then
                  Nul_Offset := Offset + Natural (Index - Buffer'First);
                  exit;
               end if;
            end loop;
         end if;

         case Posix_Tools.Host_Adapters.Temporary_Storage.Append
           (Self.Spool, Buffer, Last)
         is
            when Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete =>
               Offset := Offset + Natural (Last - Buffer'First + 1);
            when Posix_Tools.Host_Adapters.Temporary_Storage.Append_Capacity_Exceeded =>
               Outcome := Spool_Capacity_Exceeded;
               Abandon;
               return;
            when Posix_Tools.Host_Adapters.Temporary_Storage.Append_Write_Failed =>
               Outcome := Spool_Write_Failed;
               Abandon;
               return;
         end case;
      end loop;

      if Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_For_Read (Self.Spool)
        /= Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Complete
      then
         Outcome := Spool_Prepare_Failed;
         Abandon;
         return;
      end if;
      if Encoding_Has_Structural_Nuls (Encoding, Prefix, Prefix_Count) then
         Nul_Offset := No_Nul_Byte;
      end if;
      Outcome := Spool_Ready;
   end Open_Spooled_Standard_Input;

   procedure Scan_File_For_Nul
     (Name       : String;
      Encoding   : Encoding_Mode;
      Nul_Offset : out Natural;
      Outcome    : out Nul_Scan_Outcome)
   is
      File   : Posix_Tools.Host_Adapters.Input_Files.Input_File;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. Buffer_Length);
      Last   : Ada.Streams.Stream_Element_Offset;
      Status : Posix_Tools.Host_Adapters.Input_Files.Read_Outcome;
      Offset : Natural := 0;
      Opened : Boolean;
      Closed : Boolean;
      Prefix : Prefix_Array := [others => 0];
      Prefix_Count : Natural range 0 .. 3 := 0;
   begin
      Nul_Offset := No_Nul_Byte;
      Posix_Tools.Host_Adapters.Input_Files.Open (File, Name, Opened);
      if not Opened then
         Outcome := Scan_Open_Failed;
         return;
      end if;

      Outcome := No_Nul_Found;
      loop
         Posix_Tools.Host_Adapters.Input_Files.Read (File, Buffer, Last, Status);
         case Status is
            when Posix_Tools.Host_Adapters.Input_Files.Read_Failed =>
               Outcome := Scan_Read_Failed;
               exit;
            when Posix_Tools.Host_Adapters.Input_Files.Read_End =>
               exit;
            when Posix_Tools.Host_Adapters.Input_Files.Read_Complete =>
               for Index in Buffer'First .. Last loop
                  if Prefix_Count < Prefix'Length then
                     Prefix_Count := Prefix_Count + 1;
                     Prefix (Prefix_Count) := Buffer (Index);
                  end if;
                  if Buffer (Index) = 0 then
                     Nul_Offset :=
                       (if Offset > Natural'Last - Natural (Index - Buffer'First)
                        then Natural'Last
                        else Offset + Natural (Index - Buffer'First));
                     Outcome := Nul_Found;
                     exit;
                  end if;
               end loop;
               exit when Outcome = Nul_Found and then Prefix_Count = Prefix'Length;
               if Last >= Buffer'First then
                  declare
                     Count : constant Natural := Natural (Last - Buffer'First + 1);
                  begin
                     Offset :=
                       (if Offset > Natural'Last - Count then Natural'Last else Offset + Count);
                  end;
               end if;
         end case;
      end loop;

      Posix_Tools.Host_Adapters.Input_Files.Close (File, Closed);
      if Encoding_Has_Structural_Nuls (Encoding, Prefix, Prefix_Count)
        and then Outcome = Nul_Found
      then
         Nul_Offset := No_Nul_Byte;
         Outcome := No_Nul_Found;
      end if;
      if not Closed then
         Outcome := Scan_Close_Failed;
      end if;
   end Scan_File_For_Nul;

   procedure Open
     (Self     : in out Reader;
      Name     : String;
      Encoding : Encoding_Mode;
      Ok       : out Boolean) is
   begin
      Initialize_Reader (Self, Encoding);
      Self.Source := (if Name = "-" then Standard_Input else Named_File);
      if Self.Source = Standard_Input then
         Ok := True;
      else
         Posix_Tools.Host_Adapters.Input_Files.Open (Self.File, Name, Ok);
      end if;
   end Open;

   procedure Next
     (Self       : in out Reader;
      Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Line       : out Unbounded_String;
      Terminated : out Boolean;
      Outcome    : out Read_Outcome)
   is
      Nul_Offset : Natural;
   begin
      Next (Self, Context, Line, Terminated, Nul_Offset, Outcome, ASCII.LF);
   end Next;

   procedure Next
     (Self       : in out Reader;
      Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Line       : out Unbounded_String;
      Terminated : out Boolean;
      Nul_Offset : out Natural;
      Outcome    : out Read_Outcome;
      Delimiter  : Character := ASCII.LF)
   is
      Dropping     : Boolean := False;
      Record_Bytes : Natural := 0;

      procedure Fill;
      procedure Initialize_Encoding;
      procedure Read_Decoded_Byte (Item : out Character; Available : out Boolean);
      procedure Read_Raw_Byte (Item : out Ada.Streams.Stream_Element; Available : out Boolean);
      procedure Read_Source_Byte (Item : out Ada.Streams.Stream_Element; Available : out Boolean);

      procedure Fill is
      begin
         Self.Next := Self.Buffer'First;
         case Self.Source is
            when Standard_Input =>
               if not Context.Try_Read_Standard_Input (Self.Buffer, Self.Last) then
                  Outcome := Read_Failed;
                  return;
               elsif Self.Last < Self.Buffer'First then
                  Self.At_End := True;
               end if;
            when Spooled_Standard_Input =>
               if Posix_Tools.Host_Adapters.Temporary_Storage.Read_Next
                    (Self.Spool, Self.Buffer, Self.Last)
                 /= Posix_Tools.Host_Adapters.Temporary_Storage.Read_Complete
               then
                  Outcome := Read_Failed;
                  return;
               elsif Self.Last < Self.Buffer'First then
                  Self.At_End := True;
               end if;
            when Named_File =>
               declare
                  Status : Posix_Tools.Host_Adapters.Input_Files.Read_Outcome;
               begin
                  Posix_Tools.Host_Adapters.Input_Files.Read
                    (Self.File, Self.Buffer, Self.Last, Status);
                  if Status = Posix_Tools.Host_Adapters.Input_Files.Read_Failed then
                     Outcome := Read_Failed;
                     return;
                  elsif Status = Posix_Tools.Host_Adapters.Input_Files.Read_End then
                     Self.At_End := True;
                  end if;
               end;
         end case;
      end Fill;

      procedure Read_Source_Byte
        (Item      : out Ada.Streams.Stream_Element;
         Available : out Boolean) is
      begin
         loop
            if Self.Next <= Self.Last then
               Item := Self.Buffer (Self.Next);
               Self.Next := Self.Next + 1;
               Available := True;
               return;
            elsif Self.At_End or else Outcome = Read_Failed then
               Item := 0;
               Available := False;
               return;
            else
               Fill;
            end if;
         end loop;
      end Read_Source_Byte;

      procedure Initialize_Encoding is
         Item      : Ada.Streams.Stream_Element;
         Available : Boolean;
         Skip      : Natural range 0 .. 3 := 0;
         Has_UTF_8_BOM : Boolean;
         Has_LE_BOM    : Boolean;
         Has_BE_BOM    : Boolean;
      begin
         if Self.Active /= Encoding_Undetermined then
            return;
         end if;

         while Self.Prefix_Count < Self.Prefix'Length loop
            Read_Source_Byte (Item, Available);
            exit when not Available;
            Self.Prefix_Count := Self.Prefix_Count + 1;
            Self.Prefix (Self.Prefix_Count) := Item;
         end loop;

         Has_UTF_8_BOM :=
           Self.Prefix_Count = 3
           and then Self.Prefix (1) = 16#EF#
           and then Self.Prefix (2) = 16#BB#
           and then Self.Prefix (3) = 16#BF#;
         Has_LE_BOM :=
           Self.Prefix_Count >= 2
           and then Self.Prefix (1) = 16#FF#
           and then Self.Prefix (2) = 16#FE#;
         Has_BE_BOM :=
           Self.Prefix_Count >= 2
           and then Self.Prefix (1) = 16#FE#
           and then Self.Prefix (2) = 16#FF#;

         case Self.Requested_Encoding is
            when No_Encoding =>
               Self.Active := Encoding_Raw;
            when Automatic_Encoding =>
               if Has_UTF_8_BOM then
                  Self.Active := Encoding_UTF_8;
                  Skip := 3;
               elsif Has_LE_BOM then
                  Self.Active := Encoding_UTF_16LE;
                  Skip := 2;
               elsif Has_BE_BOM then
                  Self.Active := Encoding_UTF_16BE;
                  Skip := 2;
               else
                  Self.Active := Encoding_Raw;
               end if;
            when UTF_8_Encoding =>
               Self.Active := Encoding_UTF_8;
               Skip := (if Has_UTF_8_BOM then 3 else 0);
            when UTF_16_Encoding =>
               if Has_BE_BOM then
                  Self.Active := Encoding_UTF_16BE;
                  Skip := 2;
               else
                  Self.Active := Encoding_UTF_16LE;
                  Skip := (if Has_LE_BOM then 2 else 0);
               end if;
            when UTF_16LE_Encoding =>
               if Has_BE_BOM then
                  Self.Active := Encoding_UTF_16BE;
                  Skip := 2;
               else
                  Self.Active := Encoding_UTF_16LE;
                  Skip := (if Has_LE_BOM then 2 else 0);
               end if;
            when UTF_16BE_Encoding =>
               if Has_LE_BOM then
                  Self.Active := Encoding_UTF_16LE;
                  Skip := 2;
               else
                  Self.Active := Encoding_UTF_16BE;
                  Skip := (if Has_BE_BOM then 2 else 0);
               end if;
            when IBM866_Encoding =>
               Self.Active := Encoding_IBM866;
            when ISO_8859_2_Encoding =>
               Self.Active := Encoding_ISO_8859_2;
            when ISO_8859_3_Encoding =>
               Self.Active := Encoding_ISO_8859_3;
            when ISO_8859_4_Encoding =>
               Self.Active := Encoding_ISO_8859_4;
            when ISO_8859_5_Encoding =>
               Self.Active := Encoding_ISO_8859_5;
            when ISO_8859_6_Encoding =>
               Self.Active := Encoding_ISO_8859_6;
            when ISO_8859_7_Encoding =>
               Self.Active := Encoding_ISO_8859_7;
            when ISO_8859_8_Encoding =>
               Self.Active := Encoding_ISO_8859_8;
            when ISO_8859_10_Encoding =>
               Self.Active := Encoding_ISO_8859_10;
            when ISO_8859_13_Encoding =>
               Self.Active := Encoding_ISO_8859_13;
            when ISO_8859_14_Encoding =>
               Self.Active := Encoding_ISO_8859_14;
            when ISO_8859_15_Encoding =>
               Self.Active := Encoding_ISO_8859_15;
            when ISO_8859_16_Encoding =>
               Self.Active := Encoding_ISO_8859_16;
            when KOI8_R_Encoding =>
               Self.Active := Encoding_KOI8_R;
            when KOI8_U_Encoding =>
               Self.Active := Encoding_KOI8_U;
            when Macintosh_Encoding =>
               Self.Active := Encoding_Macintosh;
            when Windows_874_Encoding =>
               Self.Active := Encoding_Windows_874;
            when Windows_1250_Encoding =>
               Self.Active := Encoding_Windows_1250;
            when Windows_1251_Encoding =>
               Self.Active := Encoding_Windows_1251;
            when Windows_1252_Encoding =>
               Self.Active := Encoding_Windows_1252;
            when Windows_1253_Encoding =>
               Self.Active := Encoding_Windows_1253;
            when Windows_1254_Encoding =>
               Self.Active := Encoding_Windows_1254;
            when Windows_1255_Encoding =>
               Self.Active := Encoding_Windows_1255;
            when Windows_1256_Encoding =>
               Self.Active := Encoding_Windows_1256;
            when Windows_1257_Encoding =>
               Self.Active := Encoding_Windows_1257;
            when Windows_1258_Encoding =>
               Self.Active := Encoding_Windows_1258;
            when X_Mac_Cyrillic_Encoding =>
               Self.Active := Encoding_X_Mac_Cyrillic;
            when GBK_Encoding =>
               Self.Active := Encoding_GBK;
            when GB18030_Encoding =>
               Self.Active := Encoding_GB18030;
            when Big5_Encoding =>
               Self.Active := Encoding_Big5;
            when EUC_JP_Encoding =>
               Self.Active := Encoding_EUC_JP;
            when ISO_2022_JP_Encoding =>
               Self.Active := Encoding_ISO_2022_JP;
            when Shift_JIS_Encoding =>
               Self.Active := Encoding_Shift_JIS;
            when EUC_KR_Encoding =>
               Self.Active := Encoding_EUC_KR;
            when Replacement_Encoding =>
               Self.Active := Encoding_Replacement;
            when X_User_Defined_Encoding =>
               Self.Active := Encoding_X_User_Defined;
         end case;
         Self.Prefix_Next := Skip + 1;
      end Initialize_Encoding;

      procedure Read_Raw_Byte
        (Item      : out Ada.Streams.Stream_Element;
         Available : out Boolean) is
      begin
         if Self.Pushback_Count > 0 then
            Item := Self.Pushback (1);
            for Index in 1 .. Self.Pushback_Count - 1 loop
               Self.Pushback (Index) := Self.Pushback (Index + 1);
            end loop;
            Self.Pushback_Count := Self.Pushback_Count - 1;
            Available := True;
         elsif Self.Prefix_Next <= Self.Prefix_Count then
            Item := Self.Prefix (Self.Prefix_Next);
            Self.Prefix_Next := Self.Prefix_Next + 1;
            Available := True;
         else
            Read_Source_Byte (Item, Available);
         end if;
      end Read_Raw_Byte;

      procedure Read_Decoded_Byte (Item : out Character; Available : out Boolean) is
         Raw            : Ada.Streams.Stream_Element;
         Raw_Available  : Boolean;
         Second         : Ada.Streams.Stream_Element;
         Second_Available : Boolean;
         Third          : Ada.Streams.Stream_Element;
         Third_Available : Boolean;
         Fourth         : Ada.Streams.Stream_Element;
         Fourth_Available : Boolean;
         Unit           : Natural;
         Code_Point     : Long_Long_Integer;
         Pointer        : Natural;
         Decoded_Point  : Encoding.Code_Point;
         Consumed       : Boolean;
         Status         : Posix_Tools.Text.UTF_8.Decode_Status;

         procedure Queue (Text : String);
         procedure Queue_Code_Point (Value : Long_Long_Integer);
         procedure Queue_Replacement;
         procedure Unread (Value : Ada.Streams.Stream_Element);

         procedure Queue (Text : String) is
         begin
            Self.Decoded (1 .. Text'Length) := Text;
            Self.Decoded_Next := 1;
            Self.Decoded_Last := Text'Length;
         end Queue;

         procedure Queue_Code_Point (Value : Long_Long_Integer) is
         begin
            if Value < 0 then
               Queue_Replacement;
            else
               Queue (Posix_Tools.Text.UTF_8.Encode (Value));
            end if;
         end Queue_Code_Point;

         procedure Queue_Replacement is
         begin
            Queue (Character'Val (16#EF#) & Character'Val (16#BF#) & Character'Val (16#BD#));
         end Queue_Replacement;

         procedure Unread (Value : Ada.Streams.Stream_Element) is
         begin
            if Self.Pushback_Count < Self.Pushback'Length then
               for Index in reverse 1 .. Self.Pushback_Count loop
                  Self.Pushback (Index + 1) := Self.Pushback (Index);
               end loop;
               Self.Pushback (1) := Value;
               Self.Pushback_Count := Self.Pushback_Count + 1;
            end if;
         end Unread;
      begin
         Initialize_Encoding;
         loop
            if Self.Decoded_Next <= Self.Decoded_Last then
               Item := Self.Decoded (Self.Decoded_Next);
               Self.Decoded_Next := Self.Decoded_Next + 1;
               Available := True;
               return;
            end if;
            Self.Decoded_Next := 1;
            Self.Decoded_Last := 0;

            case Self.Active is
               when Encoding_Undetermined =>
                  Item := Character'Val (0);
                  Available := False;
                  return;
               when Encoding_Raw =>
                  Read_Raw_Byte (Raw, Raw_Available);
                  if not Raw_Available then
                     Item := Character'Val (0);
                     Available := False;
                     return;
                  end if;
                  Queue (String'(1 => Character'Val (Raw)));
               when Encoding_UTF_8 =>
                  if Self.Has_Retry_Byte then
                     Raw := Self.Retry_Byte;
                     Self.Has_Retry_Byte := False;
                     Raw_Available := True;
                  else
                     Read_Raw_Byte (Raw, Raw_Available);
                  end if;
                  if not Raw_Available then
                     if Self.UTF_8_Length > 0 then
                        Self.UTF_8_Length := 0;
                        Queue_Replacement;
                     else
                        Item := Character'Val (0);
                        Available := False;
                        return;
                     end if;
                  else
                     Posix_Tools.Text.UTF_8.Decode
                       (Self.UTF_8_Decoder, Natural (Raw), Status, Code_Point, Consumed);
                     if Consumed then
                        if Self.UTF_8_Length < Self.UTF_8_Sequence'Length then
                           Self.UTF_8_Length := Self.UTF_8_Length + 1;
                           Self.UTF_8_Sequence (Self.UTF_8_Length) := Character'Val (Raw);
                        end if;
                     else
                        Self.Retry_Byte := Raw;
                        Self.Has_Retry_Byte := True;
                     end if;

                     case Status is
                        when Posix_Tools.Text.UTF_8.Need_More =>
                           null;
                        when Posix_Tools.Text.UTF_8.Complete =>
                           Queue (Self.UTF_8_Sequence (1 .. Self.UTF_8_Length));
                           Self.UTF_8_Length := 0;
                        when Posix_Tools.Text.UTF_8.Invalid =>
                           Self.UTF_8_Length := 0;
                           Queue_Replacement;
                     end case;
                  end if;
               when Encoding_UTF_16LE | Encoding_UTF_16BE =>
                  if Self.Has_Retry_Unit then
                     Unit := Self.Retry_Unit;
                     Self.Has_Retry_Unit := False;
                     Raw_Available := True;
                  else
                     Read_Raw_Byte (Raw, Raw_Available);
                     if Raw_Available then
                        Read_Raw_Byte (Second, Second_Available);
                        if not Second_Available then
                           Queue_Replacement;
                           Raw_Available := False;
                        else
                           Unit :=
                             (if Self.Active = Encoding_UTF_16LE
                              then Natural (Raw) + 256 * Natural (Second)
                              else 256 * Natural (Raw) + Natural (Second));
                        end if;
                     end if;
                  end if;

                  if not Raw_Available then
                     if Self.Decoded_Last > 0 then
                        null;
                     elsif Self.Pending_High /= 0 then
                        Self.Pending_High := 0;
                        Queue_Replacement;
                     else
                        Item := Character'Val (0);
                        Available := False;
                        return;
                     end if;
                  elsif Self.Pending_High /= 0 then
                     if Unit in 16#DC00# .. 16#DFFF# then
                        Queue_Code_Point
                          (16#10000#
                           + 16#400# * Long_Long_Integer (Self.Pending_High - 16#D800#)
                           + Long_Long_Integer (Unit - 16#DC00#));
                        Self.Pending_High := 0;
                     else
                        Self.Pending_High := 0;
                        Self.Retry_Unit := Unit;
                        Self.Has_Retry_Unit := True;
                        Queue_Replacement;
                     end if;
                  elsif Unit in 16#D800# .. 16#DBFF# then
                     Self.Pending_High := Unit;
                  elsif Unit in 16#DC00# .. 16#DFFF# then
                     Queue_Replacement;
                  else
                     Queue_Code_Point (Long_Long_Integer (Unit));
                  end if;
               when Encoding_IBM866
                  | Encoding_ISO_8859_2
                  | Encoding_ISO_8859_3
                  | Encoding_ISO_8859_4
                  | Encoding_ISO_8859_5
                  | Encoding_ISO_8859_6
                  | Encoding_ISO_8859_7
                  | Encoding_ISO_8859_8
                  | Encoding_ISO_8859_10
                  | Encoding_ISO_8859_13
                  | Encoding_ISO_8859_14
                  | Encoding_ISO_8859_15
                  | Encoding_ISO_8859_16
                  | Encoding_KOI8_R
                  | Encoding_KOI8_U
                  | Encoding_Macintosh
                  | Encoding_Windows_874
                  | Encoding_Windows_1250
                  | Encoding_Windows_1251
                  | Encoding_Windows_1252
                  | Encoding_Windows_1253
                  | Encoding_Windows_1254
                  | Encoding_Windows_1255
                  | Encoding_Windows_1256
                  | Encoding_Windows_1257
                  | Encoding_Windows_1258
                  | Encoding_X_Mac_Cyrillic =>
                  Read_Raw_Byte (Raw, Raw_Available);
                  if not Raw_Available then
                     Item := Character'Val (0);
                     Available := False;
                     return;
                  end if;
                  declare
                     Kind : constant Encoding.Single_Byte_Kind :=
                       (case Self.Active is
                           when Encoding_IBM866 => Encoding.IBM866_Kind,
                           when Encoding_ISO_8859_2 => Encoding.ISO_8859_2_Kind,
                           when Encoding_ISO_8859_3 => Encoding.ISO_8859_3_Kind,
                           when Encoding_ISO_8859_4 => Encoding.ISO_8859_4_Kind,
                           when Encoding_ISO_8859_5 => Encoding.ISO_8859_5_Kind,
                           when Encoding_ISO_8859_6 => Encoding.ISO_8859_6_Kind,
                           when Encoding_ISO_8859_7 => Encoding.ISO_8859_7_Kind,
                           when Encoding_ISO_8859_8 => Encoding.ISO_8859_8_Kind,
                           when Encoding_ISO_8859_10 => Encoding.ISO_8859_10_Kind,
                           when Encoding_ISO_8859_13 => Encoding.ISO_8859_13_Kind,
                           when Encoding_ISO_8859_14 => Encoding.ISO_8859_14_Kind,
                           when Encoding_ISO_8859_15 => Encoding.ISO_8859_15_Kind,
                           when Encoding_ISO_8859_16 => Encoding.ISO_8859_16_Kind,
                           when Encoding_KOI8_R => Encoding.KOI8_R_Kind,
                           when Encoding_KOI8_U => Encoding.KOI8_U_Kind,
                           when Encoding_Macintosh => Encoding.Macintosh_Kind,
                           when Encoding_Windows_874 => Encoding.Windows_874_Kind,
                           when Encoding_Windows_1250 => Encoding.Windows_1250_Kind,
                           when Encoding_Windows_1251 => Encoding.Windows_1251_Kind,
                           when Encoding_Windows_1252 => Encoding.Windows_1252_Kind,
                           when Encoding_Windows_1253 => Encoding.Windows_1253_Kind,
                           when Encoding_Windows_1254 => Encoding.Windows_1254_Kind,
                           when Encoding_Windows_1255 => Encoding.Windows_1255_Kind,
                           when Encoding_Windows_1256 => Encoding.Windows_1256_Kind,
                           when Encoding_Windows_1257 => Encoding.Windows_1257_Kind,
                           when Encoding_Windows_1258 => Encoding.Windows_1258_Kind,
                           when Encoding_X_Mac_Cyrillic => Encoding.X_Mac_Cyrillic_Kind,
                           when others => Encoding.Windows_1252_Kind);
                  begin
                     Queue_Code_Point (Long_Long_Integer (Encoding.Decode_Single_Byte (Kind, Raw)));
                  end;

               when Encoding_X_User_Defined =>
                  Read_Raw_Byte (Raw, Raw_Available);
                  if not Raw_Available then
                     Item := Character'Val (0);
                     Available := False;
                     return;
                  end if;
                  Queue_Code_Point
                    ((if Raw < 16#80# then Long_Long_Integer (Raw) else Long_Long_Integer (Raw) + 16#F700#));

               when Encoding_Replacement =>
                  if Self.Replacement_Emitted then
                     loop
                        Read_Raw_Byte (Raw, Raw_Available);
                        exit when not Raw_Available;
                     end loop;
                     Item := Character'Val (0);
                     Available := False;
                     return;
                  end if;
                  Read_Raw_Byte (Raw, Raw_Available);
                  if not Raw_Available then
                     Item := Character'Val (0);
                     Available := False;
                     return;
                  end if;
                  Self.Replacement_Emitted := True;
                  Queue_Replacement;

               when Encoding_Big5 =>
                  Read_Raw_Byte (Raw, Raw_Available);
                  if not Raw_Available then
                     Item := Character'Val (0);
                     Available := False;
                     return;
                  elsif Raw < 16#80# then
                     Queue (String'(1 => Character'Val (Raw)));
                  elsif Raw not in 16#81# .. 16#FE# then
                     Queue_Replacement;
                  else
                     Read_Raw_Byte (Second, Second_Available);
                     if not Second_Available then
                        Queue_Replacement;
                     elsif Second in 16#40# .. 16#7E# then
                        Pointer := Natural (Raw - 16#81#) * 157 + Natural (Second - 16#40#);
                        Decoded_Point := Encoding.Decode_Big5 (Pointer);
                        if Pointer = 1_133 then
                           Queue
                             (Posix_Tools.Text.UTF_8.Encode (16#00CA#)
                              & Posix_Tools.Text.UTF_8.Encode (16#0304#));
                        elsif Pointer = 1_135 then
                           Queue
                             (Posix_Tools.Text.UTF_8.Encode (16#00CA#)
                              & Posix_Tools.Text.UTF_8.Encode (16#030C#));
                        elsif Pointer = 1_164 then
                           Queue
                             (Posix_Tools.Text.UTF_8.Encode (16#00EA#)
                              & Posix_Tools.Text.UTF_8.Encode (16#0304#));
                        elsif Pointer = 1_166 then
                           Queue
                             (Posix_Tools.Text.UTF_8.Encode (16#00EA#)
                              & Posix_Tools.Text.UTF_8.Encode (16#030C#));
                        else
                           if Decoded_Point = Encoding.Invalid_Code_Point then
                              Unread (Second);
                           end if;
                           Queue_Code_Point (Long_Long_Integer (Decoded_Point));
                        end if;
                     elsif Second in 16#A1# .. 16#FE# then
                        Pointer := Natural (Raw - 16#81#) * 157 + Natural (Second - 16#62#);
                        Decoded_Point := Encoding.Decode_Big5 (Pointer);
                        Queue_Code_Point (Long_Long_Integer (Decoded_Point));
                     else
                        if Second < 16#80# then
                           Unread (Second);
                        end if;
                        Queue_Replacement;
                     end if;
                  end if;

               when Encoding_EUC_KR =>
                  Read_Raw_Byte (Raw, Raw_Available);
                  if not Raw_Available then
                     Item := Character'Val (0);
                     Available := False;
                     return;
                  elsif Raw < 16#80# then
                     Queue (String'(1 => Character'Val (Raw)));
                  elsif Raw not in 16#81# .. 16#FE# then
                     Queue_Replacement;
                  else
                     Read_Raw_Byte (Second, Second_Available);
                     if not Second_Available then
                        Queue_Replacement;
                     elsif Second in 16#41# .. 16#7E# then
                        Pointer := Natural (Raw - 16#81#) * 190 + Natural (Second - 16#41#);
                        Decoded_Point := Encoding.Decode_EUC_KR (Pointer);
                        if Decoded_Point = Encoding.Invalid_Code_Point then
                           Unread (Second);
                        end if;
                        Queue_Code_Point (Long_Long_Integer (Decoded_Point));
                     elsif Second in 16#80# .. 16#FE# then
                        Pointer := Natural (Raw - 16#81#) * 190 + Natural (Second - 16#41#);
                        Queue_Code_Point (Long_Long_Integer (Encoding.Decode_EUC_KR (Pointer)));
                     else
                        if Second < 16#80# then
                           Unread (Second);
                        end if;
                        Queue_Replacement;
                     end if;
                  end if;

               when Encoding_Shift_JIS =>
                  Read_Raw_Byte (Raw, Raw_Available);
                  if not Raw_Available then
                     Item := Character'Val (0);
                     Available := False;
                     return;
                  elsif Raw < 16#80# or else Raw = 16#80# then
                     Queue_Code_Point (Long_Long_Integer (Raw));
                  elsif Raw in 16#A1# .. 16#DF# then
                     Queue_Code_Point (16#FF61# + Long_Long_Integer (Raw - 16#A1#));
                  elsif Raw not in 16#81# .. 16#9F# and then Raw not in 16#E0# .. 16#FC# then
                     Queue_Replacement;
                  else
                     Read_Raw_Byte (Second, Second_Available);
                     if not Second_Available then
                        Queue_Replacement;
                     elsif Second in 16#40# .. 16#7E# or else Second in 16#80# .. 16#FC# then
                        Pointer :=
                          Natural
                            ((if Raw <= 16#9F# then Raw - 16#81# else Raw - 16#C1#)) * 188
                          + Natural
                              ((if Second <= 16#7E# then Second - 16#40# else Second - 16#41#));
                        Decoded_Point :=
                          (if Pointer in 8_836 .. 10_715
                           then Encoding.Code_Point (Pointer - 8_836 + 16#E000#)
                           else Encoding.Decode_JIS0208 (Pointer));
                        if Decoded_Point = Encoding.Invalid_Code_Point and then Second < 16#80# then
                           Unread (Second);
                        end if;
                        Queue_Code_Point (Long_Long_Integer (Decoded_Point));
                     else
                        if Second < 16#80# then
                           Unread (Second);
                        end if;
                        Queue_Replacement;
                     end if;
                  end if;

               when Encoding_EUC_JP =>
                  Read_Raw_Byte (Raw, Raw_Available);
                  if not Raw_Available then
                     Item := Character'Val (0);
                     Available := False;
                     return;
                  elsif Raw < 16#80# then
                     Queue (String'(1 => Character'Val (Raw)));
                  elsif Raw = 16#8E# then
                     Read_Raw_Byte (Second, Second_Available);
                     if Second_Available and then Second in 16#A1# .. 16#DF# then
                        Queue_Code_Point (16#FF61# + Long_Long_Integer (Second - 16#A1#));
                     else
                        if Second_Available and then Second < 16#80# then
                           Unread (Second);
                        end if;
                        Queue_Replacement;
                     end if;
                  elsif Raw = 16#8F# then
                     Read_Raw_Byte (Second, Second_Available);
                     if not Second_Available or else Second not in 16#A1# .. 16#FE# then
                        if Second_Available and then Second < 16#80# then
                           Unread (Second);
                        end if;
                        Queue_Replacement;
                     else
                        Read_Raw_Byte (Third, Third_Available);
                        if Third_Available and then Third in 16#A1# .. 16#FE# then
                           Pointer := Natural (Second - 16#A1#) * 94 + Natural (Third - 16#A1#);
                           Queue_Code_Point (Long_Long_Integer (Encoding.Decode_JIS0212 (Pointer)));
                        else
                           if Third_Available and then Third < 16#80# then
                              Unread (Third);
                           end if;
                           Queue_Replacement;
                        end if;
                     end if;
                  elsif Raw in 16#A1# .. 16#FE# then
                     Read_Raw_Byte (Second, Second_Available);
                     if Second_Available and then Second in 16#A1# .. 16#FE# then
                        Pointer := Natural (Raw - 16#A1#) * 94 + Natural (Second - 16#A1#);
                        Queue_Code_Point (Long_Long_Integer (Encoding.Decode_JIS0208 (Pointer)));
                     else
                        if Second_Available and then Second < 16#80# then
                           Unread (Second);
                        end if;
                        Queue_Replacement;
                     end if;
                  else
                     Queue_Replacement;
                  end if;

               when Encoding_GBK | Encoding_GB18030 =>
                  Read_Raw_Byte (Raw, Raw_Available);
                  if not Raw_Available then
                     Item := Character'Val (0);
                     Available := False;
                     return;
                  elsif Raw < 16#80# then
                     Queue (String'(1 => Character'Val (Raw)));
                  elsif Raw = 16#80# then
                     Queue_Code_Point (16#20AC#);
                  elsif Raw not in 16#81# .. 16#FE# then
                     Queue_Replacement;
                  else
                     Read_Raw_Byte (Second, Second_Available);
                     if not Second_Available then
                        Queue_Replacement;
                     elsif Self.Active = Encoding_GB18030 and then Second in 16#30# .. 16#39# then
                        Read_Raw_Byte (Third, Third_Available);
                        if not Third_Available or else Third not in 16#81# .. 16#FE# then
                           if Third_Available then
                              Unread (Third);
                           end if;
                           Unread (Second);
                           Queue_Replacement;
                        else
                           Read_Raw_Byte (Fourth, Fourth_Available);
                           if not Fourth_Available or else Fourth not in 16#30# .. 16#39# then
                              if Fourth_Available then
                                 Unread (Fourth);
                              end if;
                              Unread (Third);
                              Unread (Second);
                              Queue_Replacement;
                           else
                              Pointer :=
                                Natural (Raw - 16#81#) * 10 * 126 * 10
                                + Natural (Second - 16#30#) * 10 * 126
                                + Natural (Third - 16#81#) * 10
                                + Natural (Fourth - 16#30#);
                              Decoded_Point :=
                                (if Pointer = 7_457
                                 then 16#E7C7#
                                 else Encoding.Decode_GB18030_Range (Pointer));
                              Queue_Code_Point (Long_Long_Integer (Decoded_Point));
                           end if;
                        end if;
                     elsif Second in 16#40# .. 16#7E# then
                        Pointer := Natural (Raw - 16#81#) * 190 + Natural (Second - 16#40#);
                        Queue_Code_Point
                          (Long_Long_Integer (Encoding.Decode_GB18030_Two_Byte (Pointer)));
                     elsif Second in 16#80# .. 16#FE# then
                        Pointer := Natural (Raw - 16#81#) * 190 + Natural (Second - 16#41#);
                        Queue_Code_Point
                          (Long_Long_Integer (Encoding.Decode_GB18030_Two_Byte (Pointer)));
                     else
                        if Second < 16#80# then
                           Unread (Second);
                        end if;
                        Queue_Replacement;
                     end if;
                  end if;

               when Encoding_ISO_2022_JP =>
                  Read_Raw_Byte (Raw, Raw_Available);
                  if not Raw_Available then
                     Item := Character'Val (0);
                     Available := False;
                     return;
                  elsif Raw = 16#1B# then
                     Read_Raw_Byte (Second, Second_Available);
                     if not Second_Available then
                        Queue_Replacement;
                     elsif Second not in 16#24# | 16#28# then
                        Self.ISO_Output_Flag := False;
                        Unread (Second);
                        Queue_Replacement;
                     else
                        Read_Raw_Byte (Third, Third_Available);
                        if not Third_Available then
                           Unread (Second);
                           Queue_Replacement;
                        else
                           declare
                              Valid     : Boolean := True;
                              New_State : ISO_2022_State := Self.ISO_State;
                              Previous  : constant Boolean := Self.ISO_Output_Flag;
                           begin
                              if Second = 16#28# and then Third = 16#42# then
                                 New_State := ISO_ASCII;
                              elsif Second = 16#28# and then Third = 16#4A# then
                                 New_State := ISO_Roman;
                              elsif Second = 16#28# and then Third = 16#49# then
                                 New_State := ISO_Katakana;
                              elsif Second = 16#24# and then Third in 16#40# | 16#42# then
                                 New_State := ISO_JIS0208;
                              else
                                 Valid := False;
                              end if;
                              if Valid then
                                 Self.ISO_State := New_State;
                                 Self.ISO_Output_Flag := True;
                                 if Previous then
                                    Queue_Replacement;
                                 end if;
                              else
                                 Self.ISO_Output_Flag := False;
                                 Unread (Third);
                                 Unread (Second);
                                 Queue_Replacement;
                              end if;
                           end;
                        end if;
                     end if;
                  else
                     Self.ISO_Output_Flag := False;
                     case Self.ISO_State is
                        when ISO_ASCII =>
                           if Raw > 16#7F# or else Raw in 16#0E# | 16#0F# then
                              Queue_Replacement;
                           else
                              Queue (String'(1 => Character'Val (Raw)));
                           end if;
                        when ISO_Roman =>
                           if Raw = 16#5C# then
                              Queue_Code_Point (16#00A5#);
                           elsif Raw = 16#7E# then
                              Queue_Code_Point (16#203E#);
                           elsif Raw > 16#7F# or else Raw in 16#0E# | 16#0F# then
                              Queue_Replacement;
                           else
                              Queue (String'(1 => Character'Val (Raw)));
                           end if;
                        when ISO_Katakana =>
                           if Raw in 16#21# .. 16#5F# then
                              Queue_Code_Point (16#FF61# + Long_Long_Integer (Raw - 16#21#));
                           else
                              Queue_Replacement;
                           end if;
                        when ISO_JIS0208 =>
                           if Raw not in 16#21# .. 16#7E# then
                              Queue_Replacement;
                           else
                              Read_Raw_Byte (Second, Second_Available);
                              if not Second_Available then
                                 Queue_Replacement;
                              elsif Second = 16#1B# then
                                 Unread (Second);
                                 Queue_Replacement;
                              elsif Second in 16#21# .. 16#7E# then
                                 Pointer := Natural (Raw - 16#21#) * 94 + Natural (Second - 16#21#);
                                 Queue_Code_Point
                                   (Long_Long_Integer (Encoding.Decode_JIS0208 (Pointer)));
                              else
                                 Queue_Replacement;
                              end if;
                           end if;
                     end case;
                  end if;
            end case;
         end loop;
      end Read_Decoded_Byte;
   begin
      Line := Null_Unbounded_String;
      Terminated := False;
      Nul_Offset := No_Nul_Byte;
      Outcome := End_Of_Input;

      loop
         declare
            Item      : Character;
            Available : Boolean;
         begin
            Read_Decoded_Byte (Item, Available);
            if not Available then
               if Outcome = Read_Failed then
                  return;
               elsif Dropping then
                  Outcome := Line_Too_Long;
               elsif Length (Line) > 0 then
                  Outcome := Line_Available;
               end if;
               return;
            end if;
            if Item = Delimiter then
               Terminated := True;
               Outcome := (if Dropping then Line_Too_Long else Line_Available);
               return;
            else
               if Item = ASCII.NUL and then Nul_Offset = No_Nul_Byte then
                  Nul_Offset := Record_Bytes;
               end if;
               if Record_Bytes < Natural'Last then
                  Record_Bytes := Record_Bytes + 1;
               end if;
               if Dropping then
                  null;
               elsif Length (Line) = Maximum_Line_Bytes then
                  Dropping := True;
               else
                  Append (Line, Item);
               end if;
            end if;
         end;
      end loop;
   end Next;

   procedure Close (Self : in out Reader; Ok : out Boolean) is
   begin
      case Self.Source is
         when Standard_Input =>
            Ok := True;
         when Spooled_Standard_Input =>
            Ok := Posix_Tools.Host_Adapters.Temporary_Storage.Cleanup_Or_Defer
              (Self.Spool);
         when Named_File =>
            Posix_Tools.Host_Adapters.Input_Files.Close (Self.File, Ok);
      end case;
   end Close;
end Posix_Tools.Commands.Rg.Input;
