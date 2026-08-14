with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;
with Ada.Containers;
with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Conversion;
with Interfaces;
with I18N.Collation;
with I18N.CLDR_Data;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Clock;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Host_Adapters.Host;
with Posix_Tools.Host_Adapters.Signals;
with Posix_Tools.Localization;
with Posix_Tools.Numbers;
with Posix_Tools.Paths;
with Posix_Tools.Text.Classification;
with Posix_Tools.Text.UTF_8;

package body Posix_Tools.Commands.Expanded is
   use Ada.Strings.Unbounded;
   use type Interfaces.Unsigned_64;

   NUL : constant Character := Character'Val (0);
   BS  : constant Character := Character'Val (8);
   HT  : constant Character := Character'Val (9);
   LF  : constant Character := Character'Val (10);
   FF  : constant Character := Character'Val (12);
   CR  : constant Character := Character'Val (13);

   package String_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);
   package String_Vector_Sorting is new String_Vectors.Generic_Sorting;
   type Sort_Key_Definition is record
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Fold_Case : Boolean := False;
      Numeric_Sort : Boolean := False;
      Ignore_Leading_Blanks : Boolean := False;
      Dictionary_Order : Boolean := False;
      Ignore_Nonprinting : Boolean := False;
      Reverse_Order : Boolean := False;
   end record;
   package Sort_Key_Vectors is new Ada.Containers.Vectors (Positive, Sort_Key_Definition);
   use type Ada.Containers.Count_Type;
   use type Ada.Calendar.Time;
   use type Ada.Calendar.Formatting.Day_Name;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Exit_Status.Code;
   use type Posix_Tools.Numbers.Count;
   use type Posix_Tools.Numbers.Parse_Status;
   use type Posix_Tools.Text.UTF_8.Decode_Status;
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Host renames Posix_Tools.Host_Adapters.Host;
   package Signals renames Posix_Tools.Host_Adapters.Signals;
   use type Posix_Tools.Host_Adapters.File_System.Copy_File_Status;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;
   use type Posix_Tools.Host_Adapters.File_System.Special_File_Kind;

   function Trimmed_Image (Value : Integer) return String is
   begin
      return Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Left);
   end Trimmed_Image;

   function Parse_Natural_Text (Text : String; Value : out Natural) return Boolean is
      Acc : Long_Long_Integer := 0;
   begin
      if Text = "" then
         Value := 0;
         return False;
      end if;

      for Ch of Text loop
         if Ch not in '0' .. '9' then
            Value := 0;
            return False;
         end if;
         Acc := Acc * 10 + Long_Long_Integer (Character'Pos (Ch) - Character'Pos ('0'));
         if Acc > Long_Long_Integer (Natural'Last) then
            Value := 0;
            return False;
         end if;
      end loop;

      Value := Natural (Acc);
      return True;
   end Parse_Natural_Text;

   procedure Set_Success
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
   begin
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Set_Success;

   function Read_Standard_Input (Context : in out Posix_Tools.Commands.Contexts.Context'Class) return String is
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 16 * 1024);
      Last   : Ada.Streams.Stream_Element_Offset;
      Text   : Unbounded_String;
   begin
      loop
         exit when not Context.Try_Read_Standard_Input (Buffer, Last);
         exit when Last < Buffer'First;

         for I in Buffer'First .. Last loop
            Append (Text, Character'Val (Integer (Buffer (I))));
         end loop;
      end loop;

      return To_String (Text);
   end Read_Standard_Input;

   function Read_File (Path : String; Ok : out Boolean) return String is
      use Ada.Streams.Stream_IO;
      File   : File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 16 * 1024);
      Last   : Ada.Streams.Stream_Element_Offset;
      Text   : Unbounded_String;
   begin
      Ok := False;
      Open (File, In_File, Path);
      while not End_Of_File (File) loop
         Read (File, Buffer, Last);
         for I in Buffer'First .. Last loop
            Append (Text, Character'Val (Integer (Buffer (I))));
         end loop;
      end loop;
      Close (File);
      Ok := True;
      return To_String (Text);
   exception
      when others =>
         if Is_Open (File) then
            Close (File);
         end if;
         return "";
   end Read_File;

   function Join_Path (Directory, Leaf : String) return String;

   procedure Write_File (Path : String; Text : String; Append_Mode : Boolean; Ok : out Boolean) is
      use Ada.Streams.Stream_IO;
      File   : File_Type;
   begin
      Ok := False;
      if Append_Mode and then FS.Exists (Path) then
         Open (File, Append_File, Path);
      else
         Create (File, Out_File, Path);
      end if;

      if Text'Length > 0 then
         declare
            Buffer : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Text'Length));
            Target : Ada.Streams.Stream_Element_Offset := Buffer'First;
         begin
            for Ch of Text loop
               Buffer (Target) := Ada.Streams.Stream_Element (Character'Pos (Ch));
               Target := Target + 1;
            end loop;
            Write (File, Buffer);
         end;
      end if;
      Close (File);
      Ok := True;
   exception
      when others =>
         if Is_Open (File) then
            Close (File);
         end if;
   end Write_File;

   procedure Copy_Path
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Source  : String;
      Target  : String;
      Recursive : Boolean;
      Preserve_Mode : Boolean;
      Preserve_Links : Boolean;
      Ok      : out Boolean)
   is
      function Full_Path_Or_Raw (Path : String) return String is
      begin
         return FS.Full_Name (Path);
      exception
         when others =>
            return Path;
      end Full_Path_Or_Raw;

      function Without_Trailing_Separators (Path : String) return String is
         Last : Natural := Path'Last;
      begin
         while Last > Path'First and then Path (Last) in '/' | '\' loop
            Last := Last - 1;
         end loop;

         return Path (Path'First .. Last);
      end Without_Trailing_Separators;

      function Is_Same_Or_Descendant (Parent, Child : String) return Boolean is
         Parent_Full : constant String := Without_Trailing_Separators (Full_Path_Or_Raw (Parent));
         Child_Full  : constant String := Without_Trailing_Separators (Full_Path_Or_Raw (Child));
      begin
         if Child_Full = Parent_Full then
            return True;
         elsif Child_Full'Length <= Parent_Full'Length then
            return False;
         elsif Child_Full (Child_Full'First .. Child_Full'First + Parent_Full'Length - 1) /= Parent_Full then
            return False;
         else
            return Child_Full (Child_Full'First + Parent_Full'Length) in '/' | '\';
         end if;
      end Is_Same_Or_Descendant;

      procedure Apply_Source_Metadata is
         Available : Boolean;
         Mode      : constant Natural := FS.File_Permission_Bits (Source, Available);

         procedure Apply_Source_Ownership is
            Source_User      : Natural;
            Source_Group     : Natural;
            Source_Available : Boolean;
            Target_User      : Natural;
            Target_Group     : Natural;
            Target_Available : Boolean;
         begin
            if not Preserve_Mode or else not FS.Ownership_Supported then
               return;
            end if;

            FS.File_Ownership (Source, Source_User, Source_Group, Source_Available);
            FS.File_Ownership (Target, Target_User, Target_Group, Target_Available);
            if Source_Available
              and then Target_Available
              and then (Source_User /= Target_User or else Source_Group /= Target_Group)
              and then not FS.Set_Ownership (Target, Source_User, Source_Group)
            then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            end if;
         end Apply_Source_Ownership;
      begin
         Apply_Source_Ownership;

         if Preserve_Mode
           and then FS.Permissions_Supported
           and then Available
           and then not FS.Set_Permissions (Target, Mode mod 8#1000#)
         then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end if;

         if Preserve_Mode then
            if not FS.Copy_Modification_Time (Source, Target) then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            end if;
         end if;
      exception
         when others =>
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
      end Apply_Source_Metadata;
   begin
      Ok := True;
      if Preserve_Links and then FS.Is_Link (Source) then
         declare
            Target_Text : Unbounded_String;
         begin
            if FS.Read_Link_Target (Source, Target_Text) then
               if FS.Is_Link (Target) then
                  Ok := FS.Delete_Link (Target);
               elsif FS.Kind (Target) = FS.Ordinary_File
               then
                  FS.Delete_File (Target);
               end if;

               if Ok and then FS.Create_Link (To_String (Target_Text), Target) then
                  return;
               end if;
            end if;

            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Source, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            return;
         exception
            when others =>
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Source, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               return;
         end;
      end if;

      if FS.Kind (Source) = FS.Directory
      then
         if not Recursive then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Source, "posix_tools.diagnostic.file.is_directory", "is a directory");
            return;
         end if;

         begin
            if Is_Same_Or_Descendant (Source, Target) then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.same_file", "source and destination are the same file");
               return;
            end if;

            if not FS.Exists (Target) then
               FS.Create_Directory (Target);
            elsif FS.Kind (Target) /= FS.Directory then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.not_directory", "not a directory");
               return;
            end if;
            Apply_Source_Metadata;

            declare
               Iteration_Ok : Boolean;

               procedure Copy_Child (Name : String; Full_Name : String; Stop : in out Boolean) is
                  Child_Ok : Boolean;
               begin
                  pragma Unreferenced (Stop);
                  Copy_Path
                    (Context,
                     Full_Name,
                     Join_Path (Target, Name),
                     Recursive,
                     Preserve_Mode,
                     Preserve_Links,
                     Child_Ok);
                  Ok := Ok and Child_Ok;
               end Copy_Child;

               procedure For_Each_Child is new FS.For_Each_Directory_Entry (Copy_Child);
            begin
               For_Each_Child (Source, Iteration_Ok);
               if not Iteration_Ok then
                  Ok := False;
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context,
                     Source,
                     "posix_tools.diagnostic.file.read_directory_failed",
                     "cannot read directory");
               end if;
            end;
            return;
         exception
            when others =>
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               return;
         end;
      end if;

      if FS.Kind (Source) = FS.Special_File
      then
         declare
            Info    : constant FS.Special_File_Info := FS.Special_File_Info_Of (Source);
            Created : Boolean := False;
         begin
            if FS.Kind (Target) = FS.Directory then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.not_directory", "not a directory");
               return;
            elsif FS.Exists (Target) then
               if FS.Is_Link (Target) then
                  Ok := FS.Delete_Link (Target);
               else
                  begin
                     FS.Delete_File (Target);
                     Ok := True;
                  exception
                     when others =>
                        Ok := False;
                  end;
               end if;

               if not Ok then
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
                  return;
               end if;
            end if;

            if Info.Available and then Info.Kind = FS.FIFO then
               Created := FS.Create_FIFO (Target, Info.Mode);
            elsif Info.Available and then Info.Kind in FS.Character_Device | FS.Block_Device then
               Created := FS.Create_Device (Target, Info.Kind, Info.Device, Info.Mode);
            elsif Info.Available and then Info.Kind = FS.Socket then
               Created := FS.Create_Socket (Target, Info.Mode);
            end if;

            if Created then
               Apply_Source_Metadata;
            elsif Info.Available
              and then Info.Kind in FS.FIFO | FS.Character_Device | FS.Block_Device | FS.Socket
            then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            else
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Source, "posix_tools.diagnostic.file.unsupported_type", "unsupported file type");
            end if;
         end;
         return;
      end if;

      if FS.Exists (Target) and then FS.Same_File (Source, Target) then
         Ok := False;
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Target, "posix_tools.diagnostic.file.same_file", "source and destination are the same file");
         return;
      end if;

      declare
         Copy_Status : FS.Copy_File_Status;
      begin
         FS.Copy_Regular_File (Source, Target, Copy_Status);
         Ok := Copy_Status = FS.Copy_Ok;
         case Copy_Status is
            when FS.Copy_Ok =>
               Apply_Source_Metadata;

            when FS.Source_Open_Failed | FS.Source_Read_Failed =>
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Source, "posix_tools.diagnostic.file.read_failed", "cannot read file");

            when FS.Target_Open_Failed | FS.Target_Write_Failed =>
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end case;
      end;
   end Copy_Path;

   function Lines_Of (Text : String) return String_Vectors.Vector is
      Lines : String_Vectors.Vector;
      Start : Positive := Text'First;
   begin
      if Text = "" then
         return Lines;
      end if;

      for I in Text'Range loop
         if Text (I) = LF then
            Lines.Append (Text (Start .. I - 1));
            Start := I + 1;
         end if;
      end loop;

      if Start <= Text'Last then
         Lines.Append (Text (Start .. Text'Last));
      end if;

      return Lines;
   end Lines_Of;

   procedure Append_UTF_8 (Output : in out Unbounded_String; Code_Point : Long_Long_Integer) is
   begin
      if Code_Point <= 16#7F# then
         Append (Output, Character'Val (Natural (Code_Point)));
      elsif Code_Point <= 16#7FF# then
         Append (Output, Character'Val (16#C0# + Natural (Code_Point / 64)));
         Append (Output, Character'Val (16#80# + Natural (Code_Point mod 64)));
      elsif Code_Point <= 16#FFFF# then
         Append (Output, Character'Val (16#E0# + Natural (Code_Point / 4_096)));
         Append (Output, Character'Val (16#80# + Natural ((Code_Point / 64) mod 64)));
         Append (Output, Character'Val (16#80# + Natural (Code_Point mod 64)));
      else
         Append (Output, Character'Val (16#F0# + Natural (Code_Point / 262_144)));
         Append (Output, Character'Val (16#80# + Natural ((Code_Point / 4_096) mod 64)));
         Append (Output, Character'Val (16#80# + Natural ((Code_Point / 64) mod 64)));
         Append (Output, Character'Val (16#80# + Natural (Code_Point mod 64)));
      end if;
   end Append_UTF_8;

   function Locale_Family (Locale : String) return String is
      Dot : Natural := 0;
   begin
      for I in Locale'Range loop
         if Locale (I) = '.' or else Locale (I) = '_' or else Locale (I) = '-' then
            Dot := I - 1;
            exit;
         end if;
      end loop;

      if Dot = 0 then
         return Locale;
      elsif Dot < Locale'First then
         return "";
      else
         return Locale (Locale'First .. Dot);
      end if;
   end Locale_Family;

   function Locale_Equivalence_Class (Locale, Element : String) return String is
      Family : constant String := Locale_Family (Locale);
      Output : Unbounded_String;

      function Equivalent (Candidate : String) return Boolean is
      begin
         return I18N.Collation.Available
           and then I18N.Collation.Compare
             (Candidate, Element, Locale, I18N.Collation.Primary) = 0;
      exception
         when Constraint_Error =>
            return False;
      end Equivalent;

      procedure Append_If_Equivalent (Candidate : String) is
      begin
         if Equivalent (Candidate)
           and then Ada.Strings.Fixed.Index (To_String (Output), Candidate) = 0
         then
            Append (Output, Candidate);
         end if;
      end Append_If_Equivalent;
   begin
      Append (Output, Element);
      for Code in Character'Pos ('A') .. Character'Pos ('Z') loop
         Append_If_Equivalent ([1 => Character'Val (Code)]);
      end loop;
      for Code in Character'Pos ('a') .. Character'Pos ('z') loop
         Append_If_Equivalent ([1 => Character'Val (Code)]);
      end loop;
      for Code in 16#00C0# .. 16#017F# loop
         declare
            Candidate : Unbounded_String;
         begin
            Append_UTF_8 (Candidate, Long_Long_Integer (Code));
            Append_If_Equivalent (To_String (Candidate));
         end;
      end loop;

      if Element = "a" then
         if Family = "da" then
            Append_If_Equivalent ("a");
            Append_If_Equivalent (Character'Val (16#C3#) & Character'Val (16#A1#));
            Append_If_Equivalent (Character'Val (16#C3#) & Character'Val (16#A0#));
            Append (Output, Character'Val (16#C3#) & Character'Val (16#A1#)
                    & Character'Val (16#C3#) & Character'Val (16#A0#));
         elsif Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#A1#));
         end if;
      elsif Element = "e" then
         if Family = "da" or else Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#A9#));
         end if;
      elsif Element = "o" then
         if Family = "da" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#B8#));
         elsif Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#B3#));
         end if;
      elsif Element = "A" then
         if Family = "da" or else Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#81#));
         end if;
      elsif Element = "E" then
         if Family = "da" or else Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#89#));
         end if;
      elsif Element = "O" then
         if Family = "da" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#98#));
         elsif Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#93#));
         end if;
      end if;

      if Length (Output) > Element'Length then
         return To_String (Output);
      end if;

      return Element;
   end Locale_Equivalence_Class;

   function Locale_Collating_Symbol (Locale, Element : String) return String is
      Family : constant String := Locale_Family (Locale);
   begin
      if Family = "es" and then Element = "ch" then
         return "ch";
      elsif Family = "es" and then Element = "ll" then
         return "ll";
      elsif Family = "da" and then Element = "aa" then
         return "aa";
      else
         return Element;
      end if;
   end Locale_Collating_Symbol;

   function Locale_Collation_Order (Locale, Set1 : String) return String is
      Family : constant String := Locale_Family (Locale);
      Output : Unbounded_String;
      Ordered : String (1 .. 256);
      Last    : Natural := 0;
      Spanish_After_Enye : constant String := "opqrstuvwxyzABCDEFGHIJKLMN";

      procedure Append_If_Available (Ch : Character) is
      begin
         if (for all Item of Set1 => Item /= Ch)
           and then (for all I in 1 .. Last => Ordered (I) /= Ch)
         then
            Last := Last + 1;
            Ordered (Last) := Ch;
         end if;
      end Append_If_Available;

      function Key (Ch : Character) return String is
      begin
         if I18N.Collation.Available
           and then Family /= ""
           and then Family /= "C"
           and then Family /= "POSIX"
           and then Family /= "en"
         then
            return I18N.Collation.Sort_Key ([1 => Ch], Locale, I18N.Collation.Primary);
         else
            return [1 => Ch];
         end if;
      exception
         when Constraint_Error =>
            return [1 => Ch];
      end Key;
   begin
      if Family = "da" then
         for Ch in Character range 'a' .. 'z' loop
            Append_If_Available (Ch);
         end loop;
         Append_If_Available (Character'Val (16#C3#));
         Append_If_Available (Character'Val (16#A6#));
         Append_If_Available (Character'Val (16#B8#));
         Append_If_Available (Character'Val (16#A5#));
         for Ch in Character range 'A' .. 'Z' loop
            Append_If_Available (Ch);
         end loop;
      elsif Family = "es" then
         for Ch in Character range 'a' .. 'n' loop
            Append_If_Available (Ch);
         end loop;
         Append_If_Available (Character'Val (16#C3#));
         Append_If_Available (Character'Val (16#B1#));
         for Ch of Spanish_After_Enye loop
            Append_If_Available (Ch);
         end loop;
         Append_If_Available (Character'Val (16#91#));
         for Ch in Character range 'O' .. 'Z' loop
            Append_If_Available (Ch);
         end loop;
      end if;

      for Code in 0 .. 255 loop
         Append_If_Available (Character'Val (Code));
      end loop;

      if Family /= "da" and then Family /= "es" then
         for I in 2 .. Last loop
            declare
               Item : constant Character := Ordered (I);
               J    : Natural := I;
            begin
               while J > 1
                 and then (Key (Item) < Key (Ordered (J - 1))
                           or else (Key (Item) = Key (Ordered (J - 1)) and then Item < Ordered (J - 1)))
               loop
                  Ordered (J) := Ordered (J - 1);
                  J := J - 1;
               end loop;
               Ordered (J) := Item;
            end;
         end loop;
      end if;

      for I in 1 .. Last loop
         Append (Output, Ordered (I));
      end loop;

      return To_String (Output);
   end Locale_Collation_Order;

   function Expanded_Translation_Set (Text, Locale : String) return String is
      Output : Unbounded_String;
      I : Positive := Text'First;

      procedure Append_Range (Low, High : Character) is
      begin
         for Code in Character'Pos (Low) .. Character'Pos (High) loop
            Append (Output, Character'Val (Code));
         end loop;
      end Append_Range;

      function Octal_Value (Ch : Character) return Natural is
      begin
         return Character'Pos (Ch) - Character'Pos ('0');
      end Octal_Value;

      function Decode_Escape (Index : in out Positive) return Character is
         Value : Natural := 0;
         Count : Natural := 0;
      begin
         if Index = Text'Last then
            return Text (Index);
         end if;

         Index := Index + 1;
         case Text (Index) is
            when '\' =>
               return '\';
            when 'a' =>
               return Character'Val (7);
            when 'b' =>
               return Character'Val (8);
            when 'f' =>
               return Character'Val (12);
            when 'n' =>
               return Character'Val (10);
            when 'r' =>
               return Character'Val (13);
            when 't' =>
               return Character'Val (9);
            when 'v' =>
               return Character'Val (11);
            when '0' .. '7' =>
               while Index <= Text'Last and then Text (Index) in '0' .. '7' and then Count < 3 loop
                  Value := Value * 8 + Octal_Value (Text (Index));
                  Count := Count + 1;
                  Index := Index + 1;
               end loop;
               Index := Index - 1;
               return Character'Val (Natural'Min (Value, 255));
            when others =>
               return Text (Index);
         end case;
      end Decode_Escape;

      function Decode_Set_Element (Index : in out Positive) return Character is
      begin
         if Text (Index) = '\' then
            return Decode_Escape (Index);
         else
            return Text (Index);
         end if;
      end Decode_Set_Element;

      function Repetition_Count
        (First : Positive;
         Last  : Natural;
         Count : out Natural) return Boolean
      is
         Base : constant Natural := (if First < Last and then Text (First) = '0' then 8 else 10);
      begin
         Count := 0;
         if First > Last then
            return False;
         end if;

         for J in First .. Last loop
            if Text (J) not in '0' .. '9'
              or else (Base = 8 and then Text (J) not in '0' .. '7')
            then
               return False;
            elsif Count > (Natural'Last - (Character'Pos (Text (J)) - Character'Pos ('0'))) / Base then
               return False;
            end if;
            Count := Count * Base + Character'Pos (Text (J)) - Character'Pos ('0');
         end loop;

         return True;
      end Repetition_Count;

      function Bracket_Sequence
        (Marker : Character;
         Value  : out Unbounded_String;
         Last   : out Natural) return Boolean
      is
         Element_Index : Positive := I + 2;
      begin
         Value := Null_Unbounded_String;
         Last := 0;
         if I + 4 > Text'Last
           or else Text (I) /= '['
           or else Text (I + 1) /= Marker
         then
            return False;
         end if;

         while Element_Index + 1 <= Text'Last loop
            if Text (Element_Index) = Marker and then Text (Element_Index + 1) = ']' then
               Last := Element_Index + 1;
               return Length (Value) > 0;
            else
               Append (Value, Decode_Set_Element (Element_Index));
               Element_Index := Element_Index + 1;
            end if;
         end loop;

         return False;
      end Bracket_Sequence;
   begin
      while I <= Text'Last loop
         if I + 8 <= Text'Last and then Text (I .. I + 8) = "[:lower:]" then
            Append_Range ('a', 'z');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:upper:]" then
            Append_Range ('A', 'Z');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:digit:]" then
            Append_Range ('0', '9');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:alnum:]" then
            Append_Range ('0', '9');
            Append_Range ('A', 'Z');
            Append_Range ('a', 'z');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:alpha:]" then
            Append_Range ('A', 'Z');
            Append_Range ('a', 'z');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:space:]" then
            Append (Output, Character'Val (9));
            Append (Output, Character'Val (10));
            Append (Output, Character'Val (11));
            Append (Output, Character'Val (12));
            Append (Output, Character'Val (13));
            Append (Output, ' ');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:blank:]" then
            Append (Output, Character'Val (9));
            Append (Output, ' ');
            I := I + 9;
         elsif I + 9 <= Text'Last and then Text (I .. I + 9) = "[:xdigit:]" then
            Append_Range ('0', '9');
            Append_Range ('A', 'F');
            Append_Range ('a', 'f');
            I := I + 10;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:punct:]" then
            Append_Range ('!', '/');
            Append_Range (':', '@');
            Append_Range ('[', '`');
            Append_Range ('{', '~');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:graph:]" then
            Append_Range ('!', '~');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:print:]" then
            Append_Range (' ', '~');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:cntrl:]" then
            Append_Range (Character'Val (0), Character'Val (31));
            Append (Output, Character'Val (127));
            I := I + 9;
         elsif Text (I) = '[' and then I + 3 <= Text'Last then
            declare
               Sequence   : Unbounded_String;
               Last_Index : Natural;
               Element_Index : Positive := I + 1;
               Repeated      : Character;
               Star_Index    : Natural;
               Close_Index   : Natural := 0;
               Count         : Natural := 0;
               Handled       : Boolean := False;
            begin
               if Bracket_Sequence ('=', Sequence, Last_Index)
               then
                  Append (Output, Locale_Equivalence_Class (Locale, To_String (Sequence)));
                  I := Last_Index + 1;
                  Handled := True;
               elsif Bracket_Sequence ('.', Sequence, Last_Index) then
                  Append (Output, Locale_Collating_Symbol (Locale, To_String (Sequence)));
                  I := Last_Index + 1;
                  Handled := True;
               else
                  Repeated := Decode_Set_Element (Element_Index);
                  Star_Index := Element_Index + 1;
               end if;

               if not Handled
                 and then Close_Index = 0
                 and then Star_Index <= Text'Last
                 and then Text (Star_Index) = '*'
               then
                  for J in Star_Index + 1 .. Text'Last loop
                     if Text (J) = ']' then
                        Close_Index := J;
                        exit;
                     end if;
                  end loop;
               end if;

               if not Handled
                 and then Close_Index > Star_Index + 1
                 and then Repetition_Count (Star_Index + 1, Close_Index - 1, Count)
               then
                  for J in 1 .. Count loop
                     Append (Output, Repeated);
                  end loop;
                  I := Close_Index + 1;
               elsif not Handled
                 and then Close_Index = Star_Index + 1
               then
                  for J in 1 .. 256 loop
                     Append (Output, Repeated);
                  end loop;
                  I := Close_Index + 1;
               else
                  if not Handled then
                     Append (Output, Text (I));
                     I := I + 1;
                  end if;
               end if;
            end;
         else
            declare
               Element_Index : Positive := I;
               Low           : constant Character := Decode_Set_Element (Element_Index);
               Next_Index    : constant Natural := Element_Index + 1;
            begin
               if Next_Index <= Text'Last - 1 and then Text (Next_Index) = '-' then
                  declare
                     High_Index : Positive := Next_Index + 1;
                     High       : constant Character := Decode_Set_Element (High_Index);
                  begin
                     if Character'Pos (Low) <= Character'Pos (High) then
                        Append_Range (Low, High);
                     else
                        Append (Output, Low);
                        Append (Output, '-');
                        Append (Output, High);
                     end if;
                     I := High_Index + 1;
                  end;
               else
                  Append (Output, Low);
                  I := Next_Index;
               end if;
            end;
         end if;
      end loop;

      return To_String (Output);
   end Expanded_Translation_Set;

   function Folded_Sort_Text (Text : String) return String is
      Output : Unbounded_String;
      I      : Positive := Text'First;

      function Decode_At
        (Index      : Positive;
         Code_Point : out Long_Long_Integer;
         Width      : out Natural) return Boolean
      is
         B1 : constant Natural := Character'Pos (Text (Index));
      begin
         Code_Point := 0;
         Width := 1;

         if B1 <= 16#7F# then
            Code_Point := Long_Long_Integer (B1);
            return True;
         elsif B1 in 16#C2# .. 16#DF# and then Index + 1 <= Text'Last then
            declare
               B2 : constant Natural := Character'Pos (Text (Index + 1));
            begin
               if B2 not in 16#80# .. 16#BF# then
                  return False;
               end if;
               Code_Point := Long_Long_Integer ((B1 mod 32) * 64 + (B2 mod 64));
               Width := 2;
               return True;
            end;
         elsif B1 in 16#E0# .. 16#EF# and then Index + 2 <= Text'Last then
            declare
               B2 : constant Natural := Character'Pos (Text (Index + 1));
               B3 : constant Natural := Character'Pos (Text (Index + 2));
               Value : constant Natural := (B1 mod 16) * 4_096 + (B2 mod 64) * 64 + (B3 mod 64);
            begin
               if B2 not in 16#80# .. 16#BF#
                 or else B3 not in 16#80# .. 16#BF#
                 or else Value < 16#800#
                 or else Value in 16#D800# .. 16#DFFF#
               then
                  return False;
               end if;
               Code_Point := Long_Long_Integer (Value);
               Width := 3;
               return True;
            end;
         elsif B1 in 16#F0# .. 16#F4# and then Index + 3 <= Text'Last then
            declare
               B2 : constant Natural := Character'Pos (Text (Index + 1));
               B3 : constant Natural := Character'Pos (Text (Index + 2));
               B4 : constant Natural := Character'Pos (Text (Index + 3));
               Value : constant Natural :=
                 (B1 mod 8) * 262_144 + (B2 mod 64) * 4_096 + (B3 mod 64) * 64 + (B4 mod 64);
            begin
               if B2 not in 16#80# .. 16#BF#
                 or else B3 not in 16#80# .. 16#BF#
                 or else B4 not in 16#80# .. 16#BF#
                 or else Value < 16#10000#
                 or else Value > 16#10FFFF#
               then
                  return False;
               end if;
               Code_Point := Long_Long_Integer (Value);
               Width := 4;
               return True;
            end;
         else
            return False;
         end if;
      end Decode_At;

      procedure Append_Folded_Code_Point (Code_Point : Long_Long_Integer) is
      begin
         if Code_Point in Character'Pos ('A') .. Character'Pos ('Z') then
            Append_UTF_8 (Output, Code_Point + 32);
         elsif Code_Point in 16#00C0# .. 16#00D6# or else Code_Point in 16#00D8# .. 16#00DE# then
            Append_UTF_8 (Output, Code_Point + 32);
         elsif Code_Point = 16#00DF# or else Code_Point = 16#1E9E# then
            Append (Output, "ss");
         elsif Code_Point in 16#0100# .. 16#0136# and then Code_Point mod 2 = 0 then
            Append_UTF_8 (Output, Code_Point + 1);
         elsif Code_Point in 16#0139# .. 16#0147# and then Code_Point mod 2 = 1 then
            Append_UTF_8 (Output, Code_Point + 1);
         elsif Code_Point = 16#0130# then
            Append (Output, "i");
            Append_UTF_8 (Output, 16#0307#);
         elsif Code_Point = 16#014A# then
            Append_UTF_8 (Output, 16#014B#);
         elsif Code_Point in 16#014C# .. 16#0176# and then Code_Point mod 2 = 0 then
            Append_UTF_8 (Output, Code_Point + 1);
         elsif Code_Point = 16#0178# then
            Append_UTF_8 (Output, 16#00FF#);
         elsif Code_Point in 16#0179# .. 16#017D# and then Code_Point mod 2 = 1 then
            Append_UTF_8 (Output, Code_Point + 1);
         elsif Code_Point = 16#017F# then
            Append (Output, "s");
         elsif Code_Point = 16#0181# then
            Append_UTF_8 (Output, 16#0253#);
         elsif Code_Point in 16#0182# .. 16#0184# and then Code_Point mod 2 = 0 then
            Append_UTF_8 (Output, Code_Point + 1);
         elsif Code_Point = 16#0186# then
            Append_UTF_8 (Output, 16#0254#);
         elsif Code_Point = 16#0187# then
            Append_UTF_8 (Output, 16#0188#);
         elsif Code_Point = 16#0189# then
            Append_UTF_8 (Output, 16#0256#);
         elsif Code_Point = 16#018A# then
            Append_UTF_8 (Output, 16#0257#);
         elsif Code_Point = 16#018B# then
            Append_UTF_8 (Output, 16#018C#);
         elsif Code_Point = 16#018E# then
            Append_UTF_8 (Output, 16#01DD#);
         elsif Code_Point = 16#018F# then
            Append_UTF_8 (Output, 16#0259#);
         elsif Code_Point = 16#0190# then
            Append_UTF_8 (Output, 16#025B#);
         elsif Code_Point = 16#0191# then
            Append_UTF_8 (Output, 16#0192#);
         elsif Code_Point = 16#0193# then
            Append_UTF_8 (Output, 16#0260#);
         elsif Code_Point = 16#0194# then
            Append_UTF_8 (Output, 16#0263#);
         elsif Code_Point = 16#0196# then
            Append_UTF_8 (Output, 16#0269#);
         elsif Code_Point = 16#0197# then
            Append_UTF_8 (Output, 16#0268#);
         elsif Code_Point = 16#0198# then
            Append_UTF_8 (Output, 16#0199#);
         elsif Code_Point = 16#019C# then
            Append_UTF_8 (Output, 16#026F#);
         elsif Code_Point = 16#019D# then
            Append_UTF_8 (Output, 16#0272#);
         elsif Code_Point = 16#019F# then
            Append_UTF_8 (Output, 16#0275#);
         elsif Code_Point = 16#0386# then
            Append_UTF_8 (Output, 16#03AC#);
         elsif Code_Point in 16#0388# .. 16#038A# then
            Append_UTF_8 (Output, Code_Point + 37);
         elsif Code_Point = 16#038C# then
            Append_UTF_8 (Output, 16#03CC#);
         elsif Code_Point in 16#038E# .. 16#038F# then
            Append_UTF_8 (Output, Code_Point + 63);
         elsif Code_Point in 16#0391# .. 16#03A1# or else Code_Point in 16#03A3# .. 16#03AB# then
            Append_UTF_8 (Output, Code_Point + 32);
         elsif Code_Point = 16#03C2# then
            Append_UTF_8 (Output, 16#03C3#);
         elsif Code_Point in 16#0400# .. 16#040F# then
            Append_UTF_8 (Output, Code_Point + 80);
         elsif Code_Point in 16#0410# .. 16#042F# then
            Append_UTF_8 (Output, Code_Point + 32);
         elsif Code_Point in 16#0531# .. 16#0556# then
            Append_UTF_8 (Output, Code_Point + 48);
         elsif Code_Point in 16#13A0# .. 16#13EF# then
            Append_UTF_8 (Output, Code_Point + 16#97D0#);
         elsif Code_Point in 16#13F0# .. 16#13F5# then
            Append_UTF_8 (Output, Code_Point + 8);
         elsif Code_Point in 16#10400# .. 16#10427# then
            Append_UTF_8 (Output, Code_Point + 40);
         elsif Code_Point in 16#1C90# .. 16#1CBF# then
            Append_UTF_8 (Output, Code_Point - 16#0BC0#);
         elsif Code_Point = 16#212A# then
            Append (Output, "k");
         elsif Code_Point = 16#212B# then
            Append_UTF_8 (Output, 16#00E5#);
         elsif Code_Point = 16#FB00# then
            Append (Output, "ff");
         elsif Code_Point = 16#FB01# then
            Append (Output, "fi");
         elsif Code_Point = 16#FB02# then
            Append (Output, "fl");
         elsif Code_Point = 16#FB03# then
            Append (Output, "ffi");
         elsif Code_Point = 16#FB04# then
            Append (Output, "ffl");
         elsif Code_Point = 16#FB05# or else Code_Point = 16#FB06# then
            Append (Output, "st");
         elsif Code_Point in 16#FF21# .. 16#FF3A# then
            Append_UTF_8 (Output, Code_Point + 32);
         else
            Append_UTF_8 (Output, Code_Point);
         end if;
      end Append_Folded_Code_Point;
   begin
      while I <= Text'Last loop
         declare
            Code_Point : Long_Long_Integer;
            Width      : Natural;
         begin
            if Decode_At (I, Code_Point, Width) then
               Append_Folded_Code_Point (Code_Point);
               I := I + Width;
            else
               Append (Output, Text (I));
               I := I + 1;
            end if;
         end;
      end loop;

      return To_String (Output);
   end Folded_Sort_Text;

   function Locale_Sort_Text (Locale, Text : String) return String is
      Family : constant String := Locale_Family (Locale);
      Output : Unbounded_String;
      I      : Positive := Text'First;

      function Has_Bytes (Pattern : String) return Boolean is
      begin
         return I + Pattern'Length - 1 <= Text'Last
           and then Text (I .. I + Pattern'Length - 1) = Pattern;
      end Has_Bytes;

      procedure Append_Byte_Order (Ch : Character) is
      begin
         Append (Output, Ch);
         Append (Output, Character'Val (0));
      end Append_Byte_Order;

      procedure Append_Collation (Primary, Secondary : Character) is
      begin
         Append (Output, Primary);
         Append (Output, Secondary);
      end Append_Collation;
   begin
      if Family /= ""
        and then Family /= "c"
        and then Family /= "posix"
        and then Family /= "da"
        and then Family /= "es"
        and then I18N.Collation.Available
      then
         declare
            CLDR_Key : constant String := I18N.Collation.Sort_Key (Text, Locale, I18N.Collation.Tertiary);
         begin
            if CLDR_Key /= Text then
               return CLDR_Key;
            end if;
         end;
      end if;

      if Family /= "da" and then Family /= "es" then
         return Text;
      end if;

      while I <= Text'Last loop
         if Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (166)) then
            Append_Collation ('{', 'a');
            I := I + 2;
         elsif Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (134)) then
            Append_Collation ('{', 'A');
            I := I + 2;
         elsif Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (184)) then
            Append_Collation ('{', 'b');
            I := I + 2;
         elsif Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (152)) then
            Append_Collation ('{', 'B');
            I := I + 2;
         elsif Family = "da"
           and then (Has_Bytes (Character'Val (195) & Character'Val (165))
                     or else Has_Bytes (Character'Val (226) & Character'Val (132) & Character'Val (171)))
         then
            Append_Collation ('{', 'c');
            I := I + (if Character'Pos (Text (I)) = 195 then 2 else 3);
         elsif Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (133)) then
            Append_Collation ('{', 'C');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes ("ch") then
            Append_Collation ('c', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes ("Ch") then
            Append_Collation ('C', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes ("ll") then
            Append_Collation ('l', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes ("Ll") then
            Append_Collation ('L', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (177)) then
            Append_Collation ('n', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (145)) then
            Append_Collation ('N', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (161)) then
            Append_Collation ('a', 'a');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (169)) then
            Append_Collation ('e', 'a');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (173)) then
            Append_Collation ('i', 'a');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (179)) then
            Append_Collation ('o', 'a');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (186)) then
            Append_Collation ('u', 'a');
            I := I + 2;
         else
            Append_Byte_Order (Text (I));
            I := I + 1;
         end if;
      end loop;

      return To_String (Output);
   end Locale_Sort_Text;

   function Starts_With_At
     (Text    : String;
      Pattern : String;
      Index   : Positive) return Boolean
   is
   begin
      return Pattern /= ""
        and then Index <= Text'Last
        and then Index + Pattern'Length - 1 <= Text'Last
        and then Text (Index .. Index + Pattern'Length - 1) = Pattern;
   end Starts_With_At;

   function Locale_Digit_At
     (Locale : String;
      Text   : String;
      Index  : Positive;
      Digit  : out Character;
      Width  : out Natural) return Boolean
   is
   begin
      if Index <= Text'Last and then Text (Index) in '0' .. '9' then
         Digit := Text (Index);
         Width := 1;
         return True;
      end if;

      for Ch in Character range '0' .. '9' loop
         declare
            Localized : constant String := I18N.CLDR_Data.Digit_Text (Locale, Ch);
         begin
            if Localized /= String'(1 => Ch) and then Starts_With_At (Text, Localized, Index) then
               Digit := Ch;
               Width := Localized'Length;
               return True;
            end if;
         end;
      end loop;

      Digit := '0';
      Width := 0;
      return False;
   end Locale_Digit_At;

   function Numeric_Field (Locale, Text : String) return String is
      Index     : Positive := Text'First;
      Output    : Unbounded_String;
      Decimal_Separator : constant String := I18N.CLDR_Data.Decimal_Separator (Locale);
      Plus_Sign : constant String := I18N.CLDR_Data.Number_Plus_Sign (Locale);
      Minus_Sign : constant String := I18N.CLDR_Data.Number_Minus_Sign (Locale);
      Has_Digit : Boolean := False;
      Digit     : Character;
      Width     : Natural;

      function At_Decimal_Separator return Boolean is
      begin
         return (Index <= Text'Last and then Text (Index) = '.')
           or else
             (Decimal_Separator /= "."
              and then Starts_With_At (Text, Decimal_Separator, Index));
      end At_Decimal_Separator;

      procedure Consume_Sign is
      begin
         if Index <= Text'Last and then Text (Index) in '-' | '+' then
            Append (Output, Text (Index));
            Index := Index + 1;
         elsif Minus_Sign /= "-" and then Starts_With_At (Text, Minus_Sign, Index) then
            Append (Output, "-");
            Index := Index + Minus_Sign'Length;
         elsif Plus_Sign /= "+" and then Starts_With_At (Text, Plus_Sign, Index) then
            Append (Output, "+");
            Index := Index + Plus_Sign'Length;
         end if;
      end Consume_Sign;

      procedure Consume_Digits is
      begin
         while Index <= Text'Last and then Locale_Digit_At (Locale, Text, Index, Digit, Width) loop
            Append (Output, Digit);
            Has_Digit := True;
            Index := Index + Width;
         end loop;
      end Consume_Digits;
   begin
      while Index <= Text'Last and then (Text (Index) = ' ' or else Text (Index) = Character'Val (9)) loop
         Index := Index + 1;
      end loop;

      Consume_Sign;
      Consume_Digits;

      if At_Decimal_Separator then
         Append (Output, ".");
         Index := Index + (if Index <= Text'Last and then Text (Index) = '.' then 1 else Decimal_Separator'Length);
         Consume_Digits;
      end if;

      if not Has_Digit then
         return "0";
      end if;

      if Index <= Text'Last and then Text (Index) in 'e' | 'E' then
         declare
            Exponent_Start : constant Positive := Index;
            Exponent_Output_Length : constant Natural := Length (Output);
            Exponent_Has_Digit : Boolean := False;
         begin
            Append (Output, Text (Index));
            Index := Index + 1;
            Consume_Sign;
            while Index <= Text'Last and then Locale_Digit_At (Locale, Text, Index, Digit, Width) loop
               Append (Output, Digit);
               Exponent_Has_Digit := True;
               Index := Index + Width;
            end loop;

            if not Exponent_Has_Digit then
               declare
                  Previous : constant String := To_String (Output);
               begin
                  Output :=
                    To_Unbounded_String
                      (Previous (Previous'First .. Previous'First + Exponent_Output_Length - 1));
                  Index := Exponent_Start;
               end;
            end if;
         end;
      end if;

      return To_String (Output);
   end Numeric_Field;

   function Decimal_Compare (Left, Right : String) return Integer is
      function Normalized_Decimal (Value : String) return String is
         Sign_First : constant Positive := Value'First;
         Digit_First : Positive := Value'First;
         Dot : Natural := 0;
         Exponent_Marker : Natural := 0;
         Exponent_Negative : Boolean := False;
         Exponent : Integer := 0;
         Numeric_Digits : Unbounded_String;
      begin
         if Value (Digit_First) in '-' | '+' then
            Digit_First := Digit_First + 1;
         end if;

         for I in Digit_First .. Value'Last loop
            if Value (I) = '.' then
               Dot := I;
            elsif Value (I) in 'e' | 'E' then
               Exponent_Marker := I;
               exit;
            end if;
         end loop;

         if Exponent_Marker = 0 then
            return Value;
         end if;

         if Exponent_Marker < Value'Last then
            declare
               I : Positive := Exponent_Marker + 1;
            begin
               if Value (I) in '-' | '+' then
                  Exponent_Negative := Value (I) = '-';
                  I := I + 1;
               end if;

               while I <= Value'Last and then Value (I) in '0' .. '9' loop
                  if Exponent <= 1_000_000 then
                     Exponent := Exponent * 10 + Character'Pos (Value (I)) - Character'Pos ('0');
                  end if;
                  I := I + 1;
               end loop;
            end;
         end if;

         if Exponent_Negative then
            Exponent := -Exponent;
         end if;

         for I in Digit_First .. Exponent_Marker - 1 loop
            if Value (I) in '0' .. '9' then
               Append (Numeric_Digits, Value (I));
            end if;
         end loop;

         declare
            Raw_Digits : constant String := To_String (Numeric_Digits);
            Integer_Digits : constant Integer :=
              (if Dot = 0
               then Exponent_Marker - Digit_First
               else Dot - Digit_First);
            Decimal_Position : constant Integer := Integer_Digits + Exponent;
            Output : Unbounded_String;
         begin
            if Value (Sign_First) = '-' then
               Append (Output, "-");
            elsif Value (Sign_First) = '+' then
               Append (Output, "+");
            end if;

            if Decimal_Position <= 0 then
               Append (Output, "0.");
               for I in 1 .. Natural (-Decimal_Position) loop
                  Append (Output, "0");
               end loop;
               Append (Output, Raw_Digits);
            elsif Decimal_Position >= Raw_Digits'Length then
               Append (Output, Raw_Digits);
               for I in 1 .. Natural (Decimal_Position - Raw_Digits'Length) loop
                  Append (Output, "0");
               end loop;
            else
               Append (Output, Raw_Digits (Raw_Digits'First .. Raw_Digits'First + Decimal_Position - 1));
               Append (Output, ".");
               Append (Output, Raw_Digits (Raw_Digits'First + Decimal_Position .. Raw_Digits'Last));
            end if;

            return To_String (Output);
         end;
      end Normalized_Decimal;

      Normal_Left : constant String := Normalized_Decimal (Left);
      Normal_Right : constant String := Normalized_Decimal (Right);
      Left_Negative  : constant Boolean := Normal_Left (Normal_Left'First) = '-';
      Right_Negative : constant Boolean := Normal_Right (Normal_Right'First) = '-';

      function Start_Of_Number (Value : String) return Positive is
      begin
         if Value (Value'First) in '-' | '+' then
            return Value'First + 1;
         else
            return Value'First;
         end if;
      end Start_Of_Number;

      function Dot_Or_After (Value : String) return Natural is
      begin
         for I in Start_Of_Number (Value) .. Value'Last loop
            if Value (I) = '.' then
               return I;
            end if;
         end loop;
         return Value'Last + 1;
      end Dot_Or_After;

      function Trimmed_Integer (Value : String) return String is
         First : Natural := Start_Of_Number (Value);
         Dot   : constant Natural := Dot_Or_After (Value);
      begin
         while First < Dot - 1 and then Value (First) = '0' loop
            First := First + 1;
         end loop;
         if First >= Dot then
            return "0";
         end if;
         return Value (First .. Dot - 1);
      end Trimmed_Integer;

      function Trimmed_Fraction (Value : String) return String is
         Dot  : constant Natural := Dot_Or_After (Value);
         Last : Natural := Value'Last;
      begin
         if Dot > Value'Last then
            return "";
         end if;
         while Last > Dot and then Value (Last) = '0' loop
            Last := Last - 1;
         end loop;
         if Last = Dot then
            return "";
         end if;
         return Value (Dot + 1 .. Last);
      end Trimmed_Fraction;

      Left_Integer  : constant String := Trimmed_Integer (Normal_Left);
      Right_Integer : constant String := Trimmed_Integer (Normal_Right);
      Left_Fraction : constant String := Trimmed_Fraction (Normal_Left);
      Right_Fraction : constant String := Trimmed_Fraction (Normal_Right);
      Magnitude : Integer := 0;
   begin
      if Left_Negative /= Right_Negative then
         return (if Left_Negative then -1 else 1);
      elsif Left_Integer'Length /= Right_Integer'Length then
         Magnitude := (if Left_Integer'Length > Right_Integer'Length then 1 else -1);
      elsif Left_Integer /= Right_Integer then
         Magnitude := (if Left_Integer > Right_Integer then 1 else -1);
      else
         declare
            Max : constant Natural := Natural'Max (Left_Fraction'Length, Right_Fraction'Length);
            Left_Char  : Character;
            Right_Char : Character;
         begin
            if Max > 0 then
               for Offset in 0 .. Max - 1 loop
                  Left_Char :=
                    (if Offset < Left_Fraction'Length then Left_Fraction (Left_Fraction'First + Offset) else '0');
                  Right_Char :=
                    (if Offset < Right_Fraction'Length then Right_Fraction (Right_Fraction'First + Offset) else '0');
                  if Left_Char /= Right_Char then
                     Magnitude := (if Left_Char > Right_Char then 1 else -1);
                     exit;
                  end if;
               end loop;
            end if;
         end;
      end if;

      return (if Left_Negative then -Magnitude else Magnitude);
   end Decimal_Compare;

   function Sort_Key
     (Text : String;
      Fold_Case, Ignore_Leading_Blanks, Dictionary_Order, Ignore_Nonprinting : Boolean;
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Field_Separator : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Locale : String := "";
      Apply_Locale_Collation : Boolean := True) return String
   is
      First : Natural := Text'First;
      Last  : Natural := Text'Last;

      function Dictionary_Character (Ch : Character) return Boolean is
      begin
         return Ch in 'A' .. 'Z'
           or else Ch in 'a' .. 'z'
           or else Ch in '0' .. '9'
           or else Ch = ' '
           or else Ch = Character'Val (9);
      end Dictionary_Character;

      function Printable_Character (Ch : Character) return Boolean is
      begin
         return Ch in ' ' .. '~';
      end Printable_Character;

      function Apply_Start_Character (Index : Natural) return Natural is
      begin
         if Character_Start = 1 then
            return Index;
         elsif Index > Text'Last then
            return Text'Last + 1;
         else
            return Natural'Min (Text'Last + 1, Index + Character_Start - 1);
         end if;
      end Apply_Start_Character;

      function Field_Start_Index return Natural is
         Field : Positive := 1;
         I     : Natural := Text'First;
      begin
         if Field_Start = 1 then
            if Has_Field_Separator then
               return Apply_Start_Character (Text'First);
            end if;
         elsif Has_Field_Separator then
            while I <= Text'Last loop
               if Text (I) = Field_Separator then
                  Field := Field + 1;
                  if Field = Field_Start then
                     return Apply_Start_Character (I + 1);
                  end if;
               end if;
               I := I + 1;
            end loop;
            return Text'Last + 1;
         end if;

         while I <= Text'Last and then (Text (I) = ' ' or else Text (I) = Character'Val (9)) loop
            I := I + 1;
         end loop;

         while Field < Field_Start and then I <= Text'Last loop
            while I <= Text'Last and then Text (I) /= ' ' and then Text (I) /= Character'Val (9) loop
               I := I + 1;
            end loop;
            while I <= Text'Last and then (Text (I) = ' ' or else Text (I) = Character'Val (9)) loop
               I := I + 1;
            end loop;
            Field := Field + 1;
         end loop;
         return Apply_Start_Character (I);
      end Field_Start_Index;

      function Field_End_Index return Natural is
         Field : Positive := 1;
         I     : Natural := Text'First;
         Base  : Natural := Text'First;
      begin
         if Field_End = 0 then
            return Text'Last;
         elsif Has_Field_Separator then
            while I <= Text'Last loop
               if Field = Field_End and then Text (I) = Field_Separator then
                  return
                    (if Character_End = 0
                     then I - 1
                     else Natural'Min (I - 1, Base + Character_End - 1));
               elsif Text (I) = Field_Separator then
                  Field := Field + 1;
                  Base := I + 1;
               end if;
               I := I + 1;
            end loop;
            return
              (if Character_End = 0
               then Text'Last
               else Natural'Min (Text'Last, Base + Character_End - 1));
         end if;

         while I <= Text'Last and then (Text (I) = ' ' or else Text (I) = Character'Val (9)) loop
            I := I + 1;
         end loop;

         while Field < Positive'Max (1, Field_End) and then I <= Text'Last loop
            while I <= Text'Last and then Text (I) /= ' ' and then Text (I) /= Character'Val (9) loop
               I := I + 1;
            end loop;
            while I <= Text'Last and then (Text (I) = ' ' or else Text (I) = Character'Val (9)) loop
               I := I + 1;
            end loop;
            Field := Field + 1;
         end loop;

         Base := I;
         while I <= Text'Last and then Text (I) /= ' ' and then Text (I) /= Character'Val (9) loop
            I := I + 1;
         end loop;
         return
           (if Character_End = 0
            then I - 1
            else Natural'Min (I - 1, Base + Character_End - 1));
      end Field_End_Index;
   begin
      First := Field_Start_Index;
      Last := Field_End_Index;
      if Ignore_Leading_Blanks then
         while First <= Last and then (Text (First) = ' ' or else Text (First) = Character'Val (9)) loop
            First := First + 1;
         end loop;
      end if;

      if First > Text'Last or else First > Last then
         return "";
      elsif not Fold_Case and then not Dictionary_Order and then not Ignore_Nonprinting then
         declare
            Raw_Key : constant String := Text (First .. Last);
         begin
            return (if Apply_Locale_Collation then Locale_Sort_Text (Locale, Raw_Key) else Raw_Key);
         end;
      elsif Fold_Case and then not Dictionary_Order and then not Ignore_Nonprinting then
         declare
            Raw_Key : constant String := Folded_Sort_Text (Text (First .. Last));
         begin
            return (if Apply_Locale_Collation then Locale_Sort_Text (Locale, Raw_Key) else Raw_Key);
         end;
      else
         declare
            Key  : Unbounded_String;
         begin
            for I in First .. Last loop
               if (not Dictionary_Order or else Dictionary_Character (Text (I)))
                 and then (not Ignore_Nonprinting or else Printable_Character (Text (I)))
               then
                  Append (Key, Text (I));
               end if;
            end loop;
            declare
               Raw_Key : constant String :=
                 (if Fold_Case then Folded_Sort_Text (To_String (Key)) else To_String (Key));
            begin
               return (if Apply_Locale_Collation then Locale_Sort_Text (Locale, Raw_Key) else Raw_Key);
            end;
         end;
      end if;
   end Sort_Key;

   function Line_Greater
     (Left, Right : String;
      Fold_Case,
      Numeric_Sort,
      Ignore_Leading_Blanks,
      Stable_Sort,
      Dictionary_Order,
      Ignore_Nonprinting : Boolean;
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Field_Separator : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Locale : String := "")
      return Boolean
   is
      Left_Char : Character;
      Right_Char : Character;
      Left_Key : constant String :=
        Sort_Key
          (Left,
           Fold_Case,
           Ignore_Leading_Blanks,
           Dictionary_Order,
           Ignore_Nonprinting,
           Field_Start,
           Field_End,
           Character_Start,
           Character_End,
           Field_Separator,
           Has_Field_Separator,
           Locale);
      Right_Key : constant String :=
        Sort_Key
          (Right,
           Fold_Case,
           Ignore_Leading_Blanks,
           Dictionary_Order,
           Ignore_Nonprinting,
           Field_Start,
           Field_End,
           Character_Start,
           Character_End,
           Field_Separator,
           Has_Field_Separator,
           Locale);
      Left_Index : Natural := Left_Key'First;
      Right_Index : Natural := Right_Key'First;
   begin
      if Numeric_Sort then
         declare
            Left_Numeric_Key : constant String :=
              Sort_Key
                (Left,
                 Fold_Case,
                 Ignore_Leading_Blanks,
                 Dictionary_Order,
                 Ignore_Nonprinting,
                 Field_Start,
                 Field_End,
                 Character_Start,
                 Character_End,
                 Field_Separator,
                 Has_Field_Separator,
                 Locale,
                 False);
            Right_Numeric_Key : constant String :=
              Sort_Key
                (Right,
                 Fold_Case,
                 Ignore_Leading_Blanks,
                 Dictionary_Order,
                 Ignore_Nonprinting,
                 Field_Start,
                 Field_End,
                 Character_Start,
                 Character_End,
                 Field_Separator,
                 Has_Field_Separator,
                 Locale,
                 False);
            Numeric_Result : constant Integer :=
              Decimal_Compare
                (Numeric_Field (Locale, Left_Numeric_Key), Numeric_Field (Locale, Right_Numeric_Key));
         begin
            if Numeric_Result /= 0 then
               return Numeric_Result > 0;
            elsif Stable_Sort then
               return False;
            end if;
         end;
      end if;

      if not Fold_Case then
         return Left_Key > Right_Key;
      end if;

      while Left_Index <= Left_Key'Last and then Right_Index <= Right_Key'Last loop
         Left_Char := Left_Key (Left_Index);
         Right_Char := Right_Key (Right_Index);
         if Left_Char > Right_Char then
            return True;
         elsif Left_Char < Right_Char then
            return False;
         end if;
         Left_Index := Left_Index + 1;
         Right_Index := Right_Index + 1;
      end loop;

      return Left_Key'Length > Right_Key'Length;
   end Line_Greater;

   function Sort_Key_Comparison
     (Left, Right : String;
      Key : Sort_Key_Definition;
      Fold_Case,
      Numeric_Sort,
      Ignore_Leading_Blanks,
      Dictionary_Order,
      Ignore_Nonprinting : Boolean;
      Field_Separator : Character;
      Has_Field_Separator : Boolean;
      Locale : String := "") return Integer
   is
      Effective_Fold_Case : constant Boolean := Fold_Case or else Key.Fold_Case;
      Effective_Numeric_Sort : constant Boolean := Numeric_Sort or else Key.Numeric_Sort;
      Left_Key : constant String :=
        Sort_Key
          (Left,
           Effective_Fold_Case,
           Ignore_Leading_Blanks or else Key.Ignore_Leading_Blanks,
           Dictionary_Order or else Key.Dictionary_Order,
           Ignore_Nonprinting or else Key.Ignore_Nonprinting,
           Key.Field_Start,
           Key.Field_End,
           Key.Character_Start,
           Key.Character_End,
           Field_Separator,
           Has_Field_Separator,
           Locale);
      Right_Key : constant String :=
        Sort_Key
          (Right,
           Effective_Fold_Case,
           Ignore_Leading_Blanks or else Key.Ignore_Leading_Blanks,
           Dictionary_Order or else Key.Dictionary_Order,
           Ignore_Nonprinting or else Key.Ignore_Nonprinting,
           Key.Field_Start,
           Key.Field_End,
           Key.Character_Start,
           Key.Character_End,
           Field_Separator,
           Has_Field_Separator,
           Locale);
      Numeric_Result : Integer;
   begin
      if Effective_Numeric_Sort then
         declare
            Left_Numeric_Key : constant String :=
              Sort_Key
                (Left,
                 Effective_Fold_Case,
                 Ignore_Leading_Blanks or else Key.Ignore_Leading_Blanks,
                 Dictionary_Order or else Key.Dictionary_Order,
                 Ignore_Nonprinting or else Key.Ignore_Nonprinting,
                 Key.Field_Start,
                 Key.Field_End,
                 Key.Character_Start,
                 Key.Character_End,
                 Field_Separator,
                 Has_Field_Separator,
                 Locale,
                 False);
            Right_Numeric_Key : constant String :=
              Sort_Key
                (Right,
                 Effective_Fold_Case,
                 Ignore_Leading_Blanks or else Key.Ignore_Leading_Blanks,
                 Dictionary_Order or else Key.Dictionary_Order,
                 Ignore_Nonprinting or else Key.Ignore_Nonprinting,
                 Key.Field_Start,
                 Key.Field_End,
                 Key.Character_Start,
                 Key.Character_End,
                 Field_Separator,
                 Has_Field_Separator,
                 Locale,
                 False);
         begin
            Numeric_Result :=
              Decimal_Compare
                (Numeric_Field (Locale, Left_Numeric_Key), Numeric_Field (Locale, Right_Numeric_Key));
         end;
         if Numeric_Result /= 0 then
            return Numeric_Result;
         end if;
      end if;

      if Left_Key > Right_Key then
         return 1;
      elsif Left_Key < Right_Key then
         return -1;
      else
         return 0;
      end if;
   end Sort_Key_Comparison;

   function Line_Greater_With_Keys
     (Left, Right : String;
      Keys : Sort_Key_Vectors.Vector;
      Fold_Case,
      Numeric_Sort,
      Ignore_Leading_Blanks,
      Stable_Sort,
      Dictionary_Order,
      Ignore_Nonprinting : Boolean;
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Field_Separator : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Locale : String := "")
      return Boolean
   is
      Comparison : Integer;
   begin
      if Keys.Length = 0 then
         return Line_Greater
           (Left,
            Right,
            Fold_Case,
            Numeric_Sort,
            Ignore_Leading_Blanks,
            Stable_Sort,
            Dictionary_Order,
            Ignore_Nonprinting,
            Field_Start,
            Field_End,
            Character_Start,
            Character_End,
            Field_Separator,
            Has_Field_Separator,
            Locale);
      end if;

      for Key of Keys loop
         Comparison :=
           Sort_Key_Comparison
             (Left,
              Right,
              Key,
              Fold_Case,
              Numeric_Sort,
              Ignore_Leading_Blanks,
              Dictionary_Order,
              Ignore_Nonprinting,
              Field_Separator,
              Has_Field_Separator,
              Locale);
         if Comparison /= 0 then
            return (if Key.Reverse_Order then Comparison < 0 else Comparison > 0);
         end if;
      end loop;

      return False;
   end Line_Greater_With_Keys;

   function Sort_Keys_Equal
     (Left, Right : String;
      Keys : Sort_Key_Vectors.Vector;
      Fold_Case,
      Ignore_Leading_Blanks,
      Dictionary_Order,
      Ignore_Nonprinting : Boolean;
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Field_Separator : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Locale : String := "") return Boolean
   is
   begin
      if Keys.Length = 0 then
         return
           Sort_Key
             (Left,
              Fold_Case,
              Ignore_Leading_Blanks,
              Dictionary_Order,
              Ignore_Nonprinting,
              Field_Start,
              Field_End,
              Character_Start,
              Character_End,
              Field_Separator,
              Has_Field_Separator,
              Locale)
           =
           Sort_Key
             (Right,
              Fold_Case,
              Ignore_Leading_Blanks,
              Dictionary_Order,
              Ignore_Nonprinting,
              Field_Start,
              Field_End,
              Character_Start,
              Character_End,
              Field_Separator,
              Has_Field_Separator,
              Locale);
      end if;

      for Key of Keys loop
         if Sort_Key_Comparison
              (Left,
               Right,
               Key,
               Fold_Case,
               False,
               Ignore_Leading_Blanks,
               Dictionary_Order,
               Ignore_Nonprinting,
               Field_Separator,
               Has_Field_Separator,
               Locale) /= 0
         then
            return False;
         end if;
      end loop;

      return True;
   end Sort_Keys_Equal;

   procedure Sort_Lines
     (Lines : in out String_Vectors.Vector;
      Keys : Sort_Key_Vectors.Vector;
      Fold_Case,
      Numeric_Sort,
      Ignore_Leading_Blanks,
      Stable_Sort,
      Dictionary_Order,
      Ignore_Nonprinting : Boolean;
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Field_Separator : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Locale : String := "")
   is
      Swapped : Boolean;
   begin
      if Lines.Length < 2 then
         return;
      end if;

      loop
         Swapped := False;
         for I in 1 .. Positive (Lines.Length) - 1 loop
            if Line_Greater_With_Keys
              (Lines.Element (I),
               Lines.Element (I + 1),
               Keys,
               Fold_Case,
               Numeric_Sort,
               Ignore_Leading_Blanks,
               Stable_Sort,
               Dictionary_Order,
               Ignore_Nonprinting,
               Field_Start,
               Field_End,
               Character_Start,
               Character_End,
               Field_Separator,
               Has_Field_Separator,
               Locale)
            then
               declare
                  Temp : constant String := Lines.Element (I);
               begin
                  Lines.Replace_Element (I, Lines.Element (I + 1));
                  Lines.Replace_Element (I + 1, Temp);
                  Swapped := True;
               end;
            end if;
         end loop;
         exit when not Swapped;
      end loop;
   end Sort_Lines;

   function Lines_Are_Sorted
     (Lines : String_Vectors.Vector;
      Keys : Sort_Key_Vectors.Vector;
      Fold_Case,
      Numeric_Sort,
      Ignore_Leading_Blanks,
      Reverse_Order,
      Unique,
      Stable_Sort,
      Dictionary_Order,
      Ignore_Nonprinting : Boolean;
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Field_Separator : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Locale : String := "")
      return Boolean
   is
   begin
      if Lines.Length < 2 then
         return True;
      end if;

      for I in 1 .. Positive (Lines.Length) - 1 loop
         if (not Reverse_Order)
           and then Line_Greater_With_Keys
             (Lines.Element (I),
              Lines.Element (I + 1),
              Keys,
              Fold_Case,
              Numeric_Sort,
              Ignore_Leading_Blanks,
              Stable_Sort,
              Dictionary_Order,
              Ignore_Nonprinting,
              Field_Start,
              Field_End,
              Character_Start,
              Character_End,
              Field_Separator,
              Has_Field_Separator,
              Locale)
         then
            return False;
         elsif Reverse_Order
           and then Line_Greater_With_Keys
             (Lines.Element (I + 1),
              Lines.Element (I),
              Keys,
              Fold_Case,
              Numeric_Sort,
              Ignore_Leading_Blanks,
              Stable_Sort,
              Dictionary_Order,
              Ignore_Nonprinting,
              Field_Start,
              Field_End,
              Character_Start,
              Character_End,
              Field_Separator,
              Has_Field_Separator,
              Locale)
         then
            return False;
         end if;

         if Unique then
            if Sort_Keys_Equal
                 (Lines.Element (I),
                  Lines.Element (I + 1),
                  Keys,
                  Fold_Case,
                  Ignore_Leading_Blanks,
                  Dictionary_Order,
                  Ignore_Nonprinting,
                  Field_Start,
                  Field_End,
                  Character_Start,
                  Character_End,
                  Field_Separator,
                  Has_Field_Separator,
                  Locale)
            then
               return False;
            end if;
         end if;
      end loop;

      return True;
   end Lines_Are_Sorted;

   function Join_Path (Directory, Leaf : String) return String is
   begin
      if Directory = "" or else Directory (Directory'Last) = '/' then
         return Directory & Leaf;
      else
         return Directory & "/" & Leaf;
      end if;
   end Join_Path;

   function Simple_Name (Path : String) return String is
   begin
      return FS.Simple_Name (Path);
   exception
      when others =>
         return Path;
   end Simple_Name;

   function Natural_Image (Value : Natural) return String is
      Raw : constant String := Natural'Image (Value);
   begin
      return Raw (Raw'First + 1 .. Raw'Last);
   end Natural_Image;

   function Parse_Natural_Operand
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Text    : String;
      Subject : String;
      Value   : out Natural) return Boolean
   is
      Parsed : constant Posix_Tools.Numbers.Parse_Result := Posix_Tools.Numbers.Parse_Nonnegative (Text);
   begin
      if Parsed.Status /= Posix_Tools.Numbers.Valid or else Parsed.Value > Posix_Tools.Numbers.Count (Natural'Last) then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid " & Subject & " '" & Text & "'");
         Value := 0;
         return False;
      end if;

      Value := Natural (Parsed.Value);
      return True;
   end Parse_Natural_Operand;

   function Two_Digits (Value : Natural) return String is
      Tens : constant Natural := Value / 10;
      Ones : constant Natural := Value mod 10;
   begin
      return Character'Val (Character'Pos ('0') + Tens) & Character'Val (Character'Pos ('0') + Ones);
   end Two_Digits;

   function Four_Digits (Value : Natural) return String is
      Thousands : constant Natural := (Value / 1_000) mod 10;
      Hundreds  : constant Natural := (Value / 100) mod 10;
      Tens      : constant Natural := (Value / 10) mod 10;
      Ones      : constant Natural := Value mod 10;
   begin
      return Character'Val (Character'Pos ('0') + Thousands)
        & Character'Val (Character'Pos ('0') + Hundreds)
        & Character'Val (Character'Pos ('0') + Tens)
        & Character'Val (Character'Pos ('0') + Ones);
   end Four_Digits;

   function Day_Of_Year (Year, Month, Day : Natural) return Natural is
      Result : Natural := Day;

      function Leap_Year return Boolean is
      begin
         return (Year mod 4 = 0 and then Year mod 100 /= 0) or else Year mod 400 = 0;
      end Leap_Year;
   begin
      for M in 1 .. Month - 1 loop
         Result :=
           Result
           + (case M is
                when 1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
                when 4 | 6 | 9 | 11 => 30,
                when others => (if Leap_Year then 29 else 28));
      end loop;
      return Result;
   end Day_Of_Year;

   function Three_Digits (Value : Natural) return String is
      Hundreds : constant Natural := (Value / 100) mod 10;
      Tens     : constant Natural := (Value / 10) mod 10;
      Ones     : constant Natural := Value mod 10;
   begin
      return Character'Val (Character'Pos ('0') + Hundreds)
        & Character'Val (Character'Pos ('0') + Tens)
        & Character'Val (Character'Pos ('0') + Ones);
   end Three_Digits;

   function Space_Two (Value : Natural) return String is
   begin
      if Value < 10 then
         return " " & Character'Val (Character'Pos ('0') + Value);
      else
         return Two_Digits (Value);
      end if;
   end Space_Two;

   function Week_Day_For (Year, Month, Day : Natural) return Ada.Calendar.Formatting.Day_Name is
      Offsets : constant array (1 .. 12) of Natural := [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4];
      Adjusted_Year : Natural := Year;
      Day_Index : Natural;
   begin
      if Month < 3 then
         Adjusted_Year := Adjusted_Year - 1;
      end if;

      Day_Index :=
        (Adjusted_Year
         + Adjusted_Year / 4
         - Adjusted_Year / 100
         + Adjusted_Year / 400
         + Offsets (Month)
         + Day) mod 7;

      if Day_Index = 0 then
         return Ada.Calendar.Formatting.Sunday;
      else
         return Ada.Calendar.Formatting.Day_Name'Val (Day_Index - 1);
      end if;
   end Week_Day_For;

   function Date_Text (Locale, Key, Default : String) return String is
   begin
      return Posix_Tools.Localization.Text (Locale, "posix_tools.date." & Key, Default);
   end Date_Text;

   function Month_Name (Locale : String; Month : Natural; Abbreviated : Boolean) return String is
   begin
      case Month is
         when 1 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.january" else "month.full.january"),
               (if Abbreviated then "Jan" else "January"));
         when 2 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.february" else "month.full.february"),
               (if Abbreviated then "Feb" else "February"));
         when 3 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.march" else "month.full.march"),
               (if Abbreviated then "Mar" else "March"));
         when 4 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.april" else "month.full.april"),
               (if Abbreviated then "Apr" else "April"));
         when 5 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.may" else "month.full.may"),
               "May");
         when 6 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.june" else "month.full.june"),
               (if Abbreviated then "Jun" else "June"));
         when 7 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.july" else "month.full.july"),
               (if Abbreviated then "Jul" else "July"));
         when 8 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.august" else "month.full.august"),
               (if Abbreviated then "Aug" else "August"));
         when 9 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.september" else "month.full.september"),
               (if Abbreviated then "Sep" else "September"));
         when 10 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.october" else "month.full.october"),
               (if Abbreviated then "Oct" else "October"));
         when 11 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.november" else "month.full.november"),
               (if Abbreviated then "Nov" else "November"));
         when 12 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.december" else "month.full.december"),
               (if Abbreviated then "Dec" else "December"));
         when others => return "";
      end case;
   end Month_Name;

   function Week_Day_Name
     (Locale : String;
      Day : Ada.Calendar.Formatting.Day_Name;
      Abbreviated : Boolean) return String is
   begin
      case Day is
         when Ada.Calendar.Formatting.Monday =>
            return Date_Text
              (Locale,
               (if Abbreviated then "weekday.abbrev.monday" else "weekday.full.monday"),
               (if Abbreviated then "Mon" else "Monday"));
         when Ada.Calendar.Formatting.Tuesday =>
            return Date_Text
              (Locale,
               (if Abbreviated then "weekday.abbrev.tuesday" else "weekday.full.tuesday"),
               (if Abbreviated then "Tue" else "Tuesday"));
         when Ada.Calendar.Formatting.Wednesday =>
            return Date_Text
              (Locale,
               (if Abbreviated then "weekday.abbrev.wednesday" else "weekday.full.wednesday"),
               (if Abbreviated then "Wed" else "Wednesday"));
         when Ada.Calendar.Formatting.Thursday =>
            return Date_Text
              (Locale,
               (if Abbreviated then "weekday.abbrev.thursday" else "weekday.full.thursday"),
               (if Abbreviated then "Thu" else "Thursday"));
         when Ada.Calendar.Formatting.Friday =>
            return Date_Text
              (Locale,
               (if Abbreviated then "weekday.abbrev.friday" else "weekday.full.friday"),
               (if Abbreviated then "Fri" else "Friday"));
         when Ada.Calendar.Formatting.Saturday =>
            return Date_Text
              (Locale,
               (if Abbreviated then "weekday.abbrev.saturday" else "weekday.full.saturday"),
               (if Abbreviated then "Sat" else "Saturday"));
         when Ada.Calendar.Formatting.Sunday =>
            return Date_Text
              (Locale,
               (if Abbreviated then "weekday.abbrev.sunday" else "weekday.full.sunday"),
               (if Abbreviated then "Sun" else "Sunday"));
      end case;
   end Week_Day_Name;

   type ISO_Week_Data is record
      Year : Natural;
      Week : Natural;
   end record;

   function ISO_Week_Day (Day : Ada.Calendar.Formatting.Day_Name) return Natural is
   begin
      if Day = Ada.Calendar.Formatting.Sunday then
         return 7;
      else
         return Ada.Calendar.Formatting.Day_Name'Pos (Day) + 1;
      end if;
   end ISO_Week_Day;

   function ISO_Weeks_In_Year (Year : Natural) return Natural is
      Jan_One : constant Ada.Calendar.Formatting.Day_Name := Week_Day_For (Year, 1, 1);
   begin
      if Jan_One = Ada.Calendar.Formatting.Thursday
        or else (Jan_One = Ada.Calendar.Formatting.Wednesday
                 and then ((Year mod 4 = 0 and then Year mod 100 /= 0) or else Year mod 400 = 0))
      then
         return 53;
      else
         return 52;
      end if;
   end ISO_Weeks_In_Year;

   function ISO_Week_For
     (Year  : Natural;
      Month : Natural;
      Day   : Natural) return ISO_Week_Data
   is
      Week_Day : constant Natural := ISO_Week_Day (Week_Day_For (Year, Month, Day));
      Ordinal  : constant Natural := Day_Of_Year (Year, Month, Day);
      Week     : Integer := (Integer (Ordinal) - Integer (Week_Day) + 10) / 7;
      ISO_Year : Natural := Year;
   begin
      if Week < 1 then
         ISO_Year := Year - 1;
         Week := Integer (ISO_Weeks_In_Year (ISO_Year));
      elsif Week > Integer (ISO_Weeks_In_Year (Year)) then
         ISO_Year := Year + 1;
         Week := 1;
      end if;

      return (Year => ISO_Year, Week => Natural (Week));
   end ISO_Week_For;

   function Sunday_Week_Number
     (Year  : Natural;
      Month : Natural;
      Day   : Natural) return Natural
   is
      Ordinal : constant Natural := Day_Of_Year (Year, Month, Day);
      Week_Day : constant Ada.Calendar.Formatting.Day_Name := Week_Day_For (Year, Month, Day);
      Sunday_Based_Day : constant Natural :=
        (if Week_Day = Ada.Calendar.Formatting.Sunday
         then 0
         else Ada.Calendar.Formatting.Day_Name'Pos (Week_Day) + 1);
   begin
      return (Ordinal + 6 - Sunday_Based_Day) / 7;
   end Sunday_Week_Number;

   function Monday_Week_Number
     (Year  : Natural;
      Month : Natural;
      Day   : Natural) return Natural
   is
      Ordinal : constant Natural := Day_Of_Year (Year, Month, Day);
      Week_Day : constant Ada.Calendar.Formatting.Day_Name := Week_Day_For (Year, Month, Day);
      Monday_Based_Day : constant Natural :=
        (if Week_Day = Ada.Calendar.Formatting.Sunday
         then 6
         else Ada.Calendar.Formatting.Day_Name'Pos (Week_Day));
   begin
      return (Ordinal + 6 - Monday_Based_Day) / 7;
   end Monday_Week_Number;

   function Period_Name (Locale : String; Hour : Natural) return String is
   begin
      return
        Date_Text
          (Locale,
           (if Hour < 12 then "period.am" else "period.pm"),
           (if Hour < 12 then "AM" else "PM"));
   end Period_Name;

   function Format_Date
     (Format : String;
      Time : Ada.Calendar.Time;
      Time_Zone_Offset : Ada.Calendar.Time_Zones.Time_Offset;
      Time_Zone_Name : String := "";
      Locale : String := "") return String is
      Year : Ada.Calendar.Year_Number;
      Month : Ada.Calendar.Month_Number;
      Day : Ada.Calendar.Day_Number;
      Split_Hour : Ada.Calendar.Formatting.Hour_Number;
      Split_Minute : Ada.Calendar.Formatting.Minute_Number;
      Split_Second : Ada.Calendar.Formatting.Second_Number;
      Sub_Second : Ada.Calendar.Formatting.Second_Duration;
      Hour : Natural;
      Hour_12 : Natural;
      Minute : Natural;
      Second : Natural;
      Week_Day : Ada.Calendar.Formatting.Day_Name;
      Output : Unbounded_String;
      I : Positive := Format'First;

      function Time_Zone_Image return String is
         Minutes : constant Integer := Integer (Time_Zone_Offset);
         Absolute_Minutes : constant Natural := (if Minutes < 0 then Natural (-Minutes) else Natural (Minutes));
         Hours : constant Natural := Absolute_Minutes / 60;
         Remaining_Minutes : constant Natural := Absolute_Minutes mod 60;
      begin
         return (if Minutes < 0 then "-" else "+") & Two_Digits (Hours) & Two_Digits (Remaining_Minutes);
      end Time_Zone_Image;

      function Epoch_Seconds_Image return String is
         Epoch : constant Ada.Calendar.Time := Ada.Calendar.Time_Of (1970, 1, 1, 0.0);
         Raw   : constant String := Long_Long_Integer'Image (Long_Long_Integer (Time - Epoch));
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Epoch_Seconds_Image;
   begin
      Ada.Calendar.Formatting.Split
        (Time, Year, Month, Day, Split_Hour, Split_Minute, Split_Second, Sub_Second, Time_Zone_Offset);
      Hour := Natural (Split_Hour);
      Hour_12 := Hour mod 12;
      if Hour_12 = 0 then
         Hour_12 := 12;
      end if;
      Minute := Natural (Split_Minute);
      Second := Natural (Split_Second);
      Week_Day := Week_Day_For (Natural (Year), Natural (Month), Natural (Day));

      while I <= Format'Last loop
         if Format (I) = '%' and then I < Format'Last then
            case Format (I + 1) is
               when 'a' => Append (Output, Week_Day_Name (Locale, Week_Day, True));
               when 'A' => Append (Output, Week_Day_Name (Locale, Week_Day, False));
               when 'b' | 'h' => Append (Output, Month_Name (Locale, Natural (Month), True));
               when 'B' => Append (Output, Month_Name (Locale, Natural (Month), False));
               when 'C' => Append (Output, Two_Digits (Natural (Year) / 100));
               when 'Y' => Append (Output, Four_Digits (Natural (Year)));
               when 'y' => Append (Output, Two_Digits (Natural (Year) mod 100));
               when 'm' => Append (Output, Two_Digits (Natural (Month)));
               when 'd' => Append (Output, Two_Digits (Natural (Day)));
               when 'e' => Append (Output, Space_Two (Natural (Day)));
               when 'H' => Append (Output, Two_Digits (Hour));
               when 'I' => Append (Output, Two_Digits (Hour_12));
               when 'k' => Append (Output, Space_Two (Hour));
               when 'l' => Append (Output, Space_Two (Hour_12));
               when 'M' => Append (Output, Two_Digits (Minute));
               when 'p' => Append (Output, Period_Name (Locale, Hour));
               when 'S' => Append (Output, Two_Digits (Second));
               when 's' => Append (Output, Epoch_Seconds_Image);
               when 'j' => Append (Output, Three_Digits (Day_Of_Year (Natural (Year), Natural (Month), Natural (Day))));
               when 'u' => Append (Output, Natural_Image (Ada.Calendar.Formatting.Day_Name'Pos (Week_Day) + 1));
               when 'U' =>
                  Append
                    (Output,
                     Two_Digits (Sunday_Week_Number (Natural (Year), Natural (Month), Natural (Day))));
               when 'V' =>
                  Append (Output, Two_Digits (ISO_Week_For (Natural (Year), Natural (Month), Natural (Day)).Week));
               when 'W' =>
                  Append
                    (Output,
                     Two_Digits (Monday_Week_Number (Natural (Year), Natural (Month), Natural (Day))));
               when 'G' =>
                  Append (Output, Four_Digits (ISO_Week_For (Natural (Year), Natural (Month), Natural (Day)).Year));
               when 'g' =>
                  Append
                    (Output,
                     Two_Digits (ISO_Week_For (Natural (Year), Natural (Month), Natural (Day)).Year mod 100));
               when 'z' => Append (Output, Time_Zone_Image);
               when 'Z' => Append (Output, (if Time_Zone_Name = "" then Time_Zone_Image else Time_Zone_Name));
               when 'w' =>
                  Append
                    (Output,
                     Natural_Image
                       ((if Week_Day = Ada.Calendar.Formatting.Sunday
                         then 0
                         else Ada.Calendar.Formatting.Day_Name'Pos (Week_Day) + 1)));
               when 'D' =>
                  Append
                    (Output,
                     Two_Digits (Natural (Month)) & "/"
                     & Two_Digits (Natural (Day)) & "/"
                     & Two_Digits (Natural (Year) mod 100));
               when 'c' =>
                  Append
                    (Output,
                     Week_Day_Name (Locale, Week_Day, True) & " "
                     & Month_Name (Locale, Natural (Month), True) & " "
                     & Space_Two (Natural (Day)) & " "
                     & Two_Digits (Hour) & ":"
                     & Two_Digits (Minute) & ":"
                     & Two_Digits (Second) & " "
                     & Four_Digits (Natural (Year)));
               when 'F' =>
                  Append
                    (Output,
                     Four_Digits (Natural (Year)) & "-"
                     & Two_Digits (Natural (Month)) & "-"
                     & Two_Digits (Natural (Day)));
               when 'R' => Append (Output, Two_Digits (Hour) & ":" & Two_Digits (Minute));
               when 'r' =>
                  Append
                    (Output,
                     Two_Digits (Hour_12) & ":"
                     & Two_Digits (Minute) & ":"
                     & Two_Digits (Second) & " "
                     & Period_Name (Locale, Hour));
               when 'T' => Append (Output, Two_Digits (Hour) & ":" & Two_Digits (Minute) & ":" & Two_Digits (Second));
               when 'X' => Append (Output, Two_Digits (Hour) & ":" & Two_Digits (Minute) & ":" & Two_Digits (Second));
               when 'x' =>
                  Append
                    (Output,
                     Two_Digits (Natural (Month)) & "/"
                     & Two_Digits (Natural (Day)) & "/"
                     & Two_Digits (Natural (Year) mod 100));
               when '%' => Append (Output, "%");
               when 'n' => Append (Output, LF);
               when 't' => Append (Output, Character'Val (9));
               when others =>
                  Append (Output, "%" & Format (I + 1));
            end case;
            I := I + 2;
         else
            Append (Output, Format (I));
            I := I + 1;
         end if;
      end loop;

      return To_String (Output);
   end Format_Date;

   function Glob_Matches (Pattern, Text : String) return Boolean;

   function Glob_Matches (Pattern, Text : String) return Boolean is
      function Match_From (P, T : Natural) return Boolean is
      begin
         if P > Pattern'Last then
            return T > Text'Last;
         elsif Pattern (P) = '*' then
            for Next in T .. Text'Last + 1 loop
               if Match_From (P + 1, Next) then
                  return True;
               end if;
            end loop;
            return False;
         elsif Pattern (P) = '?' then
            return T <= Text'Last and then Match_From (P + 1, T + 1);
         elsif Pattern (P) = '[' then
            declare
               Closing : Natural := 0;
            begin
               for I in P + 1 .. Pattern'Last loop
                  if Pattern (I) = ']' then
                     Closing := I;
                     exit;
                  end if;
               end loop;

               if Closing = 0 then
                  return T <= Text'Last
                    and then Pattern (P) = Text (T)
                    and then Match_From (P + 1, T + 1);
               elsif T > Text'Last then
                  return False;
               else
                  declare
                     Negated : constant Boolean := P + 1 < Closing and then Pattern (P + 1) in '!' | '^';
                     I       : Natural := (if Negated then P + 2 else P + 1);
                     Matched : Boolean := False;
                  begin
                     while I < Closing loop
                        if I + 2 < Closing and then Pattern (I + 1) = '-' then
                           if Pattern (I) <= Text (T) and then Text (T) <= Pattern (I + 2) then
                              Matched := True;
                           end if;
                           I := I + 3;
                        else
                           if Pattern (I) = Text (T) then
                              Matched := True;
                           end if;
                           I := I + 1;
                        end if;
                     end loop;

                     return (if Negated then not Matched else Matched) and then Match_From (Closing + 1, T + 1);
                  end;
               end if;
            end;
         elsif T <= Text'Last and then Pattern (P) = Text (T) then
            return Match_From (P + 1, T + 1);
         else
            return False;
         end if;
      end Match_From;
   begin
      return Match_From (Pattern'First, Text'First);
   end Glob_Matches;

   procedure Run_Cp
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Operands : String_Vectors.Vector;
      Recursive : Boolean := False;
      Preserve_Mode : Boolean := False;
      Preserve_Links : Boolean := False;
      Verbose : Boolean := False;
      Force : Boolean := False;
      Interactive : Boolean := False;
      Ok       : Boolean := True;
      Parsing_Operands : Boolean := False;

      function Confirm_Overwrite (Path : String) return Boolean is
         Buffer : Ada.Streams.Stream_Element_Array (1 .. 1);
         Last   : Ada.Streams.Stream_Element_Offset;
      begin
         if not Interactive or else Force or else not FS.Exists (Path) then
            return True;
         end if;

         Context.Put_Error_Line
           (Posix_Tools.Localization.Text_1
              (Context.Effective_Locale,
               "posix_tools.cp.overwrite.prompt",
               "path",
               Posix_Tools.Commands.Helpers.Escape_Untrusted (Path),
               "cp: overwrite '" & Posix_Tools.Commands.Helpers.Escape_Untrusted (Path) & "'?"));
         if not Context.Try_Read_Standard_Input (Buffer, Last) or else Last < Buffer'First then
            return False;
         end if;

         return Character'Val (Buffer (Buffer'First)) in 'y' | 'Y';
      end Confirm_Overwrite;
   begin
      for I in 1 .. Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (I);
         begin
            if not Parsing_Operands and then Arg = "--" then
               for J in I + 1 .. Context.Argument_Count loop
                  Operands.Append (Context.Argument (J));
               end loop;
               exit;
            elsif not Parsing_Operands and then Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when 'f' =>
                        Force := True;
                        Interactive := False;
                     when 'i' =>
                        Force := False;
                        Interactive := True;
                     when 'L' | 'H' =>
                        Preserve_Links := False;
                     when 'P' =>
                        Preserve_Links := True;
                     when 'p' => Preserve_Mode := True;
                     when 'R' | 'r' => Recursive := True;
                     when 'v' => Verbose := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                        return;
                  end case;
               end loop;
            else
               Operands.Append (Arg);
               Parsing_Operands := True;
            end if;
         end;
      end loop;

      if Operands.Length < 2 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      declare
         Count  : constant Natural := Natural (Operands.Length);
         Target : constant String := Operands.Element (Count);
      begin
         if Count = 2 then
            declare
               Destination : constant String :=
                 (if FS.Kind (Target) = FS.Directory
                  then Join_Path (Target, Simple_Name (Operands.Element (1)))
                  else Target);
               Confirmed : constant Boolean := Confirm_Overwrite (Destination);
            begin
               if Confirmed then
                  Copy_Path
                    (Context, Operands.Element (1), Destination, Recursive, Preserve_Mode, Preserve_Links, Ok);
               else
                  Ok := True;
               end if;

               if Verbose and then Ok and then Confirmed then
                  Context.Put_Line ("'" & Operands.Element (1) & "' -> '" & Destination & "'");
               end if;
            end;
         elsif FS.Kind (Target) = FS.Directory
         then
            for I in 1 .. Count - 1 loop
               declare
                  One_Ok : Boolean;
                  Destination : constant String := Join_Path (Target, Simple_Name (Operands.Element (I)));
                  Confirmed : constant Boolean := Confirm_Overwrite (Destination);
               begin
                  if Confirmed then
                     Copy_Path
                       (Context,
                        Operands.Element (I),
                        Destination,
                        Recursive,
                        Preserve_Mode,
                        Preserve_Links,
                        One_Ok);
                  else
                     One_Ok := True;
                  end if;

                  if Verbose and then One_Ok and then Confirmed then
                     Context.Put_Line
                       ("'" & Operands.Element (I) & "' -> '" & Destination & "'");
                  end if;
                  Ok := Ok and One_Ok;
               end;
            end loop;
         else
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Ok := False;
         end if;
      end;
      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Cp;

   procedure Run_Date
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Now : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Time_Zone_Offset : Ada.Calendar.Time_Zones.Time_Offset :=
        Ada.Calendar.Time_Zones.UTC_Time_Offset (Now);
      Time_Zone_Name : Unbounded_String;
      Has_Format : Boolean := False;
      Format_Arg : Unbounded_String;
      Has_Set_Time : Boolean := False;
      Set_Time : Ada.Calendar.Time := Now;
      TZ_Text : constant String := Context.Environment_Value ("TZ");
      Force_UTC : Boolean := False;
      End_Options : Boolean := False;

      function All_Digits (Text : String) return Boolean is
      begin
         return Text /= "" and then (for all Ch of Text => Ch in '0' .. '9');
      end All_Digits;

      function Two_Digit_Value (Text : String; First : Positive) return Natural is
      begin
         return (Character'Pos (Text (First)) - Character'Pos ('0')) * 10
           + Character'Pos (Text (First + 1)) - Character'Pos ('0');
      end Two_Digit_Value;

      function Parse_Set_Date_Time (Text : String; Parsed : out Ada.Calendar.Time) return Boolean is
         Dot : Natural := 0;
      begin
         if Text = "" then
            return False;
         end if;

         for I in Text'Range loop
            if Text (I) = '.' then
               if Dot /= 0 then
                  return False;
               end if;
               Dot := I;
            end if;
         end loop;

         declare
            Main_Last : constant Natural := (if Dot = 0 then Text'Last else Dot - 1);
            Main : constant String := Text (Text'First .. Main_Last);
            Seconds_Text : constant String := (if Dot = 0 then "" else Text (Dot + 1 .. Text'Last));
         begin
            if Main'Length not in 8 | 10 | 12
              or else not All_Digits (Main)
              or else (Seconds_Text /= "" and then (Seconds_Text'Length /= 2 or else not All_Digits (Seconds_Text)))
              or else (Dot /= 0 and then Seconds_Text = "")
            then
               return False;
            end if;

            declare
               Month : constant Natural := Two_Digit_Value (Main, Main'First);
               Day : constant Natural := Two_Digit_Value (Main, Main'First + 2);
               Hour : constant Natural := Two_Digit_Value (Main, Main'First + 4);
               Minute : constant Natural := Two_Digit_Value (Main, Main'First + 6);
               Second : constant Natural :=
                 (if Seconds_Text = "" then 0 else Two_Digit_Value (Seconds_Text, Seconds_Text'First));
               Year : Natural := Natural (Ada.Calendar.Year (Now));
            begin
               if Main'Length = 10 then
                  declare
                     YY : constant Natural := Two_Digit_Value (Main, Main'First + 8);
                  begin
                     Year := (if YY >= 69 then 1900 + YY else 2000 + YY);
                  end;
               elsif Main'Length = 12 then
                  Year :=
                    Two_Digit_Value (Main, Main'First + 8) * 100
                    + Two_Digit_Value (Main, Main'First + 10);
               end if;

               if Month not in 1 .. 12
                 or else Day not in 1 .. 31
                 or else Hour > 23
                 or else Minute > 59
                 or else Second > 60
                 or else Year not in Natural (Ada.Calendar.Year_Number'First) .. Natural (Ada.Calendar.Year_Number'Last)
               then
                  return False;
               end if;

               Parsed :=
                 Ada.Calendar.Formatting.Time_Of
                   (Ada.Calendar.Year_Number (Year),
                    Ada.Calendar.Month_Number (Month),
                    Ada.Calendar.Day_Number (Day),
                    Ada.Calendar.Formatting.Hour_Number (Hour),
                    Ada.Calendar.Formatting.Minute_Number (Minute),
                    Ada.Calendar.Formatting.Second_Number ((if Second = 60 then 59 else Second)),
                    Leap_Second => Second = 60,
                    Time_Zone => Time_Zone_Offset);
               return True;
            end;
         end;
      exception
         when Constraint_Error | Ada.Calendar.Time_Error =>
            return False;
      end Parse_Set_Date_Time;

      function Parse_Fixed_TZ
        (Value : String;
         Offset : out Ada.Calendar.Time_Zones.Time_Offset;
         Zone_Name : out Unbounded_String) return Boolean
      is
         Name_First  : Positive := Value'First;
         Name_Last   : Natural := 0;
         Offset_First : Natural := Value'First;

         function Is_Zone_Character (Ch : Character) return Boolean is
         begin
            return Ch in 'A' .. 'Z' | 'a' .. 'z';
         end Is_Zone_Character;

         function Parse_Offset (Text : String; Minutes : out Integer) return Boolean is
            Sign : Integer := 1;
            First : Positive := Text'First;
            Hours : Natural := 0;
            Minute_Value : Natural := 0;
         begin
            Minutes := 0;
            if Text = "" then
               return True;
            elsif Text (First) = '+' then
               Sign := 1;
               First := First + 1;
            elsif Text (First) = '-' then
               Sign := -1;
               First := First + 1;
            end if;

            if First > Text'Last then
               return False;
            end if;

            declare
               Remainder : constant String := Text (First .. Text'Last);
            begin
               if Remainder'Length = 1 or else Remainder'Length = 2 then
                  for Ch of Remainder loop
                     if Ch not in '0' .. '9' then
                        return False;
                     end if;
                     Hours := Hours * 10 + Character'Pos (Ch) - Character'Pos ('0');
                  end loop;
               elsif Remainder'Length = 4 then
                  for Ch of Remainder loop
                     if Ch not in '0' .. '9' then
                        return False;
                     end if;
                  end loop;
                  Hours := (Character'Pos (Remainder (Remainder'First)) - Character'Pos ('0')) * 10
                    + Character'Pos (Remainder (Remainder'First + 1)) - Character'Pos ('0');
                  Minute_Value := (Character'Pos (Remainder (Remainder'First + 2)) - Character'Pos ('0')) * 10
                    + Character'Pos (Remainder (Remainder'First + 3)) - Character'Pos ('0');
               elsif Remainder'Length in 3 | 5 and then Remainder (Remainder'Last - 2) = ':' then
                  declare
                     Hour_Text : constant String := Remainder (Remainder'First .. Remainder'Last - 3);
                     Minute_Text : constant String := Remainder (Remainder'Last - 1 .. Remainder'Last);
                  begin
                     if Hour_Text'Length not in 1 | 2
                       or else (for some Ch of Hour_Text => Ch not in '0' .. '9')
                       or else (for some Ch of Minute_Text => Ch not in '0' .. '9')
                     then
                        return False;
                     end if;
                     for Ch of Hour_Text loop
                        Hours := Hours * 10 + Character'Pos (Ch) - Character'Pos ('0');
                     end loop;
                     Minute_Value := (Character'Pos (Minute_Text (Minute_Text'First)) - Character'Pos ('0')) * 10
                       + Character'Pos (Minute_Text (Minute_Text'First + 1)) - Character'Pos ('0');
                  end;
               else
                  return False;
               end if;
            end;

            if Hours > 23 or else Minute_Value > 59 then
               return False;
            end if;

            Minutes := Sign * Integer (Hours * 60 + Minute_Value);
            return True;
         end Parse_Offset;

         Minutes : Integer := 0;
         Offset_Last : Natural := 0;
      begin
         if Value'Length < 3 then
            return False;
         end if;

         if Value (Value'First) = '<' then
            for I in Value'First + 1 .. Value'Last loop
               if Value (I) = '>' then
                  Name_First := Value'First + 1;
                  Name_Last := I - 1;
                  Offset_First := I + 1;
                  exit;
               end if;
            end loop;
         else
            Name_Last := Value'First - 1;
            while Name_Last < Value'Last and then Is_Zone_Character (Value (Name_Last + 1)) loop
               Name_Last := Name_Last + 1;
            end loop;
            Offset_First := Name_Last + 1;
         end if;

         if Name_Last < Name_First or else Name_Last - Name_First + 1 < 3 then
            return False;
         end if;

         if Offset_First <= Value'Last then
            Offset_Last := Offset_First - 1;
            for J in Offset_First .. Value'Last loop
               exit when Value (J) not in '+' | '-' | ':' | '0' .. '9';
               Offset_Last := J;
            end loop;

            if Offset_Last < Offset_First
              or else not Parse_Offset (Value (Offset_First .. Offset_Last), Minutes)
            then
               return False;
            end if;
         else
            if not Parse_Offset ("", Minutes) then
               return False;
            end if;
         end if;

         Offset := Ada.Calendar.Time_Zones.Time_Offset (Minutes);
         Zone_Name :=
           To_Unbounded_String
             ((if Minutes = 0
               and then Value (Name_First .. Name_Last) in "UTC" | "GMT"
               then "UTC"
               else Value (Name_First .. Name_Last)));
         return True;
      exception
         when Constraint_Error =>
            return False;
      end Parse_Fixed_TZ;

      function Parse_I18N_TZ
        (Value : String;
         Reference_Time : Ada.Calendar.Time;
         Offset : out Ada.Calendar.Time_Zones.Time_Offset;
         Zone_Name : out Unbounded_String) return Boolean
      is
         Canonical : constant String := I18N.CLDR_Data.Canonical_Time_Zone (Value);
         Year : Ada.Calendar.Year_Number;
         Month : Ada.Calendar.Month_Number;
         Day : Ada.Calendar.Day_Number;
         Hour : Ada.Calendar.Formatting.Hour_Number;
         Minute : Ada.Calendar.Formatting.Minute_Number;
         Second : Ada.Calendar.Formatting.Second_Number;
         Sub_Second : Ada.Calendar.Formatting.Second_Duration;
         Valid : Boolean;
         Offset_Seconds : Integer;
         Base_Valid : Boolean;
         Base_Minutes : Integer;
         Family : Unbounded_String;
         Short_Name : Unbounded_String;
      begin
         Ada.Calendar.Formatting.Split
           (Reference_Time, Year, Month, Day, Hour, Minute, Second, Sub_Second, Time_Zone => 0);

         Offset_Seconds :=
           I18N.CLDR_Data.Time_Zone_Offset_Seconds_At_UTC
             (Canonical,
              Natural (Year),
              Natural (Month),
              Natural (Day),
              Natural (Hour),
              Natural (Minute),
              Natural (Second),
              Valid);

         if not Valid or else Offset_Seconds mod 60 /= 0 then
            return False;
         end if;

         Offset := Ada.Calendar.Time_Zones.Time_Offset (Offset_Seconds / 60);
         Base_Minutes := I18N.CLDR_Data.Time_Zone_Base_Offset_Minutes (Canonical, Base_Valid);
         Family := To_Unbounded_String (I18N.CLDR_Data.Time_Zone_DST_Family (Canonical));
         if To_String (Family) /= "" then
            Short_Name :=
              To_Unbounded_String
                (I18N.CLDR_Data.Time_Zone_Short_Name
                   (Context.Effective_Locale,
                    To_String (Family),
                    Base_Valid and then Offset_Seconds /= Base_Minutes * 60));
         end if;

         Zone_Name :=
           (if To_String (Short_Name) /= ""
            then Short_Name
            elsif Canonical in "UTC" | "Etc/UTC" | "Etc/GMT" | "Z"
            then To_Unbounded_String ("UTC")
            else To_Unbounded_String (Canonical));
         return True;
      exception
         when Constraint_Error | Ada.Calendar.Time_Error =>
            return False;
      end Parse_I18N_TZ;

      function Parse_Host_TZ
        (Value : String;
         Reference_Time : Ada.Calendar.Time;
         Offset : out Ada.Calendar.Time_Zones.Time_Offset;
         Zone_Name : out Unbounded_String) return Boolean
      is
      begin
         return Posix_Tools.Host_Adapters.Clock.Resolve_Time_Zone (Value, Reference_Time, Offset, Zone_Name);
      end Parse_Host_TZ;
   begin
      for I in 1 .. Context.Argument_Count loop
         if not End_Options and then Context.Argument (I) = "--" then
            End_Options := True;
         elsif not End_Options and then Context.Argument (I) = "-u" then
            Time_Zone_Offset := 0;
            Time_Zone_Name := To_Unbounded_String ("UTC");
            Force_UTC := True;
         elsif Context.Argument (I)'Length > 0
           and then Context.Argument (I) (Context.Argument (I)'First) = '+'
           and then not Has_Format
           and then not Has_Set_Time
         then
            Format_Arg := To_Unbounded_String
              (Context.Argument (I) (Context.Argument (I)'First + 1 .. Context.Argument (I)'Last));
            Has_Format := True;
         elsif not Has_Format and then not Has_Set_Time then
            if Parse_Set_Date_Time (Context.Argument (I), Set_Time) then
               Has_Set_Time := True;
            else
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (I) & "'");
               return;
            end if;
         else
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "extra operand '" & Context.Argument (I) & "'");
            return;
         end if;
      end loop;

      if TZ_Text /= "" and then not Force_UTC then
         declare
            Parsed_Offset : Ada.Calendar.Time_Zones.Time_Offset;
            Parsed_Name : Unbounded_String;
         begin
            if Parse_Fixed_TZ (TZ_Text, Parsed_Offset, Parsed_Name)
              or else Parse_Host_TZ
                (TZ_Text, (if Has_Set_Time then Set_Time else Now), Parsed_Offset, Parsed_Name)
              or else Parse_I18N_TZ
                (TZ_Text, (if Has_Set_Time then Set_Time else Now), Parsed_Offset, Parsed_Name)
            then
               Time_Zone_Offset := Parsed_Offset;
               Time_Zone_Name := Parsed_Name;
            end if;
         end;
      end if;

      if Has_Set_Time and then not Context.Set_System_Date_Time (Set_Time) then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.date.set_failed", "cannot set system date");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      if Has_Format then
         Context.Put_Line
           (Format_Date
              (To_String (Format_Arg),
               (if Has_Set_Time then Set_Time else Now),
               Time_Zone_Offset,
               To_String (Time_Zone_Name),
               Context.Effective_Locale));
      else
         Context.Put_Line
           (Ada.Calendar.Formatting.Image
              ((if Has_Set_Time then Set_Time else Now),
               Time_Zone => Time_Zone_Offset));
      end if;

      Set_Success (Context, Result);
   end Run_Date;

   procedure Run_Dd
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Input  : Unbounded_String;
      Output : Unbounded_String;
      Count  : Posix_Tools.Numbers.Count := Posix_Tools.Numbers.Count'Last;
      Input_File_Count : Posix_Tools.Numbers.Count := 1;
      Input_Block_Size : Posix_Tools.Numbers.Count := 512;
      Output_Block_Size : Posix_Tools.Numbers.Count := 512;
      Conversion_Block_Size : Posix_Tools.Numbers.Count := 0;
      Skip_Blocks : Posix_Tools.Numbers.Count := 0;
      Seek_Blocks : Posix_Tools.Numbers.Count := 0;
      type Case_Conversion_Mode is (No_Case_Conversion, Uppercase_Conversion, Lowercase_Conversion);
      type Block_Conversion_Mode is (No_Block_Conversion, Block_Conversion, Unblock_Conversion);
      type Character_Set_Conversion_Mode is (No_Character_Set_Conversion, To_Ascii_Conversion, To_Ebcdic_Conversion);
      Case_Conversion : Case_Conversion_Mode := No_Case_Conversion;
      Block_Mode : Block_Conversion_Mode := No_Block_Conversion;
      Character_Set_Conversion : Character_Set_Conversion_Mode := No_Character_Set_Conversion;
      Swap_Adjacent_Bytes : Boolean := False;
      Sync_Conversion : Boolean := False;
      No_Truncate_Output : Boolean := False;
      Continue_After_Read_Error : Boolean := False;
      Data   : Unbounded_String;
      Ok     : Boolean := True;
      Input_Full_Records : Posix_Tools.Numbers.Count := 0;
      Input_Partial_Records : Posix_Tools.Numbers.Count := 0;
      Output_Full_Records : Posix_Tools.Numbers.Count := 0;
      Output_Partial_Records : Posix_Tools.Numbers.Count := 0;
      Truncated_Records : Posix_Tools.Numbers.Count := 0;

      function Record_Count_Image (Value : Posix_Tools.Numbers.Count) return String is
         Raw : constant String := Posix_Tools.Numbers.Count'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Record_Count_Image;

      function Read_Dd_Standard_Input (Read_Ok : out Boolean) return String is
         Buffer : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset
                   (Posix_Tools.Numbers.Count'Min
                      (Input_Block_Size, Posix_Tools.Numbers.Count (16 * 1024))));
         Last   : Ada.Streams.Stream_Element_Offset;
         Text   : Unbounded_String;
      begin
         Read_Ok := True;
         loop
            if not Context.Try_Read_Standard_Input (Buffer, Last) then
               Read_Ok := False;
               exit;
            end if;

            exit when Last < Buffer'First;

            for I in Buffer'First .. Last loop
               Append (Text, Character'Val (Integer (Buffer (I))));
            end loop;
         end loop;

         return To_String (Text);
      end Read_Dd_Standard_Input;

      function Selected_Input (Value : String) return String is
         Selected : Unbounded_String;
         Start    : Natural := Value'First;
         Stop     : Natural;
         Blocks   : Posix_Tools.Numbers.Count := 0;
      begin
         if Count = 0 or else Value = "" then
            return "";
         end if;

         while Start <= Value'Last
           and then Blocks < Count
         loop
            Stop :=
              Natural'Min
                (Start + Natural (Input_Block_Size) - 1,
                 Value'Last);
            Append (Selected, Value (Start .. Stop));
            Blocks := Blocks + 1;
            Start := Stop + 1;
         end loop;

         return To_String (Selected);
      end Selected_Input;

      procedure Set_Record_Counts
        (Byte_Count   : Posix_Tools.Numbers.Count;
         Block_Size   : Posix_Tools.Numbers.Count;
         Full_Records : out Posix_Tools.Numbers.Count;
         Part_Records : out Posix_Tools.Numbers.Count)
      is
      begin
         if Block_Size = 0 then
            Full_Records := 0;
            Part_Records := 0;
         else
            Full_Records := Byte_Count / Block_Size;
            Part_Records := (if Byte_Count mod Block_Size = 0 then 0 else 1);
         end if;
      end Set_Record_Counts;

      function Sync_Padded (Value : String) return String is
      begin
         if not Sync_Conversion
           or else Value'Length = 0
           or else Input_Block_Size > Posix_Tools.Numbers.Count (Natural'Last)
         then
            return Value;
         else
            declare
               Block_Size : constant Natural := Natural (Input_Block_Size);
               Remainder  : constant Natural := Value'Length mod Block_Size;
            begin
               if Remainder = 0 then
                  return Value;
               end if;

               declare
                  Padding : constant String (1 .. Block_Size - Remainder) :=
                    [others => (if Block_Mode = No_Block_Conversion then Character'Val (0) else ' ')];
               begin
                  return Value & Padding;
               end;
            end;
         end if;
      end Sync_Padded;

      type Byte_Table is array (Natural range 0 .. 255) of Natural range 0 .. 255;

      Ascii_To_Ebcdic : constant Byte_Table :=
        [
           0 =>   0,   1 =>   1,   2 =>   2,   3 =>   3,   4 =>  55,   5 =>  45,   6 =>  46,   7 =>  47,
           8 =>  22,   9 =>   5,  10 =>  37,  11 =>  11,  12 =>  12,  13 =>  13,  14 =>  14,  15 =>  15,
          16 =>  16,  17 =>  17,  18 =>  18,  19 =>  19,  20 =>  60,  21 =>  61,  22 =>  50,  23 =>  38,
          24 =>  24,  25 =>  25,  26 =>  63,  27 =>  39,  28 =>  28,  29 =>  29,  30 =>  30,  31 =>  31,
          32 =>  64,  33 =>  90,  34 => 127,  35 => 123,  36 =>  91,  37 => 108,  38 =>  80,  39 => 125,
          40 =>  77,  41 =>  93,  42 =>  92,  43 =>  78,  44 => 107,  45 =>  96,  46 =>  75,  47 =>  97,
          48 => 240,  49 => 241,  50 => 242,  51 => 243,  52 => 244,  53 => 245,  54 => 246,  55 => 247,
          56 => 248,  57 => 249,  58 => 122,  59 =>  94,  60 =>  76,  61 => 126,  62 => 110,  63 => 111,
          64 => 124,  65 => 193,  66 => 194,  67 => 195,  68 => 196,  69 => 197,  70 => 198,  71 => 199,
          72 => 200,  73 => 201,  74 => 209,  75 => 210,  76 => 211,  77 => 212,  78 => 213,  79 => 214,
          80 => 215,  81 => 216,  82 => 217,  83 => 226,  84 => 227,  85 => 228,  86 => 229,  87 => 230,
          88 => 231,  89 => 232,  90 => 233,  91 => 186,  92 => 224,  93 => 187,  94 => 176,  95 => 109,
          96 => 121,  97 => 129,  98 => 130,  99 => 131, 100 => 132, 101 => 133, 102 => 134, 103 => 135,
         104 => 136, 105 => 137, 106 => 145, 107 => 146, 108 => 147, 109 => 148, 110 => 149, 111 => 150,
         112 => 151, 113 => 152, 114 => 153, 115 => 162, 116 => 163, 117 => 164, 118 => 165, 119 => 166,
         120 => 167, 121 => 168, 122 => 169, 123 => 192, 124 =>  79, 125 => 208, 126 => 161, 127 =>   7,
         128 =>  32, 129 =>  33, 130 =>  34, 131 =>  35, 132 =>  36, 133 =>  21, 134 =>   6, 135 =>  23,
         136 =>  40, 137 =>  41, 138 =>  42, 139 =>  43, 140 =>  44, 141 =>   9, 142 =>  10, 143 =>  27,
         144 =>  48, 145 =>  49, 146 =>  26, 147 =>  51, 148 =>  52, 149 =>  53, 150 =>  54, 151 =>   8,
         152 =>  56, 153 =>  57, 154 =>  58, 155 =>  59, 156 =>   4, 157 =>  20, 158 =>  62, 159 => 255,
         160 =>  65, 161 => 170, 162 =>  74, 163 => 177, 164 => 159, 165 => 178, 166 => 106, 167 => 181,
         168 => 189, 169 => 180, 170 => 154, 171 => 138, 172 =>  95, 173 => 202, 174 => 175, 175 => 188,
         176 => 144, 177 => 143, 178 => 234, 179 => 250, 180 => 190, 181 => 160, 182 => 182, 183 => 179,
         184 => 157, 185 => 218, 186 => 155, 187 => 139, 188 => 183, 189 => 184, 190 => 185, 191 => 171,
         192 => 100, 193 => 101, 194 =>  98, 195 => 102, 196 =>  99, 197 => 103, 198 => 158, 199 => 104,
         200 => 116, 201 => 113, 202 => 114, 203 => 115, 204 => 120, 205 => 117, 206 => 118, 207 => 119,
         208 => 172, 209 => 105, 210 => 237, 211 => 238, 212 => 235, 213 => 239, 214 => 236, 215 => 191,
         216 => 128, 217 => 253, 218 => 254, 219 => 251, 220 => 252, 221 => 173, 222 => 174, 223 =>  89,
         224 =>  68, 225 =>  69, 226 =>  66, 227 =>  70, 228 =>  67, 229 =>  71, 230 => 156, 231 =>  72,
         232 =>  84, 233 =>  81, 234 =>  82, 235 =>  83, 236 =>  88, 237 =>  85, 238 =>  86, 239 =>  87,
         240 => 140, 241 =>  73, 242 => 205, 243 => 206, 244 => 203, 245 => 207, 246 => 204, 247 => 225,
         248 => 112, 249 => 221, 250 => 222, 251 => 219, 252 => 220, 253 => 141, 254 => 142, 255 => 223];

      Ebcdic_To_Ascii : constant Byte_Table :=
        [
           0 =>   0,   1 =>   1,   2 =>   2,   3 =>   3,   4 => 156,   5 =>   9,   6 => 134,   7 => 127,
           8 => 151,   9 => 141,  10 => 142,  11 =>  11,  12 =>  12,  13 =>  13,  14 =>  14,  15 =>  15,
          16 =>  16,  17 =>  17,  18 =>  18,  19 =>  19,  20 => 157,  21 => 133,  22 =>   8,  23 => 135,
          24 =>  24,  25 =>  25,  26 => 146,  27 => 143,  28 =>  28,  29 =>  29,  30 =>  30,  31 =>  31,
          32 => 128,  33 => 129,  34 => 130,  35 => 131,  36 => 132,  37 =>  10,  38 =>  23,  39 =>  27,
          40 => 136,  41 => 137,  42 => 138,  43 => 139,  44 => 140,  45 =>   5,  46 =>   6,  47 =>   7,
          48 => 144,  49 => 145,  50 =>  22,  51 => 147,  52 => 148,  53 => 149,  54 => 150,  55 =>   4,
          56 => 152,  57 => 153,  58 => 154,  59 => 155,  60 =>  20,  61 =>  21,  62 => 158,  63 =>  26,
          64 =>  32,  65 => 160,  66 => 226,  67 => 228,  68 => 224,  69 => 225,  70 => 227,  71 => 229,
          72 => 231,  73 => 241,  74 => 162,  75 =>  46,  76 =>  60,  77 =>  40,  78 =>  43,  79 => 124,
          80 =>  38,  81 => 233,  82 => 234,  83 => 235,  84 => 232,  85 => 237,  86 => 238,  87 => 239,
          88 => 236,  89 => 223,  90 =>  33,  91 =>  36,  92 =>  42,  93 =>  41,  94 =>  59,  95 => 172,
          96 =>  45,  97 =>  47,  98 => 194,  99 => 196, 100 => 192, 101 => 193, 102 => 195, 103 => 197,
         104 => 199, 105 => 209, 106 => 166, 107 =>  44, 108 =>  37, 109 =>  95, 110 =>  62, 111 =>  63,
         112 => 248, 113 => 201, 114 => 202, 115 => 203, 116 => 200, 117 => 205, 118 => 206, 119 => 207,
         120 => 204, 121 =>  96, 122 =>  58, 123 =>  35, 124 =>  64, 125 =>  39, 126 =>  61, 127 =>  34,
         128 => 216, 129 =>  97, 130 =>  98, 131 =>  99, 132 => 100, 133 => 101, 134 => 102, 135 => 103,
         136 => 104, 137 => 105, 138 => 171, 139 => 187, 140 => 240, 141 => 253, 142 => 254, 143 => 177,
         144 => 176, 145 => 106, 146 => 107, 147 => 108, 148 => 109, 149 => 110, 150 => 111, 151 => 112,
         152 => 113, 153 => 114, 154 => 170, 155 => 186, 156 => 230, 157 => 184, 158 => 198, 159 => 164,
         160 => 181, 161 => 126, 162 => 115, 163 => 116, 164 => 117, 165 => 118, 166 => 119, 167 => 120,
         168 => 121, 169 => 122, 170 => 161, 171 => 191, 172 => 208, 173 => 221, 174 => 222, 175 => 174,
         176 =>  94, 177 => 163, 178 => 165, 179 => 183, 180 => 169, 181 => 167, 182 => 182, 183 => 188,
         184 => 189, 185 => 190, 186 =>  91, 187 =>  93, 188 => 175, 189 => 168, 190 => 180, 191 => 215,
         192 => 123, 193 =>  65, 194 =>  66, 195 =>  67, 196 =>  68, 197 =>  69, 198 =>  70, 199 =>  71,
         200 =>  72, 201 =>  73, 202 => 173, 203 => 244, 204 => 246, 205 => 242, 206 => 243, 207 => 245,
         208 => 125, 209 =>  74, 210 =>  75, 211 =>  76, 212 =>  77, 213 =>  78, 214 =>  79, 215 =>  80,
         216 =>  81, 217 =>  82, 218 => 185, 219 => 251, 220 => 252, 221 => 249, 222 => 250, 223 => 255,
         224 =>  92, 225 => 247, 226 =>  83, 227 =>  84, 228 =>  85, 229 =>  86, 230 =>  87, 231 =>  88,
         232 =>  89, 233 =>  90, 234 => 178, 235 => 212, 236 => 214, 237 => 210, 238 => 211, 239 => 213,
         240 =>  48, 241 =>  49, 242 =>  50, 243 =>  51, 244 =>  52, 245 =>  53, 246 =>  54, 247 =>  55,
         248 =>  56, 249 =>  57, 250 => 179, 251 => 219, 252 => 220, 253 => 217, 254 => 218, 255 => 159];

      function Translate_Bytes (Value : String; Table : Byte_Table) return String is
         Result : String := Value;
      begin
         for I in Result'Range loop
            Result (I) := Character'Val (Table (Character'Pos (Result (I))));
         end loop;
         return Result;
      end Translate_Bytes;

      function Apply_Conversion (Value : String) return String is
         function Apply_Block_Conversion (Input : String) return String is
            Block_Size : constant Natural := Natural (Conversion_Block_Size);
            Converted  : Unbounded_String;
            Start      : Positive := Input'First;
            Effective_Block_Mode : constant Block_Conversion_Mode :=
              (if Block_Mode /= No_Block_Conversion then Block_Mode
               elsif Character_Set_Conversion = To_Ascii_Conversion then Unblock_Conversion
               elsif Character_Set_Conversion = To_Ebcdic_Conversion then Block_Conversion
               else No_Block_Conversion);

            procedure Append_Block_Record (Line : String) is
            begin
               if Line'Length >= Block_Size then
                  if Line'Length > Block_Size then
                     Truncated_Records := Truncated_Records + 1;
                  end if;
                  Append (Converted, Line (Line'First .. Line'First + Block_Size - 1));
               else
                  Append (Converted, Line);
                  for I in 1 .. Block_Size - Line'Length loop
                     Append (Converted, ' ');
                  end loop;
               end if;
            end Append_Block_Record;

            procedure Append_Unblock_Record (Record_Text : String) is
               Last : Natural := Record_Text'Last;
            begin
               while Last >= Record_Text'First and then Record_Text (Last) = ' ' loop
                  Last := Last - 1;
               end loop;
               if Last >= Record_Text'First then
                  Append (Converted, Record_Text (Record_Text'First .. Last));
               end if;
               Append (Converted, LF);
            end Append_Unblock_Record;
         begin
            if Effective_Block_Mode = No_Block_Conversion or else Input = "" then
               return Input;
            elsif Effective_Block_Mode = Block_Conversion then
               for I in Input'Range loop
                  if Input (I) = LF then
                     Append_Block_Record (Input (Start .. I - 1));
                     Start := I + 1;
                  end if;
               end loop;
               if Start <= Input'Last then
                  Append_Block_Record (Input (Start .. Input'Last));
               end if;
            else
               Start := Input'First;
               while Start <= Input'Last loop
                  declare
                     Last : constant Natural := Natural'Min (Start + Block_Size - 1, Input'Last);
                  begin
                     Append_Unblock_Record (Input (Start .. Last));
                     Start := Last + 1;
                  end;
               end loop;
            end if;

            return To_String (Converted);
         end Apply_Block_Conversion;

         Preconverted : constant String :=
           (if Character_Set_Conversion = To_Ascii_Conversion
            then Translate_Bytes (Sync_Padded (Value), Ebcdic_To_Ascii)
            else Sync_Padded (Value));
         Converted : String := Apply_Block_Conversion (Preconverted);
      begin
         if Swap_Adjacent_Bytes and then Converted'Length >= 2 then
            declare
               I : Natural := Converted'First;
            begin
               while I < Converted'Last loop
                  declare
                     Saved : constant Character := Converted (I);
                  begin
                     Converted (I) := Converted (I + 1);
                     Converted (I + 1) := Saved;
                  end;
                  I := I + 2;
               end loop;
            end;
         end if;

         case Case_Conversion is
            when No_Case_Conversion =>
               null;
            when Uppercase_Conversion =>
               for I in Converted'Range loop
                  if Converted (I) in 'a' .. 'z' then
                     Converted (I) :=
                       Character'Val (Character'Pos (Converted (I)) - Character'Pos ('a') + Character'Pos ('A'));
                  end if;
               end loop;
            when Lowercase_Conversion =>
               for I in Converted'Range loop
                  if Converted (I) in 'A' .. 'Z' then
                     Converted (I) :=
                       Character'Val (Character'Pos (Converted (I)) - Character'Pos ('A') + Character'Pos ('a'));
                  end if;
               end loop;
         end case;

         if Character_Set_Conversion = To_Ebcdic_Conversion then
            return Translate_Bytes (Converted, Ascii_To_Ebcdic);
         else
            return Converted;
         end if;
      end Apply_Conversion;

      function Parse_Conversions (Value : String) return Boolean is
         Start : Positive := Value'First;
         Stop  : Natural;
      begin
         if Value'Length = 0 then
            return False;
         elsif Value (Value'Last) = ',' then
            return False;
         end if;

         while Start <= Value'Last loop
            Stop := Start;
            while Stop <= Value'Last and then Value (Stop) /= ',' loop
               Stop := Stop + 1;
            end loop;

            if Stop = Start then
               return False;
            elsif Value (Start .. Stop - 1) = "ucase" then
               Case_Conversion := Uppercase_Conversion;
            elsif Value (Start .. Stop - 1) = "lcase" then
               Case_Conversion := Lowercase_Conversion;
            elsif Value (Start .. Stop - 1) = "swab" then
               Swap_Adjacent_Bytes := True;
            elsif Value (Start .. Stop - 1) = "sync" then
               Sync_Conversion := True;
            elsif Value (Start .. Stop - 1) = "notrunc" then
               No_Truncate_Output := True;
            elsif Value (Start .. Stop - 1) = "noerror" then
               Continue_After_Read_Error := True;
            elsif Value (Start .. Stop - 1) = "block" then
               Block_Mode := Block_Conversion;
            elsif Value (Start .. Stop - 1) = "unblock" then
               Block_Mode := Unblock_Conversion;
            elsif Value (Start .. Stop - 1) = "ascii" then
               Character_Set_Conversion := To_Ascii_Conversion;
            elsif Value (Start .. Stop - 1) = "ebcdic"
              or else Value (Start .. Stop - 1) = "ibm"
            then
               Character_Set_Conversion := To_Ebcdic_Conversion;
            else
               return False;
            end if;

            Start := Stop + 1;
         end loop;

         return True;
      end Parse_Conversions;

      function Parse_Dd_Nonnegative (Value : String) return Posix_Tools.Numbers.Parse_Result is
         Start   : Positive := Value'First;
         Stop    : Natural;
         Product : Posix_Tools.Numbers.Count := 1;

         function Parse_Dd_Factor (Factor : String) return Posix_Tools.Numbers.Parse_Result is
            Multiplier : Posix_Tools.Numbers.Count := 1;
            Last       : Natural := Factor'Last;
            Parsed     : Posix_Tools.Numbers.Parse_Result;
         begin
            if Factor'Length = 0 then
               return (Status => Posix_Tools.Numbers.Empty, Value => 0);
            elsif Factor (Factor'Last) = 'c' then
               Multiplier := 1;
               Last := Factor'Last - 1;
            elsif Factor (Factor'Last) = 'b' then
               Multiplier := 512;
               Last := Factor'Last - 1;
            elsif Factor (Factor'Last) = 'k' then
               Multiplier := 1_024;
               Last := Factor'Last - 1;
            elsif Factor (Factor'Last) = 'K' then
               Multiplier := 1_024;
               Last := Factor'Last - 1;
            elsif Factor (Factor'Last) = 'M' then
               Multiplier := 1_024 * 1_024;
               Last := Factor'Last - 1;
            elsif Factor (Factor'Last) = 'G' then
               Multiplier := 1_024 * 1_024 * 1_024;
               Last := Factor'Last - 1;
            elsif Factor (Factor'Last) = 'w' then
               Multiplier := 2;
               Last := Factor'Last - 1;
            end if;

            if Last < Factor'First then
               return (Status => Posix_Tools.Numbers.Empty, Value => 0);
            end if;

            Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Factor (Factor'First .. Last));
            if Parsed.Status /= Posix_Tools.Numbers.Valid then
               return Parsed;
            elsif Parsed.Value > Posix_Tools.Numbers.Count'Last / Multiplier then
               return (Status => Posix_Tools.Numbers.Overflow, Value => 0);
            end if;

            return (Status => Posix_Tools.Numbers.Valid, Value => Parsed.Value * Multiplier);
         end Parse_Dd_Factor;
      begin
         if Value'Length = 0 then
            return (Status => Posix_Tools.Numbers.Empty, Value => 0);
         end if;

         while Start <= Value'Last loop
            Stop := Start;
            while Stop <= Value'Last and then Value (Stop) /= 'x' loop
               Stop := Stop + 1;
            end loop;

            if Stop = Start then
               return (Status => Posix_Tools.Numbers.Empty, Value => 0);
            end if;

            declare
               Parsed : constant Posix_Tools.Numbers.Parse_Result := Parse_Dd_Factor (Value (Start .. Stop - 1));
            begin
               if Parsed.Status /= Posix_Tools.Numbers.Valid then
                  return Parsed;
               elsif Parsed.Value = 0 then
                  Product := 0;
               elsif Product > Posix_Tools.Numbers.Count'Last / Parsed.Value then
                  return (Status => Posix_Tools.Numbers.Overflow, Value => 0);
               else
                  Product := Product * Parsed.Value;
               end if;
            end;

            if Stop > Value'Last then
               exit;
            elsif Stop = Value'Last then
               return (Status => Posix_Tools.Numbers.Empty, Value => 0);
            end if;
            Start := Stop + 1;
         end loop;

         return (Status => Posix_Tools.Numbers.Valid, Value => Product);
      end Parse_Dd_Nonnegative;
   begin
      for I in 1 .. Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (I);
         begin
            if Arg'Length > 3 and then Arg (Arg'First .. Arg'First + 2) = "if=" then
               Input := To_Unbounded_String (Arg (Arg'First + 3 .. Arg'Last));
            elsif Arg'Length > 3 and then Arg (Arg'First .. Arg'First + 2) = "of=" then
               Output := To_Unbounded_String (Arg (Arg'First + 3 .. Arg'Last));
            elsif Arg'Length >= 6 and then Arg (Arg'First .. Arg'First + 5) = "count=" then
               declare
                  Parsed : constant Posix_Tools.Numbers.Parse_Result :=
                    (if Arg'Length = 6
                     then (Status => Posix_Tools.Numbers.Empty, Value => 0)
                     else Parse_Dd_Nonnegative (Arg (Arg'First + 6 .. Arg'Last)));
               begin
                  if Parsed.Status /= Posix_Tools.Numbers.Valid then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid count '" & Arg & "'");
                     return;
                  end if;
                  Count := Parsed.Value;
               end;
            elsif Arg'Length >= 6 and then Arg (Arg'First .. Arg'First + 5) = "files=" then
               declare
                  Parsed : constant Posix_Tools.Numbers.Parse_Result :=
                    (if Arg'Length = 6
                     then (Status => Posix_Tools.Numbers.Empty, Value => 0)
                     else Parse_Dd_Nonnegative (Arg (Arg'First + 6 .. Arg'Last)));
               begin
                  if Parsed.Status /= Posix_Tools.Numbers.Valid or else Parsed.Value = 0 then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid file count '" & Arg & "'");
                     return;
                  end if;
                  Input_File_Count := Parsed.Value;
               end;
            elsif Arg'Length >= 5 and then Arg (Arg'First .. Arg'First + 4) = "skip=" then
               declare
                  Parsed : constant Posix_Tools.Numbers.Parse_Result :=
                    (if Arg'Length = 5
                     then (Status => Posix_Tools.Numbers.Empty, Value => 0)
                     else Parse_Dd_Nonnegative (Arg (Arg'First + 5 .. Arg'Last)));
               begin
                  if Parsed.Status /= Posix_Tools.Numbers.Valid then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid skip '" & Arg & "'");
                     return;
                  end if;
                  Skip_Blocks := Parsed.Value;
               end;
            elsif Arg'Length >= 6 and then Arg (Arg'First .. Arg'First + 5) = "iseek=" then
               declare
                  Parsed : constant Posix_Tools.Numbers.Parse_Result :=
                    (if Arg'Length = 6
                     then (Status => Posix_Tools.Numbers.Empty, Value => 0)
                     else Parse_Dd_Nonnegative (Arg (Arg'First + 6 .. Arg'Last)));
               begin
                  if Parsed.Status /= Posix_Tools.Numbers.Valid then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid skip '" & Arg & "'");
                     return;
                  end if;
                  Skip_Blocks := Parsed.Value;
               end;
            elsif Arg'Length >= 5 and then Arg (Arg'First .. Arg'First + 4) = "seek=" then
               declare
                  Parsed : constant Posix_Tools.Numbers.Parse_Result :=
                    (if Arg'Length = 5
                     then (Status => Posix_Tools.Numbers.Empty, Value => 0)
                     else Parse_Dd_Nonnegative (Arg (Arg'First + 5 .. Arg'Last)));
               begin
                  if Parsed.Status /= Posix_Tools.Numbers.Valid then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid seek '" & Arg & "'");
                     return;
                  end if;
                  Seek_Blocks := Parsed.Value;
               end;
            elsif Arg'Length >= 6 and then Arg (Arg'First .. Arg'First + 5) = "oseek=" then
               declare
                  Parsed : constant Posix_Tools.Numbers.Parse_Result :=
                    (if Arg'Length = 6
                     then (Status => Posix_Tools.Numbers.Empty, Value => 0)
                     else Parse_Dd_Nonnegative (Arg (Arg'First + 6 .. Arg'Last)));
               begin
                  if Parsed.Status /= Posix_Tools.Numbers.Valid then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid seek '" & Arg & "'");
                     return;
                  end if;
                  Seek_Blocks := Parsed.Value;
               end;
            elsif Arg'Length >= 4 and then Arg (Arg'First .. Arg'First + 3) = "ibs=" then
               declare
                  Parsed : constant Posix_Tools.Numbers.Parse_Result :=
                    (if Arg'Length = 4
                     then (Status => Posix_Tools.Numbers.Empty, Value => 0)
                     else Parse_Dd_Nonnegative (Arg (Arg'First + 4 .. Arg'Last)));
               begin
                  if Parsed.Status /= Posix_Tools.Numbers.Valid or else Parsed.Value = 0 then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid block size '" & Arg & "'");
                     return;
                  end if;
                  Input_Block_Size := Parsed.Value;
               end;
            elsif Arg'Length >= 4 and then Arg (Arg'First .. Arg'First + 3) = "obs=" then
               declare
                  Parsed : constant Posix_Tools.Numbers.Parse_Result :=
                    (if Arg'Length = 4
                     then (Status => Posix_Tools.Numbers.Empty, Value => 0)
                     else Parse_Dd_Nonnegative (Arg (Arg'First + 4 .. Arg'Last)));
               begin
                  if Parsed.Status /= Posix_Tools.Numbers.Valid or else Parsed.Value = 0 then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid block size '" & Arg & "'");
                     return;
                  end if;
                  Output_Block_Size := Parsed.Value;
               end;
            elsif Arg'Length >= 4 and then Arg (Arg'First .. Arg'First + 3) = "cbs=" then
               declare
                  Parsed : constant Posix_Tools.Numbers.Parse_Result :=
                    (if Arg'Length = 4
                     then (Status => Posix_Tools.Numbers.Empty, Value => 0)
                     else Parse_Dd_Nonnegative (Arg (Arg'First + 4 .. Arg'Last)));
               begin
                  if Parsed.Status /= Posix_Tools.Numbers.Valid or else Parsed.Value = 0 then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid block size '" & Arg & "'");
                     return;
                  end if;
                  Conversion_Block_Size := Parsed.Value;
               end;
            elsif Arg'Length >= 3 and then Arg (Arg'First .. Arg'First + 2) = "bs=" then
               declare
                  Parsed : constant Posix_Tools.Numbers.Parse_Result :=
                    (if Arg'Length = 3
                     then (Status => Posix_Tools.Numbers.Empty, Value => 0)
                     else Parse_Dd_Nonnegative (Arg (Arg'First + 3 .. Arg'Last)));
               begin
                  if Parsed.Status /= Posix_Tools.Numbers.Valid or else Parsed.Value = 0 then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid block size '" & Arg & "'");
                     return;
                  end if;
                  Input_Block_Size := Parsed.Value;
                  Output_Block_Size := Parsed.Value;
               end;
            elsif Arg'Length >= 5 and then Arg (Arg'First .. Arg'First + 4) = "conv=" then
               if Arg'Length = 5 or else not Parse_Conversions (Arg (Arg'First + 5 .. Arg'Last)) then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid conversion '" & Arg & "'");
                  return;
               end if;
            else
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand '" & Arg & "'");
               return;
            end if;
         end;
      end loop;

      if Block_Mode /= No_Block_Conversion
        and then (Conversion_Block_Size = 0
                  or else Conversion_Block_Size > Posix_Tools.Numbers.Count (Natural'Last))
      then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid block size 'cbs'");
         return;
      end if;

      if Character_Set_Conversion /= No_Character_Set_Conversion
        and then (Conversion_Block_Size = 0
                  or else Conversion_Block_Size > Posix_Tools.Numbers.Count (Natural'Last))
      then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid block size 'cbs'");
         return;
      end if;

      if Input_File_Count = 0 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid file count 'files'");
         return;
      end if;

      Data :=
        To_Unbounded_String
          ((if Length (Input) = 0 then Read_Dd_Standard_Input (Ok)
            else Read_File (To_String (Input), Ok)));
      if not Ok then
         if not Continue_After_Read_Error then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context,
            (if Length (Input) = 0 then "standard input" else To_String (Input)),
            "posix_tools.diagnostic.file.read_failed",
            "cannot read file");
         Ok := True;
      end if;

      declare
         Full : constant String := To_String (Data);
         Limit : Posix_Tools.Numbers.Count;
         Prefix_Count : Posix_Tools.Numbers.Count;
         Start : Natural;
         Last : Natural;
      begin
         if Skip_Blocks > Posix_Tools.Numbers.Count'Last / Input_Block_Size
           or else Seek_Blocks > Posix_Tools.Numbers.Count'Last / Output_Block_Size
         then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "offset overflow");
            return;
         end if;

         declare
            Skip_Bytes : constant Posix_Tools.Numbers.Count := Skip_Blocks * Input_Block_Size;
         begin
            Start :=
              (if Skip_Bytes >= Posix_Tools.Numbers.Count (Full'Length)
               then Full'Last + 1
               else Full'First + Natural (Skip_Bytes));
         end;

         if Count = Posix_Tools.Numbers.Count'Last then
            Limit :=
              (if Start > Full'Last
               then 0
               else Posix_Tools.Numbers.Count (Full'Last - Start + 1));
         elsif Count > Posix_Tools.Numbers.Count'Last / Input_Block_Size then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "count overflow");
            return;
         else
            Limit := Count * Input_Block_Size;
         end if;

         Last :=
           (if Start > Full'Last
            then Start - 1
            elsif Limit > Posix_Tools.Numbers.Count (Full'Last - Start + 1)
            then Full'Last
            else Start + Natural (Limit) - 1);

         Prefix_Count := Seek_Blocks * Output_Block_Size;
         if Prefix_Count > Posix_Tools.Numbers.Count (Natural'Last) then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "offset overflow");
            return;
         end if;

         declare
            Prefix : constant String (1 .. Natural (Prefix_Count)) := [others => Character'Val (0)];
            Raw_Slice : constant String := Selected_Input (if Last < Start then "" else Full (Start .. Last));
            Slice  : constant String := Apply_Conversion (Raw_Slice);

            procedure Write_Dd_Output_File is
               use Ada.Streams.Stream_IO;
               File : File_Type;
            begin
               Ok := False;
               if No_Truncate_Output and then FS.Exists (To_String (Output)) then
                  declare
                     Existing_Ok : Boolean := False;
                     Existing    : constant String := Read_File (To_String (Output), Existing_Ok);
                     Combined    : Unbounded_String;
                     Offset      : constant Natural := Natural (Prefix_Count);
                     Write_Last  : constant Natural := Offset + Slice'Length;
                  begin
                     if not Existing_Ok then
                        return;
                     end if;

                     for I in 1 .. Offset loop
                        if I <= Existing'Length then
                           Append (Combined, Existing (Existing'First + I - 1));
                        else
                           Append (Combined, Character'Val (0));
                        end if;
                     end loop;

                     Append (Combined, Slice);

                     if Write_Last < Existing'Length then
                        Append (Combined, Existing (Existing'First + Write_Last .. Existing'Last));
                     end if;
                     Write_File (To_String (Output), To_String (Combined), False, Ok);
                  end;
               else
                  Create (File, Out_File, To_String (Output));

                  if Slice'Length > 0 then
                     Set_Index (File, Ada.Streams.Stream_IO.Count (Prefix_Count) + 1);
                     declare
                        Buffer : Ada.Streams.Stream_Element_Array
                          (1 .. Ada.Streams.Stream_Element_Offset (Slice'Length));
                     begin
                        for I in Slice'Range loop
                           Buffer (Ada.Streams.Stream_Element_Offset (I - Slice'First + 1)) :=
                             Ada.Streams.Stream_Element (Character'Pos (Slice (I)));
                        end loop;
                        Write (File, Buffer);
                     end;
                  end if;

                  Close (File);
                  Ok := True;
               end if;
            exception
               when others =>
                  if Is_Open (File) then
                     Close (File);
                  end if;
                  Ok := False;
            end Write_Dd_Output_File;
         begin
            Set_Record_Counts
              (Posix_Tools.Numbers.Count (Raw_Slice'Length),
               Input_Block_Size,
               Input_Full_Records,
               Input_Partial_Records);
            Set_Record_Counts
              (Posix_Tools.Numbers.Count (Slice'Length),
               Output_Block_Size,
               Output_Full_Records,
               Output_Partial_Records);

            if Length (Output) = 0 then
               Context.Put (Prefix & Slice);
            else
               Write_Dd_Output_File;
            end if;
         end;
      end;

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
      if Result.Status = Posix_Tools.Exit_Status.Success then
         Context.Put_Error_Line
           (Record_Count_Image (Input_Full_Records)
            & "+"
            & Record_Count_Image (Input_Partial_Records)
            & " records in");
         Context.Put_Error_Line
           (Record_Count_Image (Output_Full_Records)
            & "+"
            & Record_Count_Image (Output_Partial_Records)
            & " records out");
         if Truncated_Records > 0 then
            Context.Put_Error_Line
              (Record_Count_Image (Truncated_Records)
               & (if Truncated_Records = 1 then " truncated record" else " truncated records"));
         end if;
      end if;
   end Run_Dd;

   procedure Run_Env
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Pairs : Posix_Tools.Arguments.Vector;
      First : Positive := 1;
      End_Options : Boolean := False;

      function Equal_Position (Text : String) return Natural is
      begin
         for I in Text'Range loop
            if Text (I) = '=' then
               return I;
            end if;
         end loop;
         return 0;
      end Equal_Position;

      procedure Replace_Or_Append (Pair : String) is
         Equal : constant Natural := Equal_Position (Pair);
      begin
         if Equal = 0 then
            return;
         end if;

         for I in 1 .. Natural (Pairs.Length) loop
            declare
               Existing : constant String := Pairs.Element (I);
               Existing_Equal : constant Natural := Equal_Position (Existing);
            begin
               if Existing_Equal > 0
                 and then Existing (Existing'First .. Existing_Equal - 1) = Pair (Pair'First .. Equal - 1)
               then
                  Pairs.Replace_Element (I, Pair);
                  return;
               end if;
            end;
         end loop;

         Pairs.Append (Pair);
      end Replace_Or_Append;

      procedure Remove_Name (Name : String) is
         I : Natural := 1;
      begin
         while I <= Natural (Pairs.Length) loop
            declare
               Existing : constant String := Pairs.Element (I);
               Existing_Equal : constant Natural := Equal_Position (Existing);
            begin
               if Existing_Equal > 0 and then Existing (Existing'First .. Existing_Equal - 1) = Name then
                  Pairs.Delete (I);
               else
                  I := I + 1;
               end if;
            end;
         end loop;
      end Remove_Name;
   begin
      Pairs := Context.Environment_Pairs;
      while First <= Context.Argument_Count loop
         if not End_Options and then Context.Argument (First) = "--" then
            End_Options := True;
            First := First + 1;
         elsif not End_Options and then Context.Argument (First) = "-i" then
            Pairs.Clear;
            First := First + 1;
         elsif not End_Options and then Context.Argument (First) = "-u" then
            if First = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-u'");
               return;
            elsif Context.Argument (First + 1) = ""
              or else (for some Ch of Context.Argument (First + 1) => Ch = '=')
            then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (First + 1) & "'");
               return;
            end if;
            Remove_Name (Context.Argument (First + 1));
            First := First + 2;
         elsif (for some Ch of Context.Argument (First) => Ch = '=') then
            if Context.Argument (First) (Context.Argument (First)'First) = '=' then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (First) & "'");
               return;
            end if;
            Replace_Or_Append (Context.Argument (First));
            First := First + 1;
         else
            exit;
         end if;
      end loop;

      if First <= Context.Argument_Count then
         declare
            Utility : constant String := Context.Argument (First);
            Arguments : Posix_Tools.Arguments.Vector;
            Exit_Code : Integer := 0;
         begin
            for I in First + 1 .. Context.Argument_Count loop
               Arguments.Append (Context.Argument (I));
            end loop;

            if not Context.Execute_Utility_With_Environment (Utility, Arguments, Pairs, Exit_Code) then
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Utility, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               if Exit_Code in Integer (Posix_Tools.Exit_Status.Utility_Cannot_Invoke)
                 .. Integer (Posix_Tools.Exit_Status.Utility_Not_Found)
               then
                  Result.Status := Posix_Tools.Exit_Status.Code (Exit_Code);
               else
                  Result.Status := Posix_Tools.Exit_Status.Utility_Not_Found;
               end if;
            elsif Exit_Code = 0 then
               Set_Success (Context, Result);
            elsif Exit_Code in Integer (Posix_Tools.Exit_Status.Code'First)
              .. Integer (Posix_Tools.Exit_Status.Code'Last)
            then
               Result.Status := Posix_Tools.Exit_Status.Code (Exit_Code);
            else
               Result.Status := Posix_Tools.Exit_Status.Internal_Failure;
            end if;
            return;
         end;
      end if;

      for I in 1 .. Natural (Pairs.Length) loop
         Context.Put_Line (Pairs.Element (I));
      end loop;

      Set_Success (Context, Result);
   end Run_Env;

   procedure Run_File
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First  : Positive := 1;
      All_Ok : Boolean := True;

      function Is_Text_Byte (Byte : Ada.Streams.Stream_Element) return Boolean is
         Ch : constant Character := Character'Val (Byte);
      begin
         return Ch = Character'Val (9)
           or else Ch = Character'Val (10)
           or else Ch = Character'Val (12)
           or else Ch = Character'Val (13)
           or else (Ch >= ' ' and then Ch <= '~');
      end Is_Text_Byte;

      function Description (Path : String) return String is
         Saw_Byte : Boolean := False;
         Saw_NUL  : Boolean := False;
         Saw_Text : Boolean := True;
         Read_Ok  : Boolean := True;

         procedure Inspect
           (Buffer : Ada.Streams.Stream_Element_Array;
            Last   : Ada.Streams.Stream_Element_Offset;
            Stop   : in out Boolean)
         is
            pragma Unreferenced (Stop);
         begin
            for Index in Buffer'First .. Last loop
               Saw_Byte := True;
               if Buffer (Index) = Ada.Streams.Stream_Element (0) then
                  Saw_NUL := True;
               elsif not Is_Text_Byte (Buffer (Index)) then
                  Saw_Text := False;
               end if;
            end loop;
         end Inspect;

         procedure Read_File is new FS.For_Each_File_Chunk (Inspect);
      begin
         case FS.Kind (Path) is
            when FS.Missing_File =>
               All_Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               return "";
            when FS.Directory =>
               return "directory";
            when FS.Special_File =>
               return "special file";
            when FS.Ordinary_File =>
               Read_File (Path, Read_Ok);
               if not Read_Ok then
                  All_Ok := False;
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Path, "posix_tools.diagnostic.file.read_failed", "cannot read file");
                  return "";
               elsif not Saw_Byte then
                  return "empty";
               elsif Saw_NUL or else not Saw_Text then
                  return "data";
               else
                  return "text";
               end if;
         end case;
      end Description;
   begin
      while First <= Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (First);
         begin
            if Arg = "--" then
               First := First + 1;
               exit;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option " & Arg);
               return;
            else
               exit;
            end if;
         end;
      end loop;

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for Index in First .. Context.Argument_Count loop
         declare
            Path : constant String := Context.Argument (Index);
            Text : constant String := Description (Path);
         begin
            if Text /= "" then
               Context.Put_Line (Path & ": " & Text);
            end if;
         end;
      end loop;

      Result.Status :=
        (if Context.Output_Failed or else not All_Ok
         then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run_File;

   procedure Run_Find
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      type Find_Type_Filter is
        (Any_Type,
         Directory_Type,
         Regular_File_Type,
         Symbolic_Link_Type,
         Block_Device_Type,
         Character_Device_Type,
         FIFO_Type,
         Socket_Type);
      type Find_Count_Relation is (Exact_Count, Greater_Than_Count, Less_Than_Count);
      type Find_Exec_Batch is record
         Start_Index : Positive := 1;
         Utility     : Unbounded_String;
         Prefix      : Posix_Tools.Arguments.Vector;
         Paths       : Posix_Tools.Arguments.Vector;
      end record;
      package Find_Exec_Batch_Vectors is new Ada.Containers.Vectors (Positive, Find_Exec_Batch);

      Paths       : String_Vectors.Vector;
      Expression  : String_Vectors.Vector;
      Exec_Batches : Find_Exec_Batch_Vectors.Vector;
      Has_Print   : Boolean := False;

      function Batch_Position (Start_Index : Positive) return Natural is
      begin
         for I in 1 .. Natural (Exec_Batches.Length) loop
            if Exec_Batches.Element (I).Start_Index = Start_Index then
               return I;
            end if;
         end loop;
         return 0;
      end Batch_Position;

      procedure Append_Exec_Batch_Path
        (Start_Index : Positive;
         Terminator  : Positive;
         Path        : String)
      is
         Position : constant Natural := Batch_Position (Start_Index);
         Batch    : Find_Exec_Batch;
      begin
         if Position = 0 then
            Batch.Start_Index := Start_Index;
            Batch.Utility := To_Unbounded_String (Expression.Element (Start_Index));
            for J in Start_Index + 1 .. Terminator - 2 loop
               Batch.Prefix.Append (Expression.Element (J));
            end loop;
            Batch.Paths.Append (Path);
            Exec_Batches.Append (Batch);
         else
            Batch := Exec_Batches.Element (Position);
            Batch.Paths.Append (Path);
            Exec_Batches.Replace_Element (Position, Batch);
         end if;
      end Append_Exec_Batch_Path;

      procedure Flush_Exec_Batches (Ok : in out Boolean) is
         Arguments : Posix_Tools.Arguments.Vector;
         Exit_Code : Integer := 0;
      begin
         for Batch of Exec_Batches loop
            Arguments.Clear;
            for Item of Batch.Prefix loop
               Arguments.Append (Item);
            end loop;
            for Item of Batch.Paths loop
               Arguments.Append (Item);
            end loop;
            if Natural (Batch.Paths.Length) > 0
              and then (not Context.Execute_Utility (To_String (Batch.Utility), Arguments, Exit_Code)
                        or else Exit_Code /= 0)
            then
               Ok := False;
            end if;
         end loop;
      end Flush_Exec_Batches;

      function Has_Depth return Boolean is
      begin
         return (for some Token of Expression => Token = "-depth");
      end Has_Depth;

      function Has_Xdev return Boolean is
      begin
         return (for some Token of Expression => Token = "-xdev");
      end Has_Xdev;

      function Is_Expression_Start (Arg : String) return Boolean is
      begin
         return Arg = "!"
           or else Arg = "("
           or else Arg = ")"
           or else Arg = "-a"
           or else Arg = "-o"
           or else Arg = "-depth"
           or else Arg = "-exec"
           or else Arg = "-name"
           or else Arg = "-ok"
           or else Arg = "-mtime"
           or else Arg = "-newer"
           or else Arg = "-path"
           or else Arg = "-perm"
           or else Arg = "-prune"
           or else Arg = "-size"
           or else Arg = "-type"
           or else Arg = "-user"
           or else Arg = "-group"
           or else Arg = "-nouser"
           or else Arg = "-nogroup"
           or else Arg = "-xdev"
           or else Arg = "-print"
           or else (Arg'Length > 1 and then Arg (Arg'First) = '-');
      end Is_Expression_Start;

      function Type_Filter_From_Text (Text : String; Valid : in out Boolean) return Find_Type_Filter is
      begin
         if Text = "d" then
            return Directory_Type;
         elsif Text = "f" then
            return Regular_File_Type;
         elsif Text = "l" then
            return Symbolic_Link_Type;
         elsif Text = "b" then
            return Block_Device_Type;
         elsif Text = "c" then
            return Character_Device_Type;
         elsif Text = "p" then
            return FIFO_Type;
         elsif Text = "s" then
            return Socket_Type;
         else
            Valid := False;
            return Any_Type;
         end if;
      end Type_Filter_From_Text;

      type Find_Permission_Bit_List is array (Positive range <>) of Natural;
      Find_Permission_Bits : constant Find_Permission_Bit_List :=
        [8#4000#, 8#2000#, 8#1000#, 8#400#, 8#200#, 8#100#,
         8#040#, 8#020#, 8#010#, 8#004#, 8#002#, 8#001#];

      function Find_Has_Bit (Value : Natural; Bit : Natural) return Boolean is
      begin
         return (Value / Bit) mod 2 = 1;
      end Find_Has_Bit;

      procedure Find_Set_Bit (Value : in out Natural; Bit : Natural) is
      begin
         if not Find_Has_Bit (Value, Bit) then
            Value := Value + Bit;
         end if;
      end Find_Set_Bit;

      procedure Find_Clear_Bit (Value : in out Natural; Bit : Natural) is
      begin
         if Find_Has_Bit (Value, Bit) then
            Value := Value - Bit;
         end if;
      end Find_Clear_Bit;

      procedure Find_Clear_Mask (Value : in out Natural; Mask : Natural) is
      begin
         for Bit of Find_Permission_Bits loop
            if Find_Has_Bit (Mask, Bit) then
               Find_Clear_Bit (Value, Bit);
            end if;
         end loop;
      end Find_Clear_Mask;

      function Parse_Find_Symbolic_Permission (Text : String; Mode : out Natural) return Boolean is
         Result_Mode : Natural := 0;
         Index       : Positive := Text'First;
      begin
         Mode := 0;
         if Text = "" then
            return False;
         end if;

         while Index <= Text'Last loop
            declare
               Who_Mask : Natural := 0;
               Perms    : Natural := 0;
               Op       : Character := Character'Val (0);
            begin
               while Index <= Text'Last and then Text (Index) in 'a' | 'u' | 'g' | 'o' loop
                  case Text (Index) is
                     when 'a' =>
                        Who_Mask := 8#7777#;
                     when 'u' =>
                        Who_Mask := Who_Mask + (if Find_Has_Bit (Who_Mask, 8#400#) then 0 else 8#4700#);
                     when 'g' =>
                        Who_Mask := Who_Mask + (if Find_Has_Bit (Who_Mask, 8#040#) then 0 else 8#2070#);
                     when 'o' =>
                        Who_Mask := Who_Mask + (if Find_Has_Bit (Who_Mask, 8#004#) then 0 else 8#1007#);
                     when others =>
                        null;
                  end case;
                  Index := Index + 1;
               end loop;

               if Who_Mask = 0 then
                  Who_Mask := 8#7777#;
               end if;
               if Index > Text'Last or else Text (Index) not in '+' | '-' | '=' then
                  return False;
               end if;

               Op := Text (Index);
               Index := Index + 1;
               if (Index > Text'Last or else Text (Index) = ',') and then Op /= '=' then
                  return False;
               end if;

               while Index <= Text'Last and then Text (Index) /= ',' loop
                  case Text (Index) is
                     when 'r' =>
                        if Find_Has_Bit (Who_Mask, 8#400#) then
                           Find_Set_Bit (Perms, 8#400#);
                        end if;
                        if Find_Has_Bit (Who_Mask, 8#040#) then
                           Find_Set_Bit (Perms, 8#040#);
                        end if;
                        if Find_Has_Bit (Who_Mask, 8#004#) then
                           Find_Set_Bit (Perms, 8#004#);
                        end if;
                     when 'w' =>
                        if Find_Has_Bit (Who_Mask, 8#200#) then
                           Find_Set_Bit (Perms, 8#200#);
                        end if;
                        if Find_Has_Bit (Who_Mask, 8#020#) then
                           Find_Set_Bit (Perms, 8#020#);
                        end if;
                        if Find_Has_Bit (Who_Mask, 8#002#) then
                           Find_Set_Bit (Perms, 8#002#);
                        end if;
                     when 'x' | 'X' =>
                        if Find_Has_Bit (Who_Mask, 8#100#) then
                           Find_Set_Bit (Perms, 8#100#);
                        end if;
                        if Find_Has_Bit (Who_Mask, 8#010#) then
                           Find_Set_Bit (Perms, 8#010#);
                        end if;
                        if Find_Has_Bit (Who_Mask, 8#001#) then
                           Find_Set_Bit (Perms, 8#001#);
                        end if;
                     when 's' =>
                        if Find_Has_Bit (Who_Mask, 8#4000#) then
                           Find_Set_Bit (Perms, 8#4000#);
                        end if;
                        if Find_Has_Bit (Who_Mask, 8#2000#) then
                           Find_Set_Bit (Perms, 8#2000#);
                        end if;
                     when 't' =>
                        if Find_Has_Bit (Who_Mask, 8#1000#) then
                           Find_Set_Bit (Perms, 8#1000#);
                        end if;
                     when 'u' | 'g' | 'o' =>
                        declare
                           Source_Read : constant Boolean :=
                             Find_Has_Bit
                               (Result_Mode,
                                (case Text (Index) is
                                    when 'u' => 8#400#,
                                    when 'g' => 8#040#,
                                    when others => 8#004#));
                           Source_Write : constant Boolean :=
                             Find_Has_Bit
                               (Result_Mode,
                                (case Text (Index) is
                                    when 'u' => 8#200#,
                                    when 'g' => 8#020#,
                                    when others => 8#002#));
                           Source_Exec : constant Boolean :=
                             Find_Has_Bit
                               (Result_Mode,
                                (case Text (Index) is
                                    when 'u' => 8#100#,
                                    when 'g' => 8#010#,
                                    when others => 8#001#));
                        begin
                           if Source_Read then
                              if Find_Has_Bit (Who_Mask, 8#400#) then
                                 Find_Set_Bit (Perms, 8#400#);
                              end if;
                              if Find_Has_Bit (Who_Mask, 8#040#) then
                                 Find_Set_Bit (Perms, 8#040#);
                              end if;
                              if Find_Has_Bit (Who_Mask, 8#004#) then
                                 Find_Set_Bit (Perms, 8#004#);
                              end if;
                           end if;
                           if Source_Write then
                              if Find_Has_Bit (Who_Mask, 8#200#) then
                                 Find_Set_Bit (Perms, 8#200#);
                              end if;
                              if Find_Has_Bit (Who_Mask, 8#020#) then
                                 Find_Set_Bit (Perms, 8#020#);
                              end if;
                              if Find_Has_Bit (Who_Mask, 8#002#) then
                                 Find_Set_Bit (Perms, 8#002#);
                              end if;
                           end if;
                           if Source_Exec then
                              if Find_Has_Bit (Who_Mask, 8#100#) then
                                 Find_Set_Bit (Perms, 8#100#);
                              end if;
                              if Find_Has_Bit (Who_Mask, 8#010#) then
                                 Find_Set_Bit (Perms, 8#010#);
                              end if;
                              if Find_Has_Bit (Who_Mask, 8#001#) then
                                 Find_Set_Bit (Perms, 8#001#);
                              end if;
                           end if;
                        end;
                     when others =>
                        return False;
                  end case;
                  Index := Index + 1;
               end loop;

               case Op is
                  when '+' =>
                     for Bit of Find_Permission_Bits loop
                        if Find_Has_Bit (Perms, Bit) then
                           Find_Set_Bit (Result_Mode, Bit);
                        end if;
                     end loop;
                  when '-' =>
                     Find_Clear_Mask (Result_Mode, Perms);
                  when '=' =>
                     Find_Clear_Mask (Result_Mode, Who_Mask);
                     for Bit of Find_Permission_Bits loop
                        if Find_Has_Bit (Perms, Bit) then
                           Find_Set_Bit (Result_Mode, Bit);
                        end if;
                     end loop;
                  when others =>
                     return False;
               end case;

               if Index <= Text'Last then
                  if Text (Index) /= ',' or else Index = Text'Last then
                     return False;
                  end if;
                  Index := Index + 1;
               end if;
            end;
         end loop;

         Mode := Result_Mode mod 8#10000#;
         return True;
      end Parse_Find_Symbolic_Permission;

      function Parse_Permission_Mode (Text : String; Mode : out Natural; Match_All : out Boolean) return Boolean is
         First : Positive := Text'First;
         All_Octal : Boolean := True;
      begin
         Mode := 0;
         Match_All := False;
         if Text = "" then
            return False;
         elsif Text (First) = '-' then
            Match_All := True;
            First := First + 1;
            if First > Text'Last then
               return False;
            end if;
         end if;

         for I in First .. Text'Last loop
            if Text (I) not in '0' .. '7' then
               All_Octal := False;
               exit;
            end if;
         end loop;

         if not All_Octal then
            return Parse_Find_Symbolic_Permission (Text (First .. Text'Last), Mode);
         end if;

         for I in First .. Text'Last loop
            Mode := Mode * 8 + Character'Pos (Text (I)) - Character'Pos ('0');
            if Mode > 8#7777# then
               return False;
            end if;
         end loop;

         return True;
      end Parse_Permission_Mode;

      function Parse_Find_Count
        (Text     : String;
         Count    : out Long_Long_Integer;
         Relation : out Find_Count_Relation;
         Bytes    : out Boolean) return Boolean
      is
         First : Positive := Text'First;
         Last  : Natural := Text'Last;
      begin
         Count := 0;
         Relation := Exact_Count;
         Bytes := False;
         if Text = "" then
            return False;
         elsif Text (First) = '+' then
            Relation := Greater_Than_Count;
            First := First + 1;
         elsif Text (First) = '-' then
            Relation := Less_Than_Count;
            First := First + 1;
         end if;

         if Last >= First and then Text (Last) = 'c' then
            Bytes := True;
            Last := Last - 1;
         end if;
         if First > Last then
            return False;
         end if;

         for I in First .. Last loop
            if Text (I) not in '0' .. '9' then
               return False;
            elsif Count >
              (Long_Long_Integer'Last
               - Long_Long_Integer (Character'Pos (Text (I)) - Character'Pos ('0'))) / 10
            then
               return False;
            end if;
            Count := Count * 10 + Long_Long_Integer (Character'Pos (Text (I)) - Character'Pos ('0'));
         end loop;
         return True;
      end Parse_Find_Count;

      function Validate_Expression return Boolean is
         Depth : Integer := 0;
         I     : Positive := 1;
         Valid : Boolean := True;
      begin
         while I <= Natural (Expression.Length) loop
            declare
               Token : constant String := Expression.Element (I);
            begin
               if Token = "(" then
                  Depth := Depth + 1;
                  I := I + 1;
               elsif Token = ")" then
                  Depth := Depth - 1;
                  if Depth < 0 then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand ')'");
                     return False;
                  end if;
                  I := I + 1;
               elsif Token = "!"
                or else Token = "-a"
                or else Token = "-o"
                or else Token = "-depth"
                or else Token = "-prune"
                or else Token = "-xdev"
                 or else Token = "-print"
               then
                  I := I + 1;
               elsif Token = "-exec" or else Token = "-ok" then
                  declare
                     Terminator : Natural := 0;
                  begin
                     for J in I + 1 .. Natural (Expression.Length) loop
                        if Expression.Element (J) = ";"
                          or else (Token = "-exec" and then Expression.Element (J) = "+")
                        then
                           Terminator := J;
                           exit;
                        end if;
                     end loop;

                     if Terminator = 0 then
                        Posix_Tools.Commands.Helpers.Usage_Error
                          (Context, Result, "missing option argument '-exec'");
                        return False;
                     elsif Terminator = I + 1 then
                        Posix_Tools.Commands.Helpers.Usage_Error
                          (Context, Result, "missing operand");
                        return False;
                     elsif Token = "-exec"
                       and then Expression.Element (Terminator) = "+"
                       and then Expression.Element (Terminator - 1) /= "{}"
                     then
                        Posix_Tools.Commands.Helpers.Usage_Error
                          (Context, Result, "invalid operand '+'");
                        return False;
                     end if;

                     I := Terminator + 1;
                  end;
               elsif Token = "-name" or else Token = "-path" or else Token = "-newer"
                 or else Token = "-user" or else Token = "-group"
               then
                  if I = Natural (Expression.Length) then
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "missing option argument '" & Token & "'");
                     return False;
                  end if;
                  if Token = "-newer" and then not FS.Exists (Expression.Element (I + 1)) then
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "invalid operand '" & Expression.Element (I + 1) & "'");
                     return False;
                  end if;
                  I := I + 2;
               elsif Token = "-nouser" or else Token = "-nogroup" then
                  I := I + 1;
               elsif Token = "-mtime" then
                  if I = Natural (Expression.Length) then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-mtime'");
                     return False;
                  end if;
                  declare
                     Count    : Long_Long_Integer;
                     Relation : Find_Count_Relation;
                     Bytes    : Boolean;
                  begin
                     if not Parse_Find_Count (Expression.Element (I + 1), Count, Relation, Bytes)
                       or else Bytes
                     then
                        Posix_Tools.Commands.Helpers.Usage_Error
                          (Context, Result, "invalid operand '" & Expression.Element (I + 1) & "'");
                        return False;
                     end if;
                  end;
                  I := I + 2;
               elsif Token = "-perm" then
                  if I = Natural (Expression.Length) then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-perm'");
                     return False;
                  end if;
                  declare
                     Mode      : Natural;
                     Match_All : Boolean;
                  begin
                     if not Parse_Permission_Mode (Expression.Element (I + 1), Mode, Match_All) then
                        Posix_Tools.Commands.Helpers.Usage_Error
                          (Context, Result, "invalid operand '" & Expression.Element (I + 1) & "'");
                        return False;
                     end if;
                  end;
                  I := I + 2;
               elsif Token = "-size" then
                  if I = Natural (Expression.Length) then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-size'");
                     return False;
                  end if;
                  declare
                     Count    : Long_Long_Integer;
                     Relation : Find_Count_Relation;
                     Bytes    : Boolean;
                  begin
                     if not Parse_Find_Count (Expression.Element (I + 1), Count, Relation, Bytes) then
                        Posix_Tools.Commands.Helpers.Usage_Error
                          (Context, Result, "invalid operand '" & Expression.Element (I + 1) & "'");
                        return False;
                     end if;
                  end;
                  I := I + 2;
               elsif Token = "-type" then
                  if I = Natural (Expression.Length) then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-type'");
                     return False;
                  end if;
                  if Type_Filter_From_Text (Expression.Element (I + 1), Valid) = Any_Type and then not Valid then
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "unsupported type '" & Expression.Element (I + 1) & "'");
                     return False;
                  end if;
                  I := I + 2;
               elsif Token'Length > 0 and then Token (Token'First) = '-' then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "unknown option '" & Token & "'");
                  return False;
               else
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Token & "'");
                  return False;
               end if;
            end;
         end loop;

         if Depth /= 0 then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand '('");
            return False;
         end if;

         return True;
      end Validate_Expression;

      procedure Visit
        (Path                 : String;
         Ok                   : in out Boolean;
         Root_Device          : Long_Long_Integer;
         Root_Device_Available : Boolean)
      is
         Name : constant String := Simple_Name (Path);
         Exists : constant Boolean := FS.Exists (Path);
         Is_Link : constant Boolean := FS.Is_Link (Path);
         Kind   : constant FS.File_Kind := FS.Kind (Path);
         Pruned : Boolean := False;
         Current_Device_Available : Boolean := False;
         Current_Device : constant Long_Long_Integer := FS.Device_Id (Path, Current_Device_Available);
         Crosses_Device : constant Boolean :=
           Has_Xdev
           and then Root_Device_Available
           and then Current_Device_Available
           and then Current_Device /= Root_Device;

         function Type_Matches (Filter : Find_Type_Filter) return Boolean is
         begin
            if Filter = Any_Type then
               return True;
            elsif Filter = Directory_Type then
               return Exists and then Kind = FS.Directory;
            elsif Filter = Regular_File_Type then
               return Exists and then Kind = FS.Ordinary_File;
            elsif Filter = Symbolic_Link_Type then
               return Is_Link;
            elsif not Exists or else Kind /= FS.Special_File then
               return False;
            else
               declare
                  Info : constant FS.Special_File_Info := FS.Special_File_Info_Of (Path);
               begin
                  if not Info.Available then
                     return False;
                  end if;

                  return
                    (Filter = Block_Device_Type and then Info.Kind = FS.Block_Device)
                    or else (Filter = Character_Device_Type and then Info.Kind = FS.Character_Device)
                    or else (Filter = FIFO_Type and then Info.Kind = FS.FIFO)
                    or else (Filter = Socket_Type and then Info.Kind = FS.Socket);
               end;
            end if;
         end Type_Matches;

         function Permission_Matches (Text : String; Valid : in out Boolean) return Boolean is
            Available : Boolean;
            Actual    : constant Natural := FS.File_Permission_Bits (Path, Available) mod 8#10000#;
            Expected  : Natural;
            Match_All : Boolean;

            function Has_All_Mode_Bits return Boolean is
               Bit : Natural := 1;
            begin
               while Bit <= 8#4000# loop
                  if (Expected / Bit) mod 2 = 1 and then (Actual / Bit) mod 2 = 0 then
                     return False;
                  end if;
                  Bit := Bit * 2;
               end loop;
               return True;
            end Has_All_Mode_Bits;
         begin
            if not Parse_Permission_Mode (Text, Expected, Match_All) then
               Valid := False;
               return False;
            elsif not FS.Permissions_Supported or else not Available then
               return False;
            elsif Match_All then
               return Has_All_Mode_Bits;
            else
               return Actual = Expected;
            end if;
         end Permission_Matches;

         function Size_Matches (Text : String; Valid : in out Boolean) return Boolean is
            Count    : Long_Long_Integer;
            Relation : Find_Count_Relation;
            Bytes    : Boolean;
            Units    : Long_Long_Integer;
         begin
            if not Exists or else Kind = FS.Directory then
               return False;
            elsif not Parse_Find_Count (Text, Count, Relation, Bytes) then
               Valid := False;
               return False;
            end if;

            declare
               Raw_Size : constant Long_Long_Integer := FS.Size (Path);
            begin
               Units := (if Bytes then Raw_Size else (Raw_Size + 511) / 512);
            end;

            case Relation is
               when Exact_Count =>
                  return Units = Count;
               when Greater_Than_Count =>
                  return Units > Count;
               when Less_Than_Count =>
                  return Units < Count;
            end case;
         end Size_Matches;

         function Mtime_Matches (Text : String; Valid : in out Boolean) return Boolean is
            Seconds_Per_Day : constant Duration := 86_400.0;
            Count           : Long_Long_Integer;
            Relation        : Find_Count_Relation;
            Bytes           : Boolean;

            function Threshold (Value : Long_Long_Integer; Ok : in out Boolean) return Duration is
            begin
               if Value < 0 or else Value > Long_Long_Integer (Duration'Last / Seconds_Per_Day) then
                  Ok := False;
                  return 0.0;
               end if;
               return Duration (Value) * Seconds_Per_Day;
            end Threshold;
         begin
            if not Exists or else not Parse_Find_Count (Text, Count, Relation, Bytes) or else Bytes then
               Valid := False;
               return False;
            end if;

            declare
               Now : constant Ada.Calendar.Time := Ada.Calendar.Clock;
               Path_Time : Ada.Calendar.Time;
               Ok  : Boolean := True;
            begin
               if not FS.Modification_Time (Path, Path_Time) then
                  Valid := False;
                  return False;
               end if;

               case Relation is
                  when Exact_Count =>
                     if Count = Long_Long_Integer'Last then
                        Valid := False;
                        return False;
                     end if;
                     declare
                        Low  : constant Duration := Threshold (Count, Ok);
                        High : constant Duration := Threshold (Count + 1, Ok);
                     begin
                        Valid := Valid and then Ok;
                        return Ok and then Now - Path_Time >= Low and then Now - Path_Time < High;
                     end;
                  when Greater_Than_Count =>
                     if Count = Long_Long_Integer'Last then
                        return False;
                     end if;
                     declare
                        Low : constant Duration := Threshold (Count + 1, Ok);
                     begin
                        Valid := Valid and then Ok;
                        return Ok and then Now - Path_Time >= Low;
                     end;
                  when Less_Than_Count =>
                     declare
                        High : constant Duration := Threshold (Count, Ok);
                     begin
                        Valid := Valid and then Ok;
                        return Ok and then Now - Path_Time < High;
                     end;
               end case;
            end;
         end Mtime_Matches;

         function Newer_Matches (Reference : String; Valid : in out Boolean) return Boolean is
         begin
            if not Exists or else not FS.Exists (Reference) then
               Valid := False;
               return False;
            end if;
            declare
               Path_Time      : Ada.Calendar.Time;
               Reference_Time : Ada.Calendar.Time;
            begin
               if not FS.Modification_Time (Path, Path_Time)
                 or else not FS.Modification_Time (Reference, Reference_Time)
               then
                  Valid := False;
                  return False;
               end if;
               return Path_Time > Reference_Time;
            end;
         exception
            when others =>
               Valid := False;
               return False;
         end Newer_Matches;

         function Ownership_Matches (Text : String; User : Boolean; Valid : in out Boolean) return Boolean is
            Actual_User : Natural;
            Actual_Group : Natural;
            Available : Boolean;
            Expected : Natural := 0;
            Found : Boolean := False;

            function Parse_Numeric_Id return Boolean is
            begin
               if Text = "" or else (for some Ch of Text => Ch not in '0' .. '9') then
                  return False;
               end if;
               for Ch of Text loop
                  if Expected > (Natural'Last - (Character'Pos (Ch) - Character'Pos ('0'))) / 10 then
                     return False;
                  end if;
                  Expected := Expected * 10 + Character'Pos (Ch) - Character'Pos ('0');
               end loop;
               return True;
            end Parse_Numeric_Id;
         begin
            if User then
               if not Parse_Numeric_Id then
                  Expected := FS.User_Id_For_Name (Text, Found);
               else
                  Found := True;
               end if;
            else
               if not Parse_Numeric_Id then
                  Expected := FS.Group_Id_For_Name (Text, Found);
               else
                  Found := True;
               end if;
            end if;

            if not Found or else not FS.Ownership_Supported then
               return False;
            end if;

            FS.File_Ownership (Path, Actual_User, Actual_Group, Available);
            return Available and then (if User then Actual_User = Expected else Actual_Group = Expected);
         exception
            when others =>
               Valid := False;
               return False;
         end Ownership_Matches;

         function No_Owner_Matches (User : Boolean; Valid : in out Boolean) return Boolean is
            Actual_User : Natural;
            Actual_Group : Natural;
            Available : Boolean;
         begin
            if not FS.Ownership_Supported then
               return False;
            end if;

            FS.File_Ownership (Path, Actual_User, Actual_Group, Available);
            if not Available then
               return False;
            end if;

            return
              (if User
               then FS.User_Name_For_Id (Actual_User) = ""
               else FS.Group_Name_For_Id (Actual_Group) = "");
         exception
            when others =>
               Valid := False;
               return False;
         end No_Owner_Matches;

         function Read_Ok_Affirmative return Boolean is
            Buffer : Ada.Streams.Stream_Element_Array (1 .. 1);
            Last   : Ada.Streams.Stream_Element_Offset;
            First  : Character := Character'Val (0);
         begin
            loop
               if not Context.Try_Read_Standard_Input (Buffer, Last) or else Last < Buffer'First then
                  return False;
               end if;

               declare
                  Ch : constant Character := Character'Val (Integer (Buffer (Buffer'First)));
               begin
                  if Ch = LF then
                     return First = 'y' or else First = 'Y';
                  elsif First = Character'Val (0) then
                     First := Ch;
                  end if;
               end;
            end loop;
         end Read_Ok_Affirmative;

         function Evaluate_Primary
           (Index : in out Positive;
            Valid : in out Boolean;
            Active : Boolean) return Boolean;
         function Evaluate_Not
           (Index : in out Positive;
            Valid : in out Boolean;
            Active : Boolean) return Boolean;
         function Evaluate_And
           (Index : in out Positive;
            Valid : in out Boolean;
            Active : Boolean) return Boolean;
         function Evaluate_Or
           (Index : in out Positive;
            Valid : in out Boolean;
            Active : Boolean) return Boolean;

         function Evaluate_Primary
           (Index : in out Positive;
            Valid : in out Boolean;
            Active : Boolean) return Boolean
         is
            Token : constant String := Expression.Element (Index);
         begin
            if Token = "(" then
               declare
                  Value : Boolean;
               begin
                  Index := Index + 1;
                  Value := Evaluate_Or (Index, Valid, Active);
                  if not Valid
                    or else Index > Natural (Expression.Length)
                    or else Expression.Element (Index) /= ")"
                  then
                     Valid := False;
                     return False;
                  end if;
                  Index := Index + 1;
                  return Value;
               end;
            elsif Token = "-name" then
               Index := Index + 2;
               return Active and then Glob_Matches (Expression.Element (Index - 1), Name);
            elsif Token = "-path" then
               Index := Index + 2;
               return Active and then Glob_Matches (Expression.Element (Index - 1), Path);
            elsif Token = "-mtime" then
               Index := Index + 2;
               return Active and then Mtime_Matches (Expression.Element (Index - 1), Valid);
            elsif Token = "-newer" then
               Index := Index + 2;
               return Active and then Newer_Matches (Expression.Element (Index - 1), Valid);
            elsif Token = "-perm" then
               Index := Index + 2;
               return Active and then Permission_Matches (Expression.Element (Index - 1), Valid);
            elsif Token = "-size" then
               Index := Index + 2;
               return Active and then Size_Matches (Expression.Element (Index - 1), Valid);
            elsif Token = "-type" then
               declare
                  Filter : constant Find_Type_Filter := Type_Filter_From_Text (Expression.Element (Index + 1), Valid);
               begin
                  Index := Index + 2;
                  return Active and then Valid and then Type_Matches (Filter);
               end;
            elsif Token = "-user" then
               Index := Index + 2;
               return Active and then Ownership_Matches (Expression.Element (Index - 1), True, Valid);
            elsif Token = "-group" then
               Index := Index + 2;
               return Active and then Ownership_Matches (Expression.Element (Index - 1), False, Valid);
            elsif Token = "-nouser" then
               Index := Index + 1;
               return Active and then No_Owner_Matches (True, Valid);
            elsif Token = "-nogroup" then
               Index := Index + 1;
               return Active and then No_Owner_Matches (False, Valid);
            elsif Token = "-print" then
               if Active then
                  Context.Put_Line (Path);
               end if;
               Index := Index + 1;
               return Active;
            elsif Token = "-prune" then
               if Active and then not Has_Depth then
                  Pruned := True;
               end if;
               Index := Index + 1;
               return Active;
            elsif Token = "-depth" then
               Index := Index + 1;
               return Active;
            elsif Token = "-xdev" then
               Index := Index + 1;
               return Active;
            elsif Token = "-exec" then
               declare
                  Start : constant Positive := Index + 1;
                  Terminator : Natural := 0;
                  Arguments : Posix_Tools.Arguments.Vector;
                  Exit_Code : Integer := 0;

                  function Replaced_Path (Item : String) return String is
                  begin
                     if Item = "{}" then
                        return Path;
                     else
                        return Item;
                     end if;
                  end Replaced_Path;
               begin
                  for J in Start .. Natural (Expression.Length) loop
                     if Expression.Element (J) = ";" or else Expression.Element (J) = "+" then
                        Terminator := J;
                        exit;
                     end if;
                  end loop;

                  if Terminator = 0 or else Terminator = Start then
                     Valid := False;
                     return False;
                  end if;

                  Index := Terminator + 1;
                  if not Active then
                     return False;
                  end if;

                  if Expression.Element (Terminator) = "+" then
                     Append_Exec_Batch_Path (Start, Terminator, Path);
                     return True;
                  end if;

                  for J in Start + 1 .. Terminator - 1 loop
                     Arguments.Append (Replaced_Path (Expression.Element (J)));
                  end loop;

                  if Context.Execute_Utility (Expression.Element (Start), Arguments, Exit_Code) then
                     return Exit_Code = 0;
                  else
                     return False;
                  end if;
               end;
            elsif Token = "-ok" then
               declare
                  Start : constant Positive := Index + 1;
                  Terminator : Natural := 0;
                  Arguments : Posix_Tools.Arguments.Vector;
                  Exit_Code : Integer := 0;

                  function Replaced_Path (Item : String) return String is
                  begin
                     if Item = "{}" then
                        return Path;
                     else
                        return Item;
                     end if;
                  end Replaced_Path;
               begin
                  for J in Start .. Natural (Expression.Length) loop
                     if Expression.Element (J) = ";" then
                        Terminator := J;
                        exit;
                     end if;
                  end loop;

                  if Terminator = 0 or else Terminator = Start then
                     Valid := False;
                     return False;
                  end if;

                  Index := Terminator + 1;
                  if not Active then
                     return False;
                  end if;

                  Context.Put_Error_Line
                    (Posix_Tools.Localization.Text_1
                       (Context.Effective_Locale,
                        "posix_tools.find.ok.prompt",
                        "subject",
                        Expression.Element (Start) & " ... " & Path,
                        "< " & Expression.Element (Start) & " ... " & Path & " > ?"));
                  if not Read_Ok_Affirmative then
                     return False;
                  end if;

                  for J in Start + 1 .. Terminator - 1 loop
                     Arguments.Append (Replaced_Path (Expression.Element (J)));
                  end loop;

                  if Context.Execute_Utility (Expression.Element (Start), Arguments, Exit_Code) then
                     return Exit_Code = 0;
                  else
                     return False;
                  end if;
               end;
            else
               Valid := False;
               return False;
            end if;
         end Evaluate_Primary;

         function Evaluate_Not
           (Index : in out Positive;
            Valid : in out Boolean;
            Active : Boolean) return Boolean
         is
         begin
            if Index <= Natural (Expression.Length) and then Expression.Element (Index) = "!" then
               Index := Index + 1;
               if Active then
                  return not Evaluate_Not (Index, Valid, True);
               else
                  declare
                     Ignored : constant Boolean := Evaluate_Not (Index, Valid, False);
                  begin
                     return False;
                  end;
               end if;
            else
               return Evaluate_Primary (Index, Valid, Active);
            end if;
         end Evaluate_Not;

         function Evaluate_And
           (Index : in out Positive;
            Valid : in out Boolean;
            Active : Boolean) return Boolean
         is
            Value : Boolean := Evaluate_Not (Index, Valid, Active);
            Right : Boolean;
         begin
            while Valid and then Index <= Natural (Expression.Length) loop
               exit when Expression.Element (Index) = ")" or else Expression.Element (Index) = "-o";
               if Expression.Element (Index) = "-a" then
                  Index := Index + 1;
               end if;
               exit when Index > Natural (Expression.Length) or else Expression.Element (Index) = ")";
               Right := Evaluate_Not (Index, Valid, Active and then Value);
               if Value then
                  Value := Right;
               end if;
            end loop;
            return Value;
         end Evaluate_And;

         function Evaluate_Or
           (Index : in out Positive;
            Valid : in out Boolean;
            Active : Boolean) return Boolean
         is
            Value : Boolean := Evaluate_And (Index, Valid, Active);
            Right : Boolean;
         begin
            while Valid and then Index <= Natural (Expression.Length) and then Expression.Element (Index) = "-o" loop
               Index := Index + 1;
               exit when Index > Natural (Expression.Length);
               Right := Evaluate_And (Index, Valid, Active and then not Value);
               if not Value then
                  Value := Right;
               end if;
            end loop;
            return Value;
         end Evaluate_Or;

         function Expression_Matches return Boolean is
            Index : Positive := 1;
            Valid : Boolean := True;
         begin
            if Expression.Length = 0 then
               return True;
            end if;
            return Evaluate_Or (Index, Valid, True) and then Valid and then Index > Natural (Expression.Length);
         end Expression_Matches;
      begin
         if not Has_Depth then
            if Has_Print then
               declare
                  Ignored : constant Boolean := Expression_Matches;
               begin
                  null;
               end;
            elsif Expression_Matches then
               Context.Put_Line (Path);
            end if;
         end if;
         if Exists and then Kind = FS.Directory and then not Pruned and then not Crosses_Device then
            declare
               Iteration_Ok : Boolean;

               procedure Visit_Child (Name : String; Full_Name : String; Stop : in out Boolean) is
               begin
                  pragma Unreferenced (Name, Stop);
                  Visit (Full_Name, Ok, Root_Device, Root_Device_Available);
               end Visit_Child;

               procedure For_Each_Child is new FS.For_Each_Directory_Entry (Visit_Child);
            begin
               For_Each_Child (Path, Iteration_Ok);
               Ok := Ok and Iteration_Ok;
            end;
         end if;
         if Has_Depth then
            if Has_Print then
               declare
                  Ignored : constant Boolean := Expression_Matches;
               begin
                  null;
               end;
            elsif Expression_Matches then
               Context.Put_Line (Path);
            end if;
         end if;
      exception
         when others =>
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.read_failed", "cannot read file");
      end Visit;
      Ok : Boolean := True;
   begin
      declare
         I : Positive := 1;
         End_Options : Boolean := False;
      begin
         while I <= Context.Argument_Count loop
            if not End_Options and then Context.Argument (I) = "--" then
               End_Options := True;
               I := I + 1;
            elsif not End_Options and then Is_Expression_Start (Context.Argument (I)) then
               for J in I .. Context.Argument_Count loop
                  Expression.Append (Context.Argument (J));
                  if Context.Argument (J) = "-print"
                    or else Context.Argument (J) = "-exec"
                    or else Context.Argument (J) = "-ok"
                  then
                     Has_Print := True;
                  end if;
               end loop;
               exit;
            elsif not End_Options
              and then Context.Argument (I)'Length > 1
              and then Context.Argument (I) (Context.Argument (I)'First) = '-'
            then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "unknown option '" & Context.Argument (I) & "'");
               return;
            else
               Paths.Append (Context.Argument (I));
               I := I + 1;
            end if;
         end loop;
      end;

      if Expression.Length > 0 and then not Validate_Expression then
         return;
      end if;

      if Paths.Length = 0 then
         declare
            Available : Boolean := False;
            Device    : constant Long_Long_Integer := FS.Device_Id (".", Available);
         begin
            Visit (".", Ok, Device, Available);
         end;
      else
         for I in 1 .. Natural (Paths.Length) loop
            declare
               Available : Boolean := False;
               Device    : constant Long_Long_Integer := FS.Device_Id (Paths.Element (I), Available);
            begin
               Visit (Paths.Element (I), Ok, Device, Available);
            end;
         end loop;
      end if;
      Flush_Exec_Batches (Ok);
      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Find;

   procedure Run_Link
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First : Positive := 1;
   begin
      if Context.Argument_Count > 0 and then Context.Argument (1) = "--" then
         First := 2;
      end if;

      if Context.Argument_Count - First + 1 < 2 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      elsif Context.Argument_Count - First + 1 > 2 then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "extra operand '" & Context.Argument (First + 2) & "'");
         return;
      end if;

      if FS.Create_Hard_Link (Context.Argument (First), Context.Argument (First + 1)) then
         Set_Success (Context, Result);
      else
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Context.Argument (First + 1), "posix_tools.diagnostic.file.open_failed", "cannot open file");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run_Link;

   procedure Run_Readlink
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First  : Positive := 1;
      Target : Unbounded_String;
   begin
      if Context.Argument_Count > 0 and then Context.Argument (1) = "--" then
         First := 2;
      end if;

      if Context.Argument_Count < First then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      elsif Context.Argument_Count > First then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "extra operand '" & Context.Argument (First + 1) & "'");
         return;
      end if;

      if FS.Read_Link_Target (Context.Argument (First), Target) then
         Context.Put_Line (To_String (Target));
         Set_Success (Context, Result);
      else
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Context.Argument (First), "posix_tools.diagnostic.file.open_failed", "cannot open file");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run_Readlink;

   procedure Run_Realpath
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First : Positive := 1;
      Ok    : Boolean := True;
   begin
      if Context.Argument_Count > 0 and then Context.Argument (1) = "--" then
         First := 2;
      end if;

      if Context.Argument_Count < First then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for I in First .. Context.Argument_Count loop
         begin
            Context.Put_Line (FS.Real_Path (Context.Argument (I)));
         exception
            when others =>
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Context.Argument (I), "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end;
      end loop;

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Realpath;

   procedure Run_Whoami
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      User_Id : Natural;
      Name    : Unbounded_String;
   begin
      if Context.Argument_Count > 0 then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "extra operand '" & Context.Argument (1) & "'");
         return;
      end if;

      if Host.Current_User_Id (User_Id) then
         Name := To_Unbounded_String (FS.User_Name_For_Id (User_Id));
      end if;

      if Length (Name) > 0 then
         Context.Put_Line (To_String (Name));
         Set_Success (Context, Result);
      else
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.unsupported", "unsupported platform capability");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run_Whoami;

   procedure Run_Logname
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Name : Unbounded_String := To_Unbounded_String (Context.Environment_Value ("LOGNAME"));
   begin
      if Context.Argument_Count > 0 then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "extra operand '" & Context.Argument (1) & "'");
         return;
      end if;

      if Length (Name) = 0 then
         Name := To_Unbounded_String (Host.Login_Name);
      end if;

      if Length (Name) = 0 then
         declare
            User_Id : Natural;
         begin
            if Host.Current_User_Id (User_Id) then
               Name := To_Unbounded_String (FS.User_Name_For_Id (User_Id));
            end if;
         end;
      end if;

      if Length (Name) > 0 then
         Context.Put_Line (To_String (Name));
         Set_Success (Context, Result);
      else
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.unsupported", "unsupported platform capability");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run_Logname;

   procedure Run_Uname
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Show_System  : Boolean := False;
      Show_Node    : Boolean := False;
      Show_Release : Boolean := False;
      Show_Version : Boolean := False;
      Show_Machine : Boolean := False;

      procedure Add_Field (Output : in out Unbounded_String; Value : String) is
      begin
         if Length (Output) > 0 then
            Append (Output, " ");
         end if;
         Append (Output, (if Value = "" then "unknown" else Value));
      end Add_Field;

   begin
      for I in 1 .. Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (I);
         begin
            if Arg = "--" then
               if I < Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "extra operand '" & Context.Argument (I + 1) & "'");
                  return;
               end if;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when 'a' =>
                        Show_System := True;
                        Show_Node := True;
                        Show_Release := True;
                        Show_Version := True;
                        Show_Machine := True;
                     when 's' =>
                        Show_System := True;
                     when 'n' =>
                        Show_Node := True;
                     when 'r' =>
                        Show_Release := True;
                     when 'v' =>
                        Show_Version := True;
                     when 'm' =>
                        Show_Machine := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                        return;
                  end case;
               end loop;
            else
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "extra operand '" & Arg & "'");
               return;
            end if;
         end;
      end loop;

      if not (Show_System or else Show_Node or else Show_Release or else Show_Version or else Show_Machine) then
         Show_System := True;
      end if;

      declare
         Output : Unbounded_String;
      begin
         if Show_System then
            Add_Field (Output, Host.System_Name);
         end if;
         if Show_Node then
            Add_Field (Output, Host.Node_Name);
         end if;
         if Show_Release then
            Add_Field (Output, Host.Release_Name);
         end if;
         if Show_Version then
            Add_Field (Output, Host.Version_Name);
         end if;
         if Show_Machine then
            Add_Field (Output, Host.Machine_Name);
         end if;
         Context.Put_Line (To_String (Output));
      end;
      Set_Success (Context, Result);
   end Run_Uname;

   procedure Run_Id
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Show_User       : Boolean := False;
      Show_Group      : Boolean := False;
      Show_All_Groups : Boolean := False;
      Show_Name       : Boolean := False;
      User_Id         : Natural := 0;
      Group_Id        : Natural := 0;
      Groups          : Host.Group_Id_List (1 .. 256);
      Group_Last      : Natural := 0;

      function Name_Or_Id (Is_User : Boolean; Id : Natural) return String is
         Name : constant String := (if Is_User then FS.User_Name_For_Id (Id) else FS.Group_Name_For_Id (Id));
      begin
         if Show_Name and then Name /= "" then
            return Name;
         else
            return Trimmed_Image (Id);
         end if;
      end Name_Or_Id;

      function Decorated_Id (Is_User : Boolean; Id : Natural) return String is
         Name : constant String := (if Is_User then FS.User_Name_For_Id (Id) else FS.Group_Name_For_Id (Id));
      begin
         if Name = "" then
            return Trimmed_Image (Id);
         else
            return Trimmed_Image (Id) & "(" & Name & ")";
         end if;
      end Decorated_Id;

      procedure Append_Group (Id : Natural) is
      begin
         for Index in 1 .. Group_Last loop
            if Groups (Index) = Id then
               return;
            end if;
         end loop;
         if Group_Last < Groups'Length then
            Group_Last := Group_Last + 1;
            Groups (Group_Last) := Id;
         end if;
      end Append_Group;

      function Group_List (Named : Boolean; Decorated : Boolean) return String is
         Output : Unbounded_String;
      begin
         for Index in 1 .. Group_Last loop
            if Index > 1 then
               Append (Output, (if Decorated then "," else " "));
            end if;
            if Decorated then
               Append (Output, Decorated_Id (False, Groups (Index)));
            elsif Named then
               Append (Output, Name_Or_Id (False, Groups (Index)));
            else
               Append (Output, Trimmed_Image (Groups (Index)));
            end if;
         end loop;
         return To_String (Output);
      end Group_List;
   begin
      for I in 1 .. Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (I);
         begin
            if Arg = "--" then
               if I < Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "extra operand '" & Context.Argument (I + 1) & "'");
                  return;
               end if;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when 'u' =>
                        Show_User := True;
                     when 'g' =>
                        Show_Group := True;
                     when 'G' =>
                        Show_All_Groups := True;
                     when 'n' =>
                        Show_Name := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                        return;
                  end case;
               end loop;
            else
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "extra operand '" & Arg & "'");
               return;
            end if;
         end;
      end loop;

      if not Host.Current_User_Id (User_Id) then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.unsupported", "unsupported platform capability");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      if not Host.Current_Group_Id (Group_Id) then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.unsupported", "unsupported platform capability");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      Append_Group (Group_Id);
      declare
         Raw_Groups : Host.Group_Id_List (1 .. 256);
         Raw_Last   : Natural := 0;
      begin
         if Host.Current_Supplementary_Group_Ids (Raw_Groups, Raw_Last) then
            for Index in 1 .. Raw_Last loop
               Append_Group (Raw_Groups (Index));
            end loop;
         end if;
      end;

      if Show_User then
         Context.Put_Line (Name_Or_Id (True, User_Id));
      elsif Show_Group then
         Context.Put_Line (Name_Or_Id (False, Group_Id));
      elsif Show_All_Groups then
         Context.Put_Line (Group_List (Show_Name, False));
      else
         Context.Put_Line
           ("uid=" & Decorated_Id (True, User_Id) & " gid=" & Decorated_Id (False, Group_Id)
            & " groups=" & Group_List (False, True));
      end if;
      Set_Success (Context, Result);
   end Run_Id;

   procedure Run_Sleep
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Total : Duration := 0.0;

      function Parse_Duration (Text : String; Value : out Duration) return Boolean is
         Whole      : Long_Long_Integer := 0;
         Fraction   : Duration := 0.0;
         Scale      : Duration := 1.0;
         Seen_Digit : Boolean := False;
         Seen_Dot   : Boolean := False;
      begin
         if Text = "" or else Text (Text'First) = '-' then
            Value := 0.0;
            return False;
         end if;
         for Ch of Text loop
            if Ch in '0' .. '9' then
               Seen_Digit := True;
               if Seen_Dot then
                  Scale := Scale / 10.0;
                  Fraction := Fraction + Duration (Character'Pos (Ch) - Character'Pos ('0')) * Scale;
               else
                  Whole := Whole * 10 + Long_Long_Integer (Character'Pos (Ch) - Character'Pos ('0'));
                  if Whole > 31_622_400 then
                     Value := 0.0;
                     return False;
                  end if;
               end if;
            elsif Ch = '.' and then not Seen_Dot then
               Seen_Dot := True;
            else
               Value := 0.0;
               return False;
            end if;
         end loop;
         Value := Duration (Whole) + Fraction;
         return Seen_Digit;
      end Parse_Duration;
   begin
      if Context.Argument_Count = 0 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         declare
            Value : Duration;
         begin
            if not Parse_Duration (Context.Argument (I), Value) then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (I) & "'");
               return;
            end if;
            Total := Total + Value;
         end;
      end loop;

      delay Total;
      Set_Success (Context, Result);
   end Run_Sleep;

   procedure Run_Timeout
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First           : Positive := 1;
      Preserve_Status : Boolean := False;
      Timeout_Ms      : Natural := 0;
      Kill_After_Ms   : Natural := 0;
      Signal_Name     : Unbounded_String := To_Unbounded_String ("TERM");
      Timed_Out       : Boolean := False;
      Exit_Code       : Integer := 0;
      Arguments       : Posix_Tools.Arguments.Vector;

      function Duration_To_Milliseconds (Text : String; Milliseconds : out Natural) return Boolean is
         Whole      : Long_Long_Integer := 0;
         Fraction   : Long_Long_Float := 0.0;
         Scale      : Long_Long_Float := 1.0;
         Multiplier : Long_Long_Float := 1000.0;
         Seen_Digit : Boolean := False;
         Seen_Dot   : Boolean := False;
         Last_Index  : Natural := Text'Last;
      begin
         Milliseconds := 0;
         if Text = "" or else Text (Text'First) = '-' then
            return False;
         end if;

         if Text (Text'Last) = 's' then
            Multiplier := 1000.0;
            Last_Index := Text'Last - 1;
         elsif Text (Text'Last) = 'm' then
            Multiplier := 60_000.0;
            Last_Index := Text'Last - 1;
         elsif Text (Text'Last) = 'h' then
            Multiplier := 3_600_000.0;
            Last_Index := Text'Last - 1;
         elsif Text (Text'Last) = 'd' then
            Multiplier := 86_400_000.0;
            Last_Index := Text'Last - 1;
         end if;

         if Last_Index < Text'First then
            return False;
         end if;

         for I in Text'First .. Last_Index loop
            declare
               Ch : constant Character := Text (I);
            begin
               if Ch in '0' .. '9' then
                  Seen_Digit := True;
                  if Seen_Dot then
                     Scale := Scale / 10.0;
                     Fraction := Fraction + Long_Long_Float (Character'Pos (Ch) - Character'Pos ('0')) * Scale;
                  else
                     if Whole > Long_Long_Integer (Natural'Last / 10) then
                        return False;
                     end if;
                     Whole := Whole * 10 + Long_Long_Integer (Character'Pos (Ch) - Character'Pos ('0'));
                  end if;
               elsif Ch = '.' and then not Seen_Dot then
                  Seen_Dot := True;
               else
                  return False;
               end if;
            end;
         end loop;

         if not Seen_Digit then
            return False;
         end if;

         declare
            Value : constant Long_Long_Float := (Long_Long_Float (Whole) + Fraction) * Multiplier;
         begin
            if Value < 0.0 or else Value > Long_Long_Float (Natural'Last) then
               return False;
            end if;
            Milliseconds := Natural (Value);
            return True;
         end;
      end Duration_To_Milliseconds;

      procedure Require_Operand (Option : String) is
      begin
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '" & Option & "'");
      end Require_Operand;
   begin
      while First <= Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (First);
         begin
            if Arg = "--" then
               First := First + 1;
               exit;
            elsif Arg = "--preserve-status" then
               Preserve_Status := True;
               First := First + 1;
            elsif Arg = "--foreground" then
               First := First + 1;
            elsif Arg = "-s" or else Arg = "--signal" then
               if First = Context.Argument_Count then
                  Require_Operand (Arg);
                  return;
               end if;
               Signal_Name := To_Unbounded_String (Context.Argument (First + 1));
               First := First + 2;
            elsif Arg'Length > 10 and then Arg (Arg'First .. Arg'First + 9) = "--signal=" then
               Signal_Name := To_Unbounded_String (Arg (Arg'First + 10 .. Arg'Last));
               First := First + 1;
            elsif Arg = "-k" or else Arg = "--kill-after" then
               if First = Context.Argument_Count then
                  Require_Operand (Arg);
                  return;
               elsif not Duration_To_Milliseconds (Context.Argument (First + 1), Kill_After_Ms) then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid duration '" & Context.Argument (First + 1) & "'");
                  return;
               end if;
               First := First + 2;
            elsif Arg'Length > 13 and then Arg (Arg'First .. Arg'First + 12) = "--kill-after=" then
               if not Duration_To_Milliseconds (Arg (Arg'First + 13 .. Arg'Last), Kill_After_Ms) then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid duration '" & Arg (Arg'First + 13 .. Arg'Last) & "'");
                  return;
               end if;
               First := First + 1;
            elsif Arg'Length > 0 and then Arg (Arg'First) = '-' then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '" & Arg & "'");
               return;
            else
               exit;
            end if;
         end;
      end loop;

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      elsif not Duration_To_Milliseconds (Context.Argument (First), Timeout_Ms) then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "invalid duration '" & Context.Argument (First) & "'");
         return;
      elsif First = Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      if To_String (Signal_Name) = "" then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand ''");
         return;
      end if;

      for I in First + 2 .. Context.Argument_Count loop
         Arguments.Append (Context.Argument (I));
      end loop;

      if not Context.Execute_Utility_With_Timeout
        (Context.Argument (First + 1), Arguments, Timeout_Ms + Kill_After_Ms, Exit_Code, Timed_Out)
      then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Context.Argument (First + 1), "posix_tools.diagnostic.file.open_failed", "cannot open file");
         if Exit_Code in 126 .. 127 then
            Result.Status := Posix_Tools.Exit_Status.Code (Exit_Code);
         else
            Result.Status := Posix_Tools.Exit_Status.Utility_Cannot_Invoke;
         end if;
      elsif Timed_Out and then not Preserve_Status then
         Result.Status := Posix_Tools.Exit_Status.Code (124);
      elsif Exit_Code in Integer (Posix_Tools.Exit_Status.Code'First)
        .. Integer (Posix_Tools.Exit_Status.Code'Last)
      then
         Result.Status := Posix_Tools.Exit_Status.Code (Exit_Code);
      else
         Result.Status := Posix_Tools.Exit_Status.Internal_Failure;
      end if;

      if Context.Output_Failed then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run_Timeout;

   procedure Run_Tty
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Silent : Boolean := False;
   begin
      if Context.Argument_Count > 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "extra operand '" & Context.Argument (2) & "'");
         return;
      elsif Context.Argument_Count = 1 then
         if Context.Argument (1) = "-s" then
            Silent := True;
         else
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '" & Context.Argument (1) & "'");
            return;
         end if;
      end if;

      if Context.Standard_Input_Is_Terminal then
         if not Silent then
            Context.Put_Line (Context.Standard_Input_Terminal_Name);
         end if;
         Set_Success (Context, Result);
      else
         if not Silent then
            Context.Put_Line ("not a tty");
         end if;
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;

      if Context.Output_Failed then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run_Tty;

   procedure Run_Kill
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First  : Positive := 1;
      Chosen : Signals.Signal := Signals.Terminate_Signal;
      Ok     : Boolean := True;

      function Signal_From_Name (Text : String; Item : out Signals.Signal) return Boolean is
         function Upper (Ch : Character) return Character is
         begin
            if Ch in 'a' .. 'z' then
               return Character'Val (Character'Pos (Ch) - Character'Pos ('a') + Character'Pos ('A'));
            else
               return Ch;
            end if;
         end Upper;

         Clean : String (1 .. Text'Length);
      begin
         if Text = "" then
            Item := Signals.Terminate_Signal;
            return False;
         end if;
         for I in Text'Range loop
            Clean (I - Text'First + 1) := Upper (Text (I));
         end loop;
         declare
            Name   : constant String :=
              (if Clean'Length > 3 and then Clean (1 .. 3) = "SIG" then Clean (4 .. Clean'Last) else Clean);
            Number : Natural;
         begin
            if Parse_Natural_Text (Name, Number) then
               return Signals.From_Number (Integer (Number), Item);
            elsif Name = "HUP" then
               Item := Signals.Hangup;
            elsif Name = "INT" then
               Item := Signals.Interrupt;
            elsif Name = "QUIT" then
               Item := Signals.Quit;
            elsif Name = "KILL" then
               Item := Signals.Kill;
            elsif Name = "TERM" then
               Item := Signals.Terminate_Signal;
            elsif Name = "STOP" then
               Item := Signals.Stop;
            elsif Name = "TSTP" then
               Item := Signals.Terminal_Stop;
            elsif Name = "CONT" then
               Item := Signals.Continue;
            elsif Name = "PIPE" then
               Item := Signals.Pipe;
            else
               Item := Signals.Terminate_Signal;
               return False;
            end if;
            return Signals.Is_Supported (Item);
         end;
      end Signal_From_Name;
   begin
      if Context.Argument_Count = 0 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      if Context.Argument (1) = "-l" then
         for Item in Signals.Signal loop
            if Signals.Is_Supported (Item) then
               Context.Put_Line (Signals.Name (Item));
            end if;
         end loop;
         Set_Success (Context, Result);
         return;
      elsif Context.Argument_Count >= 2 and then Context.Argument (1) = "-s" then
         if not Signal_From_Name (Context.Argument (2), Chosen) then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid operand '" & Context.Argument (2) & "'");
            return;
         end if;
         First := 3;
      elsif Context.Argument (1)'Length > 1 and then Context.Argument (1) (1) = '-' then
         if not Signal_From_Name (Context.Argument (1) (2 .. Context.Argument (1)'Last), Chosen) then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid operand '" & Context.Argument (1) & "'");
            return;
         end if;
         First := 2;
      end if;

      if Context.Argument_Count < First then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for I in First .. Context.Argument_Count loop
         declare
            Pid : Natural;
         begin
            if not Parse_Natural_Text (Context.Argument (I), Pid)
              or else not Signals.Send_To_Process (Integer (Pid), Chosen)
            then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Context.Argument (I), "posix_tools.diagnostic.file.open_failed", "cannot open file");
            end if;
         end;
      end loop;

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Kill;

   procedure Run_Chmod
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First            : Positive := 1;
      Recursive        : Boolean := False;
      Mode_Bits        : Natural := 0;
      Mode_Text        : Unbounded_String;
      Mode_Is_Symbolic : Boolean := False;
      Ok               : Boolean := True;

      type Permission_Bit_List is array (Positive range <>) of Natural;
      Permission_Bits : constant Permission_Bit_List :=
        [8#4000#, 8#2000#, 8#1000#, 8#400#, 8#200#, 8#100#, 8#040#, 8#020#, 8#010#, 8#004#, 8#002#, 8#001#];

      function Has_Bit (Value : Natural; Bit : Natural) return Boolean is
      begin
         return (Value / Bit) mod 2 = 1;
      end Has_Bit;

      procedure Set_Bit (Value : in out Natural; Bit : Natural) is
      begin
         if not Has_Bit (Value, Bit) then
            Value := Value + Bit;
         end if;
      end Set_Bit;

      procedure Clear_Bit (Value : in out Natural; Bit : Natural) is
      begin
         if Has_Bit (Value, Bit) then
            Value := Value - Bit;
         end if;
      end Clear_Bit;

      procedure Clear_Mask (Value : in out Natural; Mask : Natural) is
      begin
         for Bit of Permission_Bits loop
            if Has_Bit (Mask, Bit) then
               Clear_Bit (Value, Bit);
            end if;
         end loop;
      end Clear_Mask;

      function Parse_Octal_Mode (Text : String; Value : out Natural) return Boolean is
      begin
         Value := 0;
         if Text = "" or else Text'Length > 4 then
            return False;
         end if;
         for Ch of Text loop
            if Ch not in '0' .. '7' then
               Value := 0;
               return False;
            end if;
            Value := Value * 8 + Character'Pos (Ch) - Character'Pos ('0');
         end loop;
         return True;
      end Parse_Octal_Mode;

      function Apply_Symbolic_Mode (Mode : String; Base : Natural; Valid : out Boolean) return Natural is
         Result_Mode : Natural := Base mod 8#10000#;
         Index       : Positive := Mode'First;
      begin
         Valid := Mode'Length > 0;
         while Valid and then Index <= Mode'Last loop
            declare
               Who_Mask : Natural := 0;
               Perms    : Natural := 0;
               Op       : Character := Character'Val (0);
            begin
               while Index <= Mode'Last and then Mode (Index) in 'a' | 'u' | 'g' | 'o' loop
                  case Mode (Index) is
                     when 'a' =>
                        Who_Mask := 8#7777#;
                     when 'u' =>
                        Who_Mask := Who_Mask + (if Has_Bit (Who_Mask, 8#400#) then 0 else 8#4700#);
                     when 'g' =>
                        Who_Mask := Who_Mask + (if Has_Bit (Who_Mask, 8#040#) then 0 else 8#2070#);
                     when 'o' =>
                        Who_Mask := Who_Mask + (if Has_Bit (Who_Mask, 8#004#) then 0 else 8#1007#);
                     when others =>
                        null;
                  end case;
                  Index := Index + 1;
               end loop;
               if Who_Mask = 0 then
                  Who_Mask := 8#7777#;
               end if;
               if Index > Mode'Last or else Mode (Index) not in '+' | '-' | '=' then
                  Valid := False;
                  return Result_Mode;
               end if;
               Op := Mode (Index);
               Index := Index + 1;
               if (Index > Mode'Last or else Mode (Index) = ',') and then Op /= '=' then
                  Valid := False;
                  return Result_Mode;
               end if;
               while Index <= Mode'Last and then Mode (Index) /= ',' loop
                  case Mode (Index) is
                     when 'r' =>
                        if Has_Bit (Who_Mask, 8#400#) then
                           Set_Bit (Perms, 8#400#);
                        end if;
                        if Has_Bit (Who_Mask, 8#040#) then
                           Set_Bit (Perms, 8#040#);
                        end if;
                        if Has_Bit (Who_Mask, 8#004#) then
                           Set_Bit (Perms, 8#004#);
                        end if;
                     when 'w' =>
                        if Has_Bit (Who_Mask, 8#200#) then
                           Set_Bit (Perms, 8#200#);
                        end if;
                        if Has_Bit (Who_Mask, 8#020#) then
                           Set_Bit (Perms, 8#020#);
                        end if;
                        if Has_Bit (Who_Mask, 8#002#) then
                           Set_Bit (Perms, 8#002#);
                        end if;
                     when 'x' | 'X' =>
                        if Has_Bit (Who_Mask, 8#100#) then
                           Set_Bit (Perms, 8#100#);
                        end if;
                        if Has_Bit (Who_Mask, 8#010#) then
                           Set_Bit (Perms, 8#010#);
                        end if;
                        if Has_Bit (Who_Mask, 8#001#) then
                           Set_Bit (Perms, 8#001#);
                        end if;
                     when 's' =>
                        if Has_Bit (Who_Mask, 8#4000#) then
                           Set_Bit (Perms, 8#4000#);
                        end if;
                        if Has_Bit (Who_Mask, 8#2000#) then
                           Set_Bit (Perms, 8#2000#);
                        end if;
                     when 't' =>
                        if Has_Bit (Who_Mask, 8#1000#) then
                           Set_Bit (Perms, 8#1000#);
                        end if;
                     when 'u' | 'g' | 'o' =>
                        declare
                           Source_Read  : constant Boolean :=
                             Has_Bit
                               (Result_Mode,
                                (case Mode (Index) is
                                    when 'u' => 8#400#,
                                    when 'g' => 8#040#,
                                    when others => 8#004#));
                           Source_Write : constant Boolean :=
                             Has_Bit
                               (Result_Mode,
                                (case Mode (Index) is
                                    when 'u' => 8#200#,
                                    when 'g' => 8#020#,
                                    when others => 8#002#));
                           Source_Exec  : constant Boolean :=
                             Has_Bit
                               (Result_Mode,
                                (case Mode (Index) is
                                    when 'u' => 8#100#,
                                    when 'g' => 8#010#,
                                    when others => 8#001#));
                        begin
                           if Source_Read then
                              if Has_Bit (Who_Mask, 8#400#) then
                                 Set_Bit (Perms, 8#400#);
                              end if;
                              if Has_Bit (Who_Mask, 8#040#) then
                                 Set_Bit (Perms, 8#040#);
                              end if;
                              if Has_Bit (Who_Mask, 8#004#) then
                                 Set_Bit (Perms, 8#004#);
                              end if;
                           end if;
                           if Source_Write then
                              if Has_Bit (Who_Mask, 8#200#) then
                                 Set_Bit (Perms, 8#200#);
                              end if;
                              if Has_Bit (Who_Mask, 8#020#) then
                                 Set_Bit (Perms, 8#020#);
                              end if;
                              if Has_Bit (Who_Mask, 8#002#) then
                                 Set_Bit (Perms, 8#002#);
                              end if;
                           end if;
                           if Source_Exec then
                              if Has_Bit (Who_Mask, 8#100#) then
                                 Set_Bit (Perms, 8#100#);
                              end if;
                              if Has_Bit (Who_Mask, 8#010#) then
                                 Set_Bit (Perms, 8#010#);
                              end if;
                              if Has_Bit (Who_Mask, 8#001#) then
                                 Set_Bit (Perms, 8#001#);
                              end if;
                           end if;
                        end;
                     when others =>
                        Valid := False;
                        return Result_Mode;
                  end case;
                  Index := Index + 1;
               end loop;
               case Op is
                  when '+' =>
                     for Bit of Permission_Bits loop
                        if Has_Bit (Perms, Bit) then
                           Set_Bit (Result_Mode, Bit);
                        end if;
                     end loop;
                  when '-' =>
                     Clear_Mask (Result_Mode, Perms);
                  when '=' =>
                     Clear_Mask (Result_Mode, Who_Mask);
                     for Bit of Permission_Bits loop
                        if Has_Bit (Perms, Bit) then
                           Set_Bit (Result_Mode, Bit);
                        end if;
                     end loop;
                  when others =>
                     Valid := False;
                     return Result_Mode;
               end case;
               if Index <= Mode'Last then
                  if Mode (Index) /= ',' or else Index = Mode'Last then
                     Valid := False;
                     return Result_Mode;
                  end if;
                  Index := Index + 1;
               end if;
            end;
         end loop;
         return Result_Mode;
      end Apply_Symbolic_Mode;

      function Parse_Mode (Text : String) return Boolean is
         Valid   : Boolean;
         Ignored : Natural;
      begin
         if Parse_Octal_Mode (Text, Mode_Bits) then
            Mode_Is_Symbolic := False;
            Mode_Text := Null_Unbounded_String;
            return True;
         end if;

         Ignored := Apply_Symbolic_Mode (Text, 0, Valid);
         if Valid then
            Mode_Is_Symbolic := True;
            Mode_Text := To_Unbounded_String (Text);
            Mode_Bits := 0;
         end if;
         return Valid;
      end Parse_Mode;

      function Selected_Mode_For (Path : String; Valid : out Boolean) return Natural is
         Available : Boolean := False;
         Base      : Natural := 0;
      begin
         if not Mode_Is_Symbolic then
            Valid := True;
            return Mode_Bits;
         end if;

         Base := FS.File_Permission_Bits (Path, Available) mod 8#10000#;
         if not Available then
            Valid := False;
            return 0;
         end if;
         return Apply_Symbolic_Mode (To_String (Mode_Text), Base, Valid);
      end Selected_Mode_For;

      procedure Apply_One (Path : String);

      procedure Apply_Children (Path : String) is
         procedure Visit (Name : String; Full_Name : String; Stop : in out Boolean) is
            pragma Unreferenced (Name, Stop);
         begin
            Apply_One (Full_Name);
         end Visit;

         procedure Each is new FS.For_Each_Directory_Entry (Visit);
         Listed : Boolean;
      begin
         if FS.Kind (Path) = FS.Directory then
            Each (Path, Listed);
            Ok := Ok and Listed;
         end if;
      end Apply_Children;

      procedure Apply_One (Path : String) is
         Desired_Mode : Natural;
         Mode_Ok      : Boolean;
      begin
         if Recursive then
            Apply_Children (Path);
         end if;
         Desired_Mode := Selected_Mode_For (Path, Mode_Ok);
         if not Mode_Ok or else not FS.Set_Permissions (Path, Desired_Mode) then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end if;
      exception
         when others =>
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
      end Apply_One;
   begin
      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First) = "-R" then
            Recursive := True;
            First := First + 1;
         else
            exit;
         end if;
      end loop;

      if Context.Argument_Count < First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      elsif not Parse_Mode (Context.Argument (First)) then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "invalid operand '" & Context.Argument (First) & "'");
         return;
      end if;

      for I in First + 1 .. Context.Argument_Count loop
         Apply_One (Context.Argument (I));
      end loop;

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Chmod;

   procedure Run_Chown
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First     : Positive := 1;
      Recursive : Boolean := False;
      Owner     : Natural := 0;
      Group     : Natural := 0;
      Owner_Set : Boolean := False;
      Group_Set : Boolean := False;
      Ok        : Boolean := True;

      function Resolve_User (Text : String; Value : out Natural) return Boolean is
         Found : Boolean;
      begin
         if Parse_Natural_Text (Text, Value) then
            return True;
         end if;
         Value := FS.User_Id_For_Name (Text, Found);
         return Found;
      end Resolve_User;

      function Resolve_Group (Text : String; Value : out Natural) return Boolean is
         Found : Boolean;
      begin
         if Parse_Natural_Text (Text, Value) then
            return True;
         end if;
         Value := FS.Group_Id_For_Name (Text, Found);
         return Found;
      end Resolve_Group;

      procedure Parse_Owner_Group (Spec : String; Valid : out Boolean) is
         Split : Natural := 0;
      begin
         for I in Spec'Range loop
            if Spec (I) = ':' then
               Split := I;
               exit;
            end if;
         end loop;

         if Split = 0 then
            Valid := Resolve_User (Spec, Owner);
            Owner_Set := Valid;
         else
            if Split > Spec'First then
               Valid := Resolve_User (Spec (Spec'First .. Split - 1), Owner);
               Owner_Set := Valid;
            else
               Valid := True;
            end if;
            if Valid and then Split < Spec'Last then
               Valid := Resolve_Group (Spec (Split + 1 .. Spec'Last), Group);
               Group_Set := Valid;
            end if;
         end if;
      end Parse_Owner_Group;

      procedure Apply_One (Path : String);

      procedure Apply_Children (Path : String) is
         procedure Visit (Name : String; Full_Name : String; Stop : in out Boolean) is
            pragma Unreferenced (Name, Stop);
         begin
            Apply_One (Full_Name);
         end Visit;

         procedure Each is new FS.For_Each_Directory_Entry (Visit);
         Listed : Boolean;
      begin
         if FS.Kind (Path) = FS.Directory then
            Each (Path, Listed);
            Ok := Ok and Listed;
         end if;
      end Apply_Children;

      procedure Apply_One (Path : String) is
         Current_User  : Natural;
         Current_Group : Natural;
         Available     : Boolean;
      begin
         if Recursive then
            Apply_Children (Path);
         end if;
         FS.File_Ownership (Path, Current_User, Current_Group, Available);
         if not Available then
            Current_User := Owner;
            Current_Group := Group;
         end if;
         if not FS.Set_Ownership
           (Path,
            (if Owner_Set then Owner else Current_User),
            (if Group_Set then Group else Current_Group))
         then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end if;
      exception
         when others =>
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
      end Apply_One;
   begin
      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First) = "-R" then
            Recursive := True;
            First := First + 1;
         else
            exit;
         end if;
      end loop;

      if Context.Argument_Count < First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      declare
         Valid : Boolean;
      begin
         Parse_Owner_Group (Context.Argument (First), Valid);
         if not Valid or else not (Owner_Set or else Group_Set) then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid operand '" & Context.Argument (First) & "'");
            return;
         end if;
      end;

      for I in First + 1 .. Context.Argument_Count loop
         Apply_One (Context.Argument (I));
      end loop;

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Chown;

   procedure Run_Chgrp
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First     : Positive := 1;
      Recursive : Boolean := False;
      Group     : Natural := 0;
      Ok        : Boolean := True;

      function Resolve_Group (Text : String; Value : out Natural) return Boolean is
         Found : Boolean;
      begin
         if Parse_Natural_Text (Text, Value) then
            return True;
         end if;
         Value := FS.Group_Id_For_Name (Text, Found);
         return Found;
      end Resolve_Group;

      procedure Apply_One (Path : String);

      procedure Apply_Children (Path : String) is
         procedure Visit (Name : String; Full_Name : String; Stop : in out Boolean) is
            pragma Unreferenced (Name, Stop);
         begin
            Apply_One (Full_Name);
         end Visit;

         procedure Each is new FS.For_Each_Directory_Entry (Visit);
         Listed : Boolean;
      begin
         if FS.Kind (Path) = FS.Directory then
            Each (Path, Listed);
            Ok := Ok and Listed;
         end if;
      end Apply_Children;

      procedure Apply_One (Path : String) is
         User      : Natural;
         Old_Group : Natural;
         Available : Boolean;
      begin
         if Recursive then
            Apply_Children (Path);
         end if;
         FS.File_Ownership (Path, User, Old_Group, Available);
         if not Available then
            User := 0;
         end if;
         if not FS.Set_Ownership (Path, User, Group) then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end if;
      exception
         when others =>
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
      end Apply_One;
   begin
      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First) = "-R" then
            Recursive := True;
            First := First + 1;
         else
            exit;
         end if;
      end loop;

      if Context.Argument_Count < First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      elsif not Resolve_Group (Context.Argument (First), Group) then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "invalid operand '" & Context.Argument (First) & "'");
         return;
      end if;

      for I in First + 1 .. Context.Argument_Count loop
         Apply_One (Context.Argument (I));
      end loop;

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Chgrp;

   procedure Run_Ln
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First : Positive := 1;
      Force : Boolean := False;
      Symbolic : Boolean := False;
      Verbose : Boolean := False;

      function Is_Directory (Path : String) return Boolean is
      begin
         return FS.Kind (Path) = FS.Directory;
      exception
         when others =>
            return False;
      end Is_Directory;

      function Target_Path (Source : String; Target : String; Target_Is_Directory : Boolean) return String is
      begin
         if Target_Is_Directory then
            return FS.Join (Target, Posix_Tools.Paths.Basename (Source));
         else
            return Target;
         end if;
      end Target_Path;

      function Remove_Existing_Target (Path : String) return Boolean is
      begin
         if FS.Is_Link (Path) then
            return FS.Delete_Link (Path);
         elsif FS.Exists (Path) then
            if FS.Kind (Path) = FS.Directory then
               return False;
            end if;
            FS.Delete_File (Path);
         end if;
         return True;
      exception
         when others =>
            return False;
      end Remove_Existing_Target;

      procedure Create_Link (Source : String; Target : String; Ok : in out Boolean; Created_One : out Boolean) is
         Created : Boolean;
      begin
         Created_One := False;
         if Force and then not Remove_Existing_Target (Target) then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            return;
         end if;

         Created :=
           (if Symbolic
            then FS.Create_Link (Source, Target)
            else FS.Create_Hard_Link (Source, Target));
         if not Created then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         else
            Created_One := True;
         end if;
      exception
         when others =>
            Created_One := False;
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
      end Create_Link;
   begin
      while First <= Context.Argument_Count
        and then Context.Argument (First)'Length > 1
        and then Context.Argument (First) (1) = '-'
      loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         end if;

         for Ch of Context.Argument (First) (2 .. Context.Argument (First)'Last) loop
            case Ch is
               when 'f' =>
                  Force := True;
               when 's' =>
                  Symbolic := True;
               when 'v' =>
                  Verbose := True;
               when others =>
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                  return;
            end case;
         end loop;
         First := First + 1;
      end loop;
      if First > Context.Argument_Count or else Context.Argument_Count - First + 1 < 2 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      declare
         Operand_Count : constant Natural := Context.Argument_Count - First + 1;
         Target        : constant String := Context.Argument (Context.Argument_Count);
         Target_Is_Dir : constant Boolean := Is_Directory (Target);
         Ok            : Boolean := True;
      begin
         if Operand_Count > 2 and then not Target_Is_Dir then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         for I in First .. Context.Argument_Count - 1 loop
            declare
               Destination : constant String := Target_Path (Context.Argument (I), Target, Target_Is_Dir);
               Created_One : Boolean;
            begin
               Create_Link (Context.Argument (I), Destination, Ok, Created_One);
               if Verbose and then Created_One then
                  Context.Put_Line ("'" & Context.Argument (I) & "' -> '" & Destination & "'");
               end if;
            end;
         end loop;

         Result.Status :=
           (if Ok and then not Context.Output_Failed
            then Posix_Tools.Exit_Status.Success
            else Posix_Tools.Exit_Status.Operational_Failure);
      end;
   exception
      when others =>
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Context.Argument (Context.Argument_Count),
            "posix_tools.diagnostic.file.open_failed", "cannot open file");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
   end Run_Ln;

   procedure Run_Mkdir
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Parents : Boolean := False;
      Ok      : Boolean := True;
      First   : Positive := 1;
      Has_Mode : Boolean := False;
      Mode_Bits : Natural := 0;
      Mode_Text : Unbounded_String;
      Mode_Is_Symbolic : Boolean := False;
      type Permission_Bit_List is array (Positive range <>) of Natural;
      Permission_Bits : constant Permission_Bit_List :=
        [8#4000#, 8#2000#, 8#1000#, 8#400#, 8#200#, 8#100#, 8#040#, 8#020#, 8#010#, 8#004#, 8#002#, 8#001#];

      function Has_Bit (Value : Natural; Bit : Natural) return Boolean is
      begin
         return (Value / Bit) mod 2 = 1;
      end Has_Bit;

      procedure Set_Bit (Value : in out Natural; Bit : Natural) is
      begin
         if not Has_Bit (Value, Bit) then
            Value := Value + Bit;
         end if;
      end Set_Bit;

      procedure Clear_Bit (Value : in out Natural; Bit : Natural) is
      begin
         if Has_Bit (Value, Bit) then
            Value := Value - Bit;
         end if;
      end Clear_Bit;

      procedure Clear_Mask (Value : in out Natural; Mask : Natural) is
      begin
         for Bit of Permission_Bits loop
            if Has_Bit (Mask, Bit) then
               Clear_Bit (Value, Bit);
            end if;
         end loop;
      end Clear_Mask;

      function Octal_Mode_Value (Mode : String) return Natural is
         Value : Natural := 0;
      begin
         for Ch of Mode loop
            Value := Value * 8 + Character'Pos (Ch) - Character'Pos ('0');
         end loop;
         return Value;
      end Octal_Mode_Value;

      function Valid_Octal_Mode (Mode : String) return Boolean is
      begin
         return Mode'Length > 0
           and then Mode'Length <= 4
           and then (for all Ch of Mode => Ch in '0' .. '7');
      end Valid_Octal_Mode;

      function Apply_Symbolic_Mode (Mode : String; Base : Natural; Valid : out Boolean) return Natural is
         Result_Mode : Natural := Base mod 8#1000#;
         Index       : Positive := Mode'First;
      begin
         Valid := Mode'Length > 0;
         while Valid and then Index <= Mode'Last loop
            declare
               Who_Mask : Natural := 0;
               Perms    : Natural := 0;
               Op       : Character := Character'Val (0);
            begin
               while Index <= Mode'Last and then Mode (Index) in 'a' | 'u' | 'g' | 'o' loop
                  case Mode (Index) is
                     when 'a' =>
                        Who_Mask := 8#7777#;
                     when 'u' =>
                        Who_Mask := Who_Mask + (if Has_Bit (Who_Mask, 8#400#) then 0 else 8#4700#);
                     when 'g' =>
                        Who_Mask := Who_Mask + (if Has_Bit (Who_Mask, 8#040#) then 0 else 8#2070#);
                     when 'o' =>
                        Who_Mask := Who_Mask + (if Has_Bit (Who_Mask, 8#004#) then 0 else 8#1007#);
                     when others =>
                        null;
                  end case;
                  Index := Index + 1;
               end loop;
               if Who_Mask = 0 then
                  Who_Mask := 8#7777#;
               end if;
               if Index > Mode'Last or else Mode (Index) not in '+' | '-' | '=' then
                  Valid := False;
                  return Result_Mode;
               end if;
               Op := Mode (Index);
               Index := Index + 1;
               if (Index > Mode'Last or else Mode (Index) = ',') and then Op /= '=' then
                  Valid := False;
                  return Result_Mode;
               end if;
               while Index <= Mode'Last and then Mode (Index) /= ',' loop
                  case Mode (Index) is
                     when 'r' =>
                        if Has_Bit (Who_Mask, 8#400#) then
                           Set_Bit (Perms, 8#400#);
                        end if;
                        if Has_Bit (Who_Mask, 8#040#) then
                           Set_Bit (Perms, 8#040#);
                        end if;
                        if Has_Bit (Who_Mask, 8#004#) then
                           Set_Bit (Perms, 8#004#);
                        end if;
                     when 'w' =>
                        if Has_Bit (Who_Mask, 8#200#) then
                           Set_Bit (Perms, 8#200#);
                        end if;
                        if Has_Bit (Who_Mask, 8#020#) then
                           Set_Bit (Perms, 8#020#);
                        end if;
                        if Has_Bit (Who_Mask, 8#002#) then
                           Set_Bit (Perms, 8#002#);
                        end if;
                     when 'x' | 'X' =>
                        if Has_Bit (Who_Mask, 8#100#) then
                           Set_Bit (Perms, 8#100#);
                        end if;
                        if Has_Bit (Who_Mask, 8#010#) then
                           Set_Bit (Perms, 8#010#);
                        end if;
                        if Has_Bit (Who_Mask, 8#001#) then
                           Set_Bit (Perms, 8#001#);
                        end if;
                     when 's' =>
                        if Has_Bit (Who_Mask, 8#4000#) then
                           Set_Bit (Perms, 8#4000#);
                        end if;
                        if Has_Bit (Who_Mask, 8#2000#) then
                           Set_Bit (Perms, 8#2000#);
                        end if;
                     when 't' =>
                        if Has_Bit (Who_Mask, 8#1000#) then
                           Set_Bit (Perms, 8#1000#);
                        end if;
                     when 'u' | 'g' | 'o' =>
                        declare
                           Source_Read  : constant Boolean :=
                             Has_Bit (Result_Mode,
                                      (case Mode (Index) is
                                          when 'u' => 8#400#,
                                          when 'g' => 8#040#,
                                          when others => 8#004#));
                           Source_Write : constant Boolean :=
                             Has_Bit (Result_Mode,
                                      (case Mode (Index) is
                                          when 'u' => 8#200#,
                                          when 'g' => 8#020#,
                                          when others => 8#002#));
                           Source_Exec  : constant Boolean :=
                             Has_Bit (Result_Mode,
                                      (case Mode (Index) is
                                          when 'u' => 8#100#,
                                          when 'g' => 8#010#,
                                          when others => 8#001#));
                        begin
                           if Source_Read then
                              if Has_Bit (Who_Mask, 8#400#) then
                                 Set_Bit (Perms, 8#400#);
                              end if;
                              if Has_Bit (Who_Mask, 8#040#) then
                                 Set_Bit (Perms, 8#040#);
                              end if;
                              if Has_Bit (Who_Mask, 8#004#) then
                                 Set_Bit (Perms, 8#004#);
                              end if;
                           end if;
                           if Source_Write then
                              if Has_Bit (Who_Mask, 8#200#) then
                                 Set_Bit (Perms, 8#200#);
                              end if;
                              if Has_Bit (Who_Mask, 8#020#) then
                                 Set_Bit (Perms, 8#020#);
                              end if;
                              if Has_Bit (Who_Mask, 8#002#) then
                                 Set_Bit (Perms, 8#002#);
                              end if;
                           end if;
                           if Source_Exec then
                              if Has_Bit (Who_Mask, 8#100#) then
                                 Set_Bit (Perms, 8#100#);
                              end if;
                              if Has_Bit (Who_Mask, 8#010#) then
                                 Set_Bit (Perms, 8#010#);
                              end if;
                              if Has_Bit (Who_Mask, 8#001#) then
                                 Set_Bit (Perms, 8#001#);
                              end if;
                           end if;
                        end;
                     when others =>
                        Valid := False;
                        return Result_Mode;
                  end case;
                  Index := Index + 1;
               end loop;
               case Op is
                  when '+' =>
                     for Bit of Permission_Bits loop
                        if Has_Bit (Perms, Bit) then
                           Set_Bit (Result_Mode, Bit);
                        end if;
                     end loop;
                  when '-' =>
                     Clear_Mask (Result_Mode, Perms);
                  when '=' =>
                     Clear_Mask (Result_Mode, Who_Mask);
                     for Bit of Permission_Bits loop
                        if Has_Bit (Perms, Bit) then
                           Set_Bit (Result_Mode, Bit);
                        end if;
                     end loop;
                  when others =>
                     Valid := False;
                     return Result_Mode;
               end case;
               if Index <= Mode'Last then
                  if Mode (Index) /= ',' or else Index = Mode'Last then
                     Valid := False;
                     return Result_Mode;
                  end if;
                  Index := Index + 1;
               end if;
            end;
         end loop;
         return Result_Mode;
      end Apply_Symbolic_Mode;

      function Valid_Symbolic_Mode (Mode : String) return Boolean is
         Valid : Boolean;
         Ignored : Natural;
      begin
         Ignored := Apply_Symbolic_Mode (Mode, 0, Valid);
         return Valid;
      end Valid_Symbolic_Mode;

      procedure Record_Mode (Mode : String; Accepted : out Boolean) is
      begin
         Accepted := True;
         if Valid_Octal_Mode (Mode) then
            Has_Mode := True;
            Mode_Is_Symbolic := False;
            Mode_Text := Null_Unbounded_String;
            Mode_Bits := Octal_Mode_Value (Mode);
         elsif Valid_Symbolic_Mode (Mode) then
            Has_Mode := True;
            Mode_Is_Symbolic := True;
            Mode_Text := To_Unbounded_String (Mode);
            Mode_Bits := 0;
         else
            Accepted := False;
         end if;
      end Record_Mode;

      function Selected_Mode_For (Path : String; Valid : out Boolean) return Natural is
         Available : Boolean := False;
         Base      : Natural := 0;
      begin
         if not Mode_Is_Symbolic then
            Valid := True;
            return Mode_Bits;
         end if;
         Base := FS.File_Permission_Bits (Path, Available) mod 8#1000#;
         if not Available then
            Base := 0;
         end if;
         return Apply_Symbolic_Mode (To_String (Mode_Text), Base, Valid);
      end Selected_Mode_For;
   begin
      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First)'Length > 1
           and then Context.Argument (First) (Context.Argument (First)'First) = '-'
         then
            declare
               Arg      : constant String := Context.Argument (First);
               Position : Positive := Arg'First + 1;
            begin
               while Position <= Arg'Last loop
                  case Arg (Position) is
                     when 'p' =>
                        Parents := True;
                        Position := Position + 1;
                     when 'm' =>
                        if Position < Arg'Last then
                           declare
                              Accepted : Boolean;
                           begin
                              Record_Mode (Arg (Position + 1 .. Arg'Last), Accepted);
                              if not Accepted then
                                 Posix_Tools.Commands.Helpers.Usage_Error
                                   (Context, Result, "invalid mode '" & Arg & "'");
                                 return;
                              end if;
                           end;
                           Position := Arg'Last + 1;
                        else
                           if First = Context.Argument_Count then
                              Posix_Tools.Commands.Helpers.Usage_Error
                                (Context, Result, "missing option argument '-m'");
                              return;
                           end if;
                           declare
                              Accepted : Boolean;
                           begin
                              Record_Mode (Context.Argument (First + 1), Accepted);
                              if not Accepted then
                                 Posix_Tools.Commands.Helpers.Usage_Error
                                   (Context, Result, "invalid mode '" & Context.Argument (First + 1) & "'");
                                 return;
                              end if;
                           end;
                           First := First + 1;
                           Position := Arg'Last + 1;
                        end if;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error
                          (Context, Result, "unknown option '-" & Arg (Position) & "'");
                        return;
                  end case;
               end loop;
            end;
            First := First + 1;
         else
            exit;
         end if;
      end loop;
      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;
      for I in First .. Context.Argument_Count loop
         begin
            if Parents then
               FS.Create_Path (Context.Argument (I));
            else
               FS.Create_Directory (Context.Argument (I));
            end if;
            if Has_Mode then
               declare
                  Mode_Ok : Boolean;
                  Desired_Mode : constant Natural := Selected_Mode_For (Context.Argument (I), Mode_Ok);
               begin
                  if not Mode_Ok or else not FS.Set_Permissions (Context.Argument (I), Desired_Mode) then
                     Ok := False;
                     Posix_Tools.Commands.Helpers.Subject_Operational_Error
                       (Context, Context.Argument (I), "posix_tools.diagnostic.file.open_failed", "cannot open file");
                  end if;
               end;
            end if;
         exception
            when others =>
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Context.Argument (I), "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end;
      end loop;
      Result.Status :=
        (if Ok then Posix_Tools.Exit_Status.Success else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Mkdir;

   procedure Run_Mv
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Operands : String_Vectors.Vector;
      Ok       : Boolean := True;
      Verbose  : Boolean := False;
      Force    : Boolean := False;
      Interactive : Boolean := False;
      Parsing_Operands : Boolean := False;

      function Confirm_Overwrite (Path : String) return Boolean is
         Buffer : Ada.Streams.Stream_Element_Array (1 .. 1);
         Last   : Ada.Streams.Stream_Element_Offset;
      begin
         if not Interactive or else Force or else not FS.Exists (Path) then
            return True;
         end if;

         Context.Put_Error_Line ("mv: overwrite '" & Path & "'?");
         if not Context.Try_Read_Standard_Input (Buffer, Last) or else Last < Buffer'First then
            return False;
         end if;

         return Character'Val (Buffer (Buffer'First)) in 'y' | 'Y';
      end Confirm_Overwrite;

      procedure Copy_Then_Remove (Source, Destination : String; Moved : out Boolean) is
         Copied : Boolean;
      begin
         Moved := False;
         Copy_Path (Context, Source, Destination, True, True, False, Copied);
         if not Copied then
            return;
         end if;

         begin
            if FS.Kind (Source) = FS.Directory
            then
               FS.Delete_Tree (Source);
            else
               FS.Delete_File (Source);
            end if;
            Moved := True;
         exception
            when others =>
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Source, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end;
      end Copy_Then_Remove;
   begin
      for I in 1 .. Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (I);
         begin
            if not Parsing_Operands and then Arg = "--" then
               for J in I + 1 .. Context.Argument_Count loop
                  Operands.Append (Context.Argument (J));
               end loop;
               exit;
            elsif not Parsing_Operands and then Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when 'f' =>
                        Force := True;
                        Interactive := False;
                     when 'i' =>
                        Force := False;
                        Interactive := True;
                     when 'v' =>
                        Verbose := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                        return;
                  end case;
               end loop;
            else
               Operands.Append (Arg);
               Parsing_Operands := True;
            end if;
         end;
      end loop;

      if Operands.Length < 2 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      declare
         Count  : constant Natural := Natural (Operands.Length);
         Target : constant String := Operands.Element (Count);
      begin
         if Count > 2
           and then FS.Kind (Target) /= FS.Directory
         then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         for I in 1 .. Count - 1 loop
            declare
               Destination : constant String :=
                 (if Count = 2 then Target else Join_Path (Target, Simple_Name (Operands.Element (I))));
               Overwrite_Accepted : constant Boolean := Confirm_Overwrite (Destination);
            begin
               if Overwrite_Accepted then
                  FS.Rename (Operands.Element (I), Destination);
                  if Verbose then
                     Context.Put_Line ("'" & Operands.Element (I) & "' -> '" & Destination & "'");
                  end if;
               end if;
            exception
               when others =>
                  declare
                     Moved : Boolean;
                  begin
                     if not Overwrite_Accepted then
                        Moved := True;
                     else
                        Copy_Then_Remove (Operands.Element (I), Destination, Moved);
                     end if;

                     if not Moved then
                        Ok := False;
                        Posix_Tools.Commands.Helpers.Subject_Operational_Error
                          (Context,
                           Operands.Element (I),
                           "posix_tools.diagnostic.file.open_failed",
                           "cannot open file");
                     elsif Verbose then
                        Context.Put_Line ("'" & Operands.Element (I) & "' -> '" & Destination & "'");
                     end if;
                  end;
            end;
         end loop;
      end;
      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Mv;

   procedure Run_Printf
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
   begin
      if Context.Argument_Count = 0 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      declare
         Format : constant String := Context.Argument (1);
         Arg    : Positive := 2;
         Used_Argument : Boolean := False;
         Format_Ok : Boolean := True;
         Stop_Output : Boolean := False;

         function Numeric_Locale return String is
            LC_All     : constant String := Context.Environment_Value ("LC_ALL");
            LC_Numeric : constant String := Context.Environment_Value ("LC_NUMERIC");
            Lang       : constant String := Context.Environment_Value ("LANG");
         begin
            if LC_All /= "" then
               return LC_All;
            elsif LC_Numeric /= "" then
               return LC_Numeric;
            elsif Lang /= "" then
               return Lang;
            else
               return Context.Effective_Locale;
            end if;
         end Numeric_Locale;

         function Localize_Decimal_Number
           (Text                : String;
            Localize_Radix      : Boolean;
            Localize_Digit_Glyphs : Boolean := True) return String
         is
            Locale  : constant String := Numeric_Locale;
            Radix   : constant String := I18N.CLDR_Data.Decimal_Separator (Locale);
            Plus    : constant String := I18N.CLDR_Data.Number_Plus_Sign (Locale);
            Minus   : constant String := I18N.CLDR_Data.Number_Minus_Sign (Locale);
            Output  : Unbounded_String;
         begin
            for I in Text'Range loop
               if Text (I) in '0' .. '9' and then Localize_Digit_Glyphs then
                  Append (Output, I18N.CLDR_Data.Digit_Text (Locale, Text (I)));
               elsif Text (I) = '.' and then Localize_Radix then
                  Append (Output, Radix);
               elsif Text (I) = '+' then
                  Append (Output, Plus);
               elsif Text (I) = '-' then
                  Append (Output, Minus);
               else
                  Append (Output, Text (I));
               end if;
            end loop;

            return To_String (Output);
         end Localize_Decimal_Number;

         function Canonical_Decimal (Text : String; Ok : out Boolean) return String is
            First    : Positive := Text'First;
            Negative : Boolean := False;
            Parsed   : Posix_Tools.Numbers.Parse_Result;
         begin
            Ok := False;
            if Text = "" then
               return "";
            elsif Text (First) = '-' or else Text (First) = '+' then
               Negative := Text (First) = '-';
               First := First + 1;
               if First > Text'Last then
                  return "";
               end if;
            end if;

            Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Text (First .. Text'Last));
            if Parsed.Status /= Posix_Tools.Numbers.Valid then
               return "";
            end if;

            Ok := True;
            declare
               Raw : constant String := Posix_Tools.Numbers.Count'Image (Parsed.Value);
               Magnitude : constant String := Raw (Raw'First + 1 .. Raw'Last);
            begin
               if Negative and then Parsed.Value /= 0 then
                  return "-" & Magnitude;
               else
                  return Magnitude;
               end if;
            end;
         end Canonical_Decimal;

         function Canonical_Unsigned (Text : String; Ok : out Boolean) return String is
            First  : Positive := Text'First;
            Parsed : Posix_Tools.Numbers.Parse_Result;
         begin
            Ok := False;
            if Text = "" then
               return "";
            elsif Text (First) = '+' then
               First := First + 1;
               if First > Text'Last then
                  return "";
               end if;
            elsif Text (First) = '-' then
               return "";
            end if;

            Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Text (First .. Text'Last));
            if Parsed.Status /= Posix_Tools.Numbers.Valid then
               return "";
            end if;

            Ok := True;
            declare
               Raw : constant String := Posix_Tools.Numbers.Count'Image (Parsed.Value);
            begin
               return Raw (Raw'First + 1 .. Raw'Last);
            end;
         end Canonical_Unsigned;

         function Unsigned_Image
           (Text  : String;
            Base  : Positive;
            Upper : Boolean;
            Ok    : out Boolean) return String
         is
            First  : Positive := Text'First;
            Parsed : Posix_Tools.Numbers.Parse_Result;
         begin
            Ok := False;
            if Text = "" or else Base < 2 or else Base > 16 then
               return "";
            elsif Text (First) = '+' then
               First := First + 1;
               if First > Text'Last then
                  return "";
               end if;
            elsif Text (First) = '-' then
               return "";
            end if;

            Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Text (First .. Text'Last));
            if Parsed.Status /= Posix_Tools.Numbers.Valid then
               return "";
            end if;

            Ok := True;
            if Parsed.Value = 0 then
               return "0";
            end if;

            declare
               Digit_Chars : constant String := (if Upper then "0123456789ABCDEF" else "0123456789abcdef");
               Buffer : String (1 .. 128);
               Next   : Natural := Buffer'Last;
               Value  : Posix_Tools.Numbers.Count := Parsed.Value;
            begin
               while Value > 0 loop
                  declare
                     Digit : constant Natural := Natural (Value mod Posix_Tools.Numbers.Count (Base));
                  begin
                     Buffer (Next) := Digit_Chars (Digit_Chars'First + Digit);
                     Next := Next - 1;
                     Value := Value / Posix_Tools.Numbers.Count (Base);
                  end;
               end loop;
               return Buffer (Next + 1 .. Buffer'Last);
            end;
         end Unsigned_Image;

         function Expanded_Backslash_Text (Text : String; Stop : out Boolean) return String is
            Output : Unbounded_String;
            I      : Positive := Text'First;
         begin
            Stop := False;
            while I <= Text'Last loop
               if Text (I) = '\' and then I < Text'Last then
                  if Text (I + 1) = 'a' then
                     Append (Output, Character'Val (7));
                     I := I + 2;
                  elsif Text (I + 1) = 'b' then
                     Append (Output, Character'Val (8));
                     I := I + 2;
                  elsif Text (I + 1) = 'c' then
                     Stop := True;
                     return To_String (Output);
                  elsif Text (I + 1) = 'f' then
                     Append (Output, Character'Val (12));
                     I := I + 2;
                  elsif Text (I + 1) = 'n' then
                     Append (Output, LF);
                     I := I + 2;
                  elsif Text (I + 1) = 'r' then
                     Append (Output, Character'Val (13));
                     I := I + 2;
                  elsif Text (I + 1) = 't' then
                     Append (Output, Character'Val (9));
                     I := I + 2;
                  elsif Text (I + 1) = 'v' then
                     Append (Output, Character'Val (11));
                     I := I + 2;
                  elsif Text (I + 1) = '\' then
                     Append (Output, '\');
                     I := I + 2;
                  elsif Text (I + 1) in '0' .. '7' then
                     declare
                        Value : Natural := 0;
                        Last  : Natural := I;
                     begin
                        while Last < Text'Last
                          and then Last < I + 3
                          and then Text (Last + 1) in '0' .. '7'
                        loop
                           Last := Last + 1;
                           Value := Value * 8 + Character'Pos (Text (Last)) - Character'Pos ('0');
                        end loop;
                        Append (Output, Character'Val (Value mod 256));
                        I := Last + 1;
                     end;
                  else
                     Append (Output, Text (I + 1));
                     I := I + 2;
                  end if;
               else
                  Append (Output, Text (I));
                  I := I + 1;
               end if;
            end loop;
            return To_String (Output);
         end Expanded_Backslash_Text;

         procedure Emit_Field
           (Text          : String;
            Width         : Natural;
            Left_Justify  : Boolean := False;
            Has_Precision : Boolean := False;
            Precision     : Natural := 0;
            Pad           : Character := ' ')
         is
            Field : constant String :=
              (if Has_Precision and then Precision < Text'Length
               then Text (Text'First .. Text'First + Precision - 1)
               else Text);
         begin
            if Width > Field'Length and then not Left_Justify then
               declare
                  Padding : constant String (1 .. Width - Field'Length) := [others => Pad];
               begin
                  if Pad = '0'
                    and then Field'Length > 0
                    and then (Field (Field'First) in '-' | '+' | ' '
                              or else (Field'Length > 1 and then Field (Field'First .. Field'First + 1) = "0x")
                              or else (Field'Length > 1 and then Field (Field'First .. Field'First + 1) = "0X"))
                  then
                     if Field (Field'First) in '-' | '+' | ' ' then
                        Context.Put ("" & Field (Field'First));
                     else
                        Context.Put (Field (Field'First .. Field'First + 1));
                     end if;
                     Context.Put (Padding);
                     if Field (Field'First) in '-' | '+' | ' ' and then Field'Length > 1 then
                        Context.Put (Field (Field'First + 1 .. Field'Last));
                     elsif Field (Field'First) not in '-' | '+' | ' ' and then Field'Length > 2 then
                        Context.Put (Field (Field'First + 2 .. Field'Last));
                     end if;
                  else
                     Context.Put (Padding);
                     Context.Put (Field);
                  end if;
               end;
            else
               Context.Put (Field);
            end if;
            if Width > Field'Length and then Left_Justify then
               declare
                  Padding : constant String (1 .. Width - Field'Length) := [others => ' '];
               begin
                  Context.Put (Padding);
               end;
            end if;
         end Emit_Field;

         function Decimal_With_Precision
           (Image         : String;
            Has_Precision : Boolean;
            Precision     : Natural;
            Always_Sign   : Boolean := False;
            Blank_Sign    : Boolean := False) return String
         is
            Negative  : constant Boolean := Image'Length > 0 and then Image (Image'First) = '-';
            Magnitude : constant String :=
              (if Negative then Image (Image'First + 1 .. Image'Last) else Image);
            Zero_Value : constant Boolean :=
              (Magnitude'Length = 1 and then Magnitude (Magnitude'First) = '0');

            function With_Sign (Text : String) return String is
            begin
               if Negative then
                  return "-" & Text;
               elsif Always_Sign then
                  return "+" & Text;
               elsif Blank_Sign then
                  return " " & Text;
               else
                  return Text;
               end if;
            end With_Sign;
         begin
            if not Has_Precision then
               return With_Sign (Magnitude);
            elsif Precision = 0 and then Zero_Value then
               return With_Sign ("");
            elsif Precision <= Magnitude'Length then
               return With_Sign (Magnitude);
            else
               declare
                  Padding : constant String (1 .. Precision - Magnitude'Length) := [others => '0'];
               begin
                  return With_Sign (Padding & Magnitude);
               end;
            end if;
         end Decimal_With_Precision;

         function Fixed_Float_Image
           (Text        : String;
            Precision   : Natural;
            Always_Sign : Boolean;
            Blank_Sign  : Boolean;
            Ok          : out Boolean) return String
         is
            First       : Positive := Text'First;
            Negative    : Boolean := False;
            Saw_Digit   : Boolean := False;
            Saw_Dot     : Boolean := False;
            Whole       : Long_Long_Integer := 0;
            Fraction    : Long_Long_Integer := 0;
            Fraction_Digits : Natural := 0;
            Extra_Digit : Natural := 0;
         begin
            Ok := False;
            if Text = "" then
               return "";
            elsif Text (First) = '-' or else Text (First) = '+' then
               Negative := Text (First) = '-';
               First := First + 1;
               if First > Text'Last then
                  return "";
               end if;
            end if;

            for I in First .. Text'Last loop
               if Text (I) in '0' .. '9' then
                  Saw_Digit := True;
                  if Saw_Dot then
                     if Fraction_Digits < Precision then
                        declare
                           Digit : constant Long_Long_Integer :=
                             Long_Long_Integer (Character'Pos (Text (I)) - Character'Pos ('0'));
                        begin
                           if Fraction > (Long_Long_Integer'Last - Digit) / 10 then
                              return "";
                           end if;
                           Fraction := Fraction * 10 + Digit;
                           Fraction_Digits := Fraction_Digits + 1;
                        end;
                     elsif Fraction_Digits = Precision then
                        Extra_Digit := Character'Pos (Text (I)) - Character'Pos ('0');
                        Fraction_Digits := Fraction_Digits + 1;
                     end if;
                  else
                     declare
                        Digit : constant Long_Long_Integer :=
                          Long_Long_Integer (Character'Pos (Text (I)) - Character'Pos ('0'));
                     begin
                        if Whole > (Long_Long_Integer'Last - Digit) / 10 then
                           return "";
                        end if;
                        Whole := Whole * 10 + Digit;
                     end;
                  end if;
               elsif Text (I) = '.' and then not Saw_Dot then
                  Saw_Dot := True;
               else
                  return "";
               end if;
            end loop;

            if not Saw_Digit then
               return "";
            end if;

            while Fraction_Digits < Precision loop
               if Fraction > Long_Long_Integer'Last / 10 then
                  return "";
               end if;
               Fraction := Fraction * 10;
               Fraction_Digits := Fraction_Digits + 1;
            end loop;

            if Extra_Digit >= 5 then
               Fraction := Fraction + 1;
               declare
                  Scale : Long_Long_Integer := 1;
               begin
                  for I in 1 .. Precision loop
                     if Scale > Long_Long_Integer'Last / 10 then
                        return "";
                     end if;
                     Scale := Scale * 10;
                  end loop;
                  if Precision > 0 and then Fraction >= Scale then
                     Fraction := Fraction - Scale;
                     if Whole = Long_Long_Integer'Last then
                        return "";
                     end if;
                     Whole := Whole + 1;
                  elsif Precision = 0 then
                     if Whole = Long_Long_Integer'Last then
                        return "";
                     end if;
                     Whole := Whole + 1;
                     Fraction := 0;
                  end if;
               end;
            end if;

            Ok := True;

            declare
               Whole_Image : constant String := Long_Long_Integer'Image (Whole);
               Whole_Text  : constant String := Whole_Image (Whole_Image'First + 1 .. Whole_Image'Last);
               Fraction_Int : Long_Long_Integer := Fraction;
               Fraction_Buffer : String (1 .. Natural'Max (Precision, 1)) := [others => '0'];
               Sign_Text : constant String :=
                 (if Negative then "-"
                  elsif Always_Sign then "+"
                  elsif Blank_Sign then " "
                  else "");
            begin
               if Precision > 0 then
                  for I in reverse 1 .. Precision loop
                     Fraction_Buffer (I) :=
                       Character'Val (Character'Pos ('0') + Natural (Fraction_Int mod 10));
                     Fraction_Int := Fraction_Int / 10;
                  end loop;
                  return Sign_Text & Whole_Text & "." & Fraction_Buffer (1 .. Precision);
               else
                  return Sign_Text & Whole_Text;
               end if;
            end;
         exception
            when Constraint_Error =>
               Ok := False;
               return "";
         end Fixed_Float_Image;

         function Scientific_Float_Image
           (Text        : String;
            Precision   : Natural;
            Upper       : Boolean;
            Always_Sign : Boolean;
            Blank_Sign  : Boolean;
            Alternate   : Boolean;
            Ok          : out Boolean) return String
         is
            First        : Positive := Text'First;
            Negative     : Boolean := False;
            Saw_Digit    : Boolean := False;
            Saw_Dot      : Boolean := False;
            Fraction     : Natural := 0;
            Exponent     : Integer := 0;
            Exp_Negative : Boolean := False;
            Digits_Text  : Unbounded_String;

            function Exponent_Text (Value : Integer) return String is
               Image : constant String := Integer'Image (abs Value);
               Raw   : constant String := Image (Image'First + 1 .. Image'Last);
            begin
               if Raw'Length = 1 then
                  return (if Value < 0 then "-0" & Raw else "+0" & Raw);
               else
                  return (if Value < 0 then "-" & Raw else "+" & Raw);
               end if;
            end Exponent_Text;
         begin
            Ok := False;
            if Text = "" then
               return "";
            elsif Text (First) = '-' or else Text (First) = '+' then
               Negative := Text (First) = '-';
               First := First + 1;
               if First > Text'Last then
                  return "";
               end if;
            end if;

            for I in First .. Text'Last loop
               if Text (I) in '0' .. '9' then
                  Saw_Digit := True;
                  Append (Digits_Text, Text (I));
                  if Saw_Dot then
                     Fraction := Fraction + 1;
                  end if;
               elsif Text (I) = '.' and then not Saw_Dot then
                  Saw_Dot := True;
               elsif Text (I) in 'e' | 'E' then
                  declare
                     J : Natural := I + 1;
                  begin
                     if J > Text'Last then
                        return "";
                     elsif Text (J) = '-' or else Text (J) = '+' then
                        Exp_Negative := Text (J) = '-';
                        J := J + 1;
                        if J > Text'Last then
                           return "";
                        end if;
                     end if;

                     while J <= Text'Last loop
                        if Text (J) not in '0' .. '9' then
                           return "";
                        elsif Exponent > 999_999 then
                           return "";
                        end if;
                        Exponent := Exponent * 10 + Character'Pos (Text (J)) - Character'Pos ('0');
                        J := J + 1;
                     end loop;
                     if Exp_Negative then
                        Exponent := -Exponent;
                     end if;
                     exit;
                  end;
               else
                  return "";
               end if;
            end loop;

            if not Saw_Digit then
               return "";
            end if;

            declare
               Raw      : constant String := To_String (Digits_Text);
               First_NZ : Natural := 0;
            begin
               for I in Raw'Range loop
                  if Raw (I) /= '0' then
                     First_NZ := I;
                     exit;
                  end if;
               end loop;

               if First_NZ = 0 then
                  declare
                     Fraction_Zeros : constant String (1 .. Natural'Max (Precision, 1)) := [others => '0'];
                     Sign_Text : constant String :=
                       (if Negative then "-" elsif Always_Sign then "+" elsif Blank_Sign then " " else "");
                  begin
                     Ok := True;
                     return Sign_Text
                       & "0"
                       & (if Precision > 0
                          then "." & Fraction_Zeros (1 .. Precision)
                          elsif Alternate
                          then "."
                          else "")
                       & (if Upper then "E+00" else "e+00");
                  end;
               else
                  declare
                     Decimal_Exponent : Integer := Raw'Last - Fraction - First_NZ + Exponent;
                     Mantissa_Length  : constant Natural := Precision + 1;
                     Mantissa         : String (1 .. Mantissa_Length) := [others => '0'];
                     Source_Index     : Natural := First_NZ;
                     Round_Digit      : Natural := 0;
                     Sign_Text        : constant String :=
                       (if Negative then "-" elsif Always_Sign then "+" elsif Blank_Sign then " " else "");
                  begin
                     for I in Mantissa'Range loop
                        if Source_Index <= Raw'Last then
                           Mantissa (I) := Raw (Source_Index);
                           Source_Index := Source_Index + 1;
                        end if;
                     end loop;

                     if Source_Index <= Raw'Last then
                        Round_Digit := Character'Pos (Raw (Source_Index)) - Character'Pos ('0');
                     end if;

                     if Round_Digit >= 5 then
                        for I in reverse Mantissa'Range loop
                           if Mantissa (I) < '9' then
                              Mantissa (I) := Character'Val (Character'Pos (Mantissa (I)) + 1);
                              exit;
                           else
                              Mantissa (I) := '0';
                              if I = Mantissa'First then
                                 Mantissa (I) := '1';
                                 Decimal_Exponent := Decimal_Exponent + 1;
                              end if;
                           end if;
                        end loop;
                     end if;

                     Ok := True;
                     return Sign_Text
                       & Mantissa (Mantissa'First)
                       & (if Precision > 0
                          then "." & Mantissa (Mantissa'First + 1 .. Mantissa'Last)
                          elsif Alternate
                          then "."
                          else "")
                       & (if Upper then "E" else "e")
                       & Exponent_Text (Decimal_Exponent);
                  end;
               end if;
            end;
         exception
            when Constraint_Error =>
               Ok := False;
               return "";
         end Scientific_Float_Image;

         function Decimal_Exponent_Of (Text : String; Ok : out Boolean) return Integer is
            First        : Positive := Text'First;
            Saw_Digit    : Boolean := False;
            Saw_Dot      : Boolean := False;
            Fraction     : Natural := 0;
            Exponent     : Integer := 0;
            Exp_Negative : Boolean := False;
            Digits_Text  : Unbounded_String;
         begin
            Ok := False;
            if Text = "" then
               return 0;
            elsif Text (First) = '-' or else Text (First) = '+' then
               First := First + 1;
               if First > Text'Last then
                  return 0;
               end if;
            end if;

            for I in First .. Text'Last loop
               if Text (I) in '0' .. '9' then
                  Saw_Digit := True;
                  Append (Digits_Text, Text (I));
                  if Saw_Dot then
                     Fraction := Fraction + 1;
                  end if;
               elsif Text (I) = '.' and then not Saw_Dot then
                  Saw_Dot := True;
               elsif Text (I) in 'e' | 'E' then
                  declare
                     J : Natural := I + 1;
                  begin
                     if J > Text'Last then
                        return 0;
                     elsif Text (J) = '-' or else Text (J) = '+' then
                        Exp_Negative := Text (J) = '-';
                        J := J + 1;
                        if J > Text'Last then
                           return 0;
                        end if;
                     end if;

                     while J <= Text'Last loop
                        if Text (J) not in '0' .. '9' or else Exponent > 999_999 then
                           return 0;
                        end if;
                        Exponent := Exponent * 10 + Character'Pos (Text (J)) - Character'Pos ('0');
                        J := J + 1;
                     end loop;
                     if Exp_Negative then
                        Exponent := -Exponent;
                     end if;
                     exit;
                  end;
               else
                  return 0;
               end if;
            end loop;

            if not Saw_Digit then
               return 0;
            end if;

            declare
               Raw : constant String := To_String (Digits_Text);
            begin
               for I in Raw'Range loop
                  if Raw (I) /= '0' then
                     Ok := True;
                     return Raw'Last - Fraction - I + Exponent;
                  end if;
               end loop;
            end;

            Ok := True;
            return 0;
         end Decimal_Exponent_Of;

         function Trim_General_Float (Text : String; Alternate : Boolean) return String is
         begin
            if Alternate then
               return Text;
            end if;

            declare
               Exp_Pos : Natural := 0;
            begin
               for I in Text'Range loop
                  if Text (I) in 'e' | 'E' then
                     Exp_Pos := I;
                     exit;
                  end if;
               end loop;

               declare
                  Mantissa_First : constant Natural := Text'First;
                  Mantissa_Last  : constant Natural := (if Exp_Pos = 0 then Text'Last else Exp_Pos - 1);
                  Last           : Natural := Mantissa_Last;
                  Dot_Pos        : Natural := 0;
               begin
                  for I in Mantissa_First .. Mantissa_Last loop
                     if Text (I) = '.' then
                        Dot_Pos := I;
                        exit;
                     end if;
                  end loop;

                  if Dot_Pos = 0 then
                     return Text;
                  end if;

                  while Last > Dot_Pos and then Text (Last) = '0' loop
                     Last := Last - 1;
                  end loop;
                  if Last = Dot_Pos then
                     Last := Last - 1;
                  end if;

                  return Text (Text'First .. Last)
                    & (if Exp_Pos = 0 then "" else Text (Exp_Pos .. Text'Last));
               end;
            end;
         end Trim_General_Float;

         function General_Float_Image
           (Text        : String;
            Precision   : Natural;
            Upper       : Boolean;
            Always_Sign : Boolean;
            Blank_Sign  : Boolean;
            Alternate   : Boolean;
            Ok          : out Boolean) return String
         is
            Effective_Precision : constant Natural := (if Precision = 0 then 1 else Precision);
            Exponent_Ok         : Boolean;
            Decimal_Exponent    : constant Integer := Decimal_Exponent_Of (Text, Exponent_Ok);
         begin
            if not Exponent_Ok then
               Ok := False;
               return "";
            elsif Decimal_Exponent < -4 or else Decimal_Exponent >= Effective_Precision then
               declare
                  Image : constant String :=
                    Scientific_Float_Image
                      (Text,
                       Effective_Precision - 1,
                       Upper,
                       Always_Sign,
                       Blank_Sign,
                       Alternate,
                       Ok);
               begin
                  return (if Ok then Trim_General_Float (Image, Alternate) else "");
               end;
            else
               declare
                  Fraction_Precision : constant Natural :=
                    (if Decimal_Exponent >= Integer (Effective_Precision)
                     then 0
                     elsif Decimal_Exponent >= 0
                     then Effective_Precision - Natural (Decimal_Exponent) - 1
                     else Effective_Precision + Natural (-Decimal_Exponent) - 1);
                  Image : constant String :=
                    Fixed_Float_Image
                      (Text, Fraction_Precision, Always_Sign, Blank_Sign, Ok);
               begin
                  return (if Ok then Trim_General_Float (Image, Alternate) else "");
               end;
            end if;
         end General_Float_Image;

         procedure Emit_Format (Used : out Boolean) is
            I : Positive := Format'First;

            function Parse_Checked_Signed (Text : String; Ok : out Boolean) return Long_Long_Integer is
               Image : constant String := Canonical_Decimal (Text, Ok);
               First : Positive;
               Negative : Boolean := False;
               Value : Long_Long_Integer := 0;
            begin
               if not Ok or else Image = "" then
                  Ok := False;
                  return 0;
               end if;

               First := Image'First;
               if Image (First) = '-' then
                  Negative := True;
                  First := First + 1;
               end if;

               for Index in First .. Image'Last loop
                  declare
                     Digit : constant Long_Long_Integer :=
                       Long_Long_Integer (Character'Pos (Image (Index)) - Character'Pos ('0'));
                  begin
                     if Value > (Long_Long_Integer'Last - Digit) / 10 then
                        Ok := False;
                        return 0;
                     end if;
                     Value := Value * 10 + Digit;
                  end;
               end loop;

               return (if Negative then -Value else Value);
            end Parse_Checked_Signed;

            function Consume_Star_Value (Ok : out Boolean) return Long_Long_Integer is
            begin
               if Arg > Context.Argument_Count then
                  Ok := True;
                  Used := True;
                  return 0;
               end if;

               declare
                  Value : constant Long_Long_Integer := Parse_Checked_Signed (Context.Argument (Arg), Ok);
               begin
                  Arg := Arg + 1;
                  Used := True;
                  return Value;
               end;
            end Consume_Star_Value;
         begin
            Used := False;
            while I <= Format'Last and then not Stop_Output loop
               if Format (I) = '%' and then I < Format'Last and then Format (I + 1) = 's' then
                  Context.Put ((if Arg <= Context.Argument_Count then Context.Argument (Arg) else ""));
                  Arg := Arg + 1;
                  Used := True;
                  I := I + 2;
               elsif Format (I) = '%' and then I < Format'Last and then Format (I + 1) = 'b' then
                  if Arg <= Context.Argument_Count then
                     declare
                        Stop : Boolean;
                        Expanded : constant String := Expanded_Backslash_Text (Context.Argument (Arg), Stop);
                     begin
                        Context.Put (Expanded);
                        Stop_Output := Stop;
                     end;
                  end if;
                  Arg := Arg + 1;
                  Used := True;
                  I := I + 2;
               elsif Format (I) = '%'
               and then I < Format'Last
                 and then Format (I + 1) in 'd' | 'i' | 'u' | 'o' | 'x' | 'X' | 'f' | 'e' | 'E' | 'g' | 'G'
               then
                  declare
                     Numeric_Text : constant String :=
                       (if Arg <= Context.Argument_Count then Context.Argument (Arg) else "0");
                     Numeric_Ok   : Boolean;
                     Image        : constant String :=
                       (if Format (I + 1) in 'd' | 'i'
                        then Canonical_Decimal (Numeric_Text, Numeric_Ok)
                        elsif Format (I + 1) = 'u'
                        then Canonical_Unsigned (Numeric_Text, Numeric_Ok)
                        elsif Format (I + 1) = 'o'
                        then Unsigned_Image (Numeric_Text, 8, False, Numeric_Ok)
                        elsif Format (I + 1) = 'f'
                        then Fixed_Float_Image (Numeric_Text, 6, False, False, Numeric_Ok)
                        elsif Format (I + 1) in 'e' | 'E'
                        then Scientific_Float_Image
                          (Numeric_Text,
                           6,
                           Format (I + 1) = 'E',
                           False,
                           False,
                           False,
                           Numeric_Ok)
                        elsif Format (I + 1) in 'g' | 'G'
                        then General_Float_Image
                          (Numeric_Text,
                           6,
                           Format (I + 1) = 'G',
                           False,
                           False,
                           False,
                           Numeric_Ok)
                        else Unsigned_Image (Numeric_Text, 16, Format (I + 1) = 'X', Numeric_Ok));
                  begin
                     if Numeric_Ok then
                        Context.Put
                          ((if Format (I + 1) in 'd' | 'i' | 'u' | 'f' | 'e' | 'E' | 'g' | 'G'
                            then Localize_Decimal_Number
                              (Image, Format (I + 1) in 'f' | 'e' | 'E' | 'g' | 'G')
                            else Image));
                     else
                        Format_Ok := False;
                     end if;
                  end;
                  Arg := Arg + 1;
                  Used := True;
                  I := I + 2;
               elsif Format (I) = '%' and then I < Format'Last
                 and then (Format (I + 1) in '0' .. '9'
                           or else Format (I + 1) = '.'
                           or else Format (I + 1) = '*'
                           or else Format (I + 1) in '-' | '+' | ' ' | '#')
               then
                  declare
                     J            : Natural := I + 1;
                     Width        : Natural := 0;
                     Left_Justify : Boolean := False;
                     Always_Sign  : Boolean := False;
                     Blank_Sign   : Boolean := False;
                     Zero_Pad     : Boolean := False;
                     Alternate    : Boolean := False;
                     Has_Precision : Boolean := False;
                     Precision     : Natural := 0;
                  begin
                     while J <= Format'Last and then Format (J) in '-' | '+' | ' ' | '0' | '#' loop
                        case Format (J) is
                           when '-' =>
                              Left_Justify := True;
                           when '+' =>
                              Always_Sign := True;
                              Blank_Sign := False;
                           when ' ' =>
                              if not Always_Sign then
                                 Blank_Sign := True;
                              end if;
                           when '0' =>
                              Zero_Pad := True;
                           when '#' =>
                              Alternate := True;
                           when others =>
                              null;
                        end case;
                        J := J + 1;
                     end loop;
                     if J > Format'Last
                       or else (Format (J) not in '0' .. '9'
                                and then Format (J) /= '.'
                                and then Format (J) /= '*'
                                and then Format (J) not in
                                  's' | 'b' | 'c' | 'd' | 'i' | 'u' | 'o' | 'x' | 'X' | 'f' | 'e' | 'E' | 'g' | 'G')
                     then
                        Context.Put ("%");
                        I := I + 1;
                     else
                        if J <= Format'Last and then Format (J) = '*' then
                           declare
                              Star_Ok : Boolean;
                              Star_Value : constant Long_Long_Integer := Consume_Star_Value (Star_Ok);
                           begin
                              if not Star_Ok or else abs Star_Value > Long_Long_Integer (Natural'Last) then
                                 Format_Ok := False;
                                 return;
                              elsif Star_Value < 0 then
                                 Left_Justify := True;
                                 Width := Natural (-Star_Value);
                              else
                                 Width := Natural (Star_Value);
                              end if;
                              J := J + 1;
                           end;
                        end if;

                        while J <= Format'Last and then Format (J) in '0' .. '9' loop
                           if Width > (Natural'Last - (Character'Pos (Format (J)) - Character'Pos ('0'))) / 10 then
                              Format_Ok := False;
                              return;
                           end if;
                           Width := Width * 10 + Character'Pos (Format (J)) - Character'Pos ('0');
                           J := J + 1;
                        end loop;

                        if J <= Format'Last and then Format (J) = '.' then
                           Has_Precision := True;
                           J := J + 1;
                           if J <= Format'Last and then Format (J) = '*' then
                              declare
                                 Star_Ok : Boolean;
                                 Star_Value : constant Long_Long_Integer := Consume_Star_Value (Star_Ok);
                              begin
                                 if not Star_Ok or else Star_Value > Long_Long_Integer (Natural'Last) then
                                    Format_Ok := False;
                                    return;
                                 elsif Star_Value < 0 then
                                    Has_Precision := False;
                                    Precision := 0;
                                 else
                                    Precision := Natural (Star_Value);
                                 end if;
                                 J := J + 1;
                              end;
                           end if;

                           while J <= Format'Last and then Format (J) in '0' .. '9' loop
                              if Precision >
                                (Natural'Last - (Character'Pos (Format (J)) - Character'Pos ('0'))) / 10
                              then
                                 Format_Ok := False;
                                 return;
                              end if;
                              Precision := Precision * 10 + Character'Pos (Format (J)) - Character'Pos ('0');
                              J := J + 1;
                           end loop;
                        end if;

                        if J <= Format'Last and then Format (J) = 's' then
                           Emit_Field
                             ((if Arg <= Context.Argument_Count then Context.Argument (Arg) else ""),
                              Width,
                              Left_Justify,
                              Has_Precision,
                              Precision);
                           Arg := Arg + 1;
                           Used := True;
                           I := J + 1;
                        elsif J <= Format'Last and then Format (J) = 'b' then
                           if Arg <= Context.Argument_Count then
                              declare
                                 Stop : Boolean;
                                 Expanded : constant String :=
                                   Expanded_Backslash_Text (Context.Argument (Arg), Stop);
                              begin
                                 Emit_Field (Expanded, Width, Left_Justify, Has_Precision, Precision);
                                 Stop_Output := Stop;
                              end;
                           end if;
                           Arg := Arg + 1;
                           Used := True;
                           I := J + 1;
                        elsif J <= Format'Last and then Format (J) = 'c' then
                           declare
                              Field : constant String :=
                                (if Arg <= Context.Argument_Count and then Context.Argument (Arg) /= ""
                                 then "" & Context.Argument (Arg) (Context.Argument (Arg)'First)
                                 else "");
                           begin
                              Emit_Field (Field, Width, Left_Justify);
                           end;
                           Arg := Arg + 1;
                           Used := True;
                           I := J + 1;
                        elsif J <= Format'Last
                          and then Format (J) in 'd' | 'i' | 'u' | 'o' | 'x' | 'X' | 'f' | 'e' | 'E'
                            | 'g' | 'G'
                        then
                           declare
                              Numeric_Text : constant String :=
                                (if Arg <= Context.Argument_Count then Context.Argument (Arg) else "0");
                              Numeric_Ok   : Boolean;
                              Image        : constant String :=
                                (if Format (J) in 'd' | 'i'
                                 then Canonical_Decimal (Numeric_Text, Numeric_Ok)
                                 elsif Format (J) = 'u'
                                 then Canonical_Unsigned (Numeric_Text, Numeric_Ok)
                                 elsif Format (J) = 'o'
                                 then Unsigned_Image (Numeric_Text, 8, False, Numeric_Ok)
                                 elsif Format (J) = 'f'
                                 then Fixed_Float_Image
                                   (Numeric_Text,
                                    (if Has_Precision then Precision else 6),
                                    Always_Sign,
                                    Blank_Sign,
                                    Numeric_Ok)
                                 elsif Format (J) in 'e' | 'E'
                                 then Scientific_Float_Image
                                   (Numeric_Text,
                                    (if Has_Precision then Precision else 6),
                                    Format (J) = 'E',
                                    Always_Sign,
                                    Blank_Sign,
                                    Alternate,
                                    Numeric_Ok)
                                 elsif Format (J) in 'g' | 'G'
                                 then General_Float_Image
                                   (Numeric_Text,
                                    (if Has_Precision then Precision else 6),
                                    Format (J) = 'G',
                                    Always_Sign,
                                    Blank_Sign,
                                    Alternate,
                                    Numeric_Ok)
                                 else Unsigned_Image (Numeric_Text, 16, Format (J) = 'X', Numeric_Ok));
                           begin
                              if Numeric_Ok then
                                 declare
                                    Formatted : constant String :=
                                      (if Format (J) in 'f' | 'e' | 'E' | 'g' | 'G'
                                       then Image
                                       else Decimal_With_Precision
                                         (Image,
                                          Has_Precision,
                                          Precision,
                                          Always_Sign and then Format (J) in 'd' | 'i',
                                          Blank_Sign and then Format (J) in 'd' | 'i'));
                                    Zero_Value : constant Boolean :=
                                      Formatted = "" or else Formatted = "0";
                                    Alternate_Image : constant String :=
                                      (if Alternate and then Format (J) = 'o' and then not Zero_Value
                                       then "0" & Formatted
                                       elsif Alternate and then Format (J) = 'x' and then not Zero_Value
                                       then "0x" & Formatted
                                       elsif Alternate and then Format (J) = 'X' and then not Zero_Value
                                       then "0X" & Formatted
                                       else Formatted);
                                    Localized_Image : constant String :=
                                      (if Format (J) in 'd' | 'i' | 'u' | 'f' | 'e' | 'E' | 'g' | 'G'
                                       then Localize_Decimal_Number
                                         (Alternate_Image,
                                          Format (J) in 'f' | 'e' | 'E' | 'g' | 'G')
                                       else Alternate_Image);
                                 begin
                                    Emit_Field
                                      (Localized_Image,
                                       Width,
                                       Left_Justify,
                                       Pad =>
                                         (if Zero_Pad
                                            and then (Format (J) in 'f' | 'e' | 'E' | 'g' | 'G'
                                                      or else not Has_Precision)
                                          then '0'
                                          else ' '));
                                 end;
                              else
                                 Format_Ok := False;
                              end if;
                           end;
                           Arg := Arg + 1;
                           Used := True;
                           I := J + 1;
                        else
                           Context.Put ("%");
                           I := I + 1;
                        end if;
                     end if;
                  end;
               elsif Format (I) = '%' and then I < Format'Last and then Format (I + 1) = 'c' then
                  if Arg <= Context.Argument_Count and then Context.Argument (Arg) /= "" then
                     Context.Put ("" & Context.Argument (Arg) (Context.Argument (Arg)'First));
                  end if;
                  Arg := Arg + 1;
                  Used := True;
                  I := I + 2;
               elsif Format (I) = '%' and then I < Format'Last and then Format (I + 1) = '%' then
                  Context.Put ("%");
                  I := I + 2;
               elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = 'a' then
                  Context.Put ("" & Character'Val (7));
                  I := I + 2;
               elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = 'b' then
                  Context.Put ("" & Character'Val (8));
                  I := I + 2;
               elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = 'f' then
                  Context.Put ("" & Character'Val (12));
                  I := I + 2;
               elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = 'n' then
                  Context.Put ("" & LF);
                  I := I + 2;
               elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = 't' then
                  Context.Put ("" & Character'Val (9));
                  I := I + 2;
               elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = 'r' then
                  Context.Put ("" & Character'Val (13));
                  I := I + 2;
               elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = 'v' then
                  Context.Put ("" & Character'Val (11));
                  I := I + 2;
               elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = '\' then
                  Context.Put ("\");
                  I := I + 2;
               elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = '0' then
                  declare
                     Value : Natural := 0;
                     Last  : Natural := I + 1;
                  begin
                     while Last < Format'Last
                       and then Last < I + 4
                       and then Format (Last + 1) in '0' .. '7'
                     loop
                        Last := Last + 1;
                        Value := Value * 8 + Character'Pos (Format (Last)) - Character'Pos ('0');
                     end loop;
                     Context.Put ("" & Character'Val (Value mod 256));
                     I := Last + 1;
                  end;
               else
                  Context.Put ("" & Format (I));
                  I := I + 1;
               end if;
            end loop;
         end Emit_Format;
      begin
         Emit_Format (Used_Argument);
         while Used_Argument and then Arg <= Context.Argument_Count loop
            Emit_Format (Used_Argument);
         end loop;
         if not Format_Ok then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid number");
            return;
         end if;
      end;
      Set_Success (Context, Result);
   end Run_Printf;

   procedure Run_Rm
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Recursive : Boolean := False;
      Force     : Boolean := False;
      Interactive : Boolean := False;
      Directory : Boolean := False;
      Verbose   : Boolean := False;
      First     : Positive := 1;
      Ok        : Boolean := True;

      function Confirm_Removal (Path : String) return Boolean is
         Buffer : Ada.Streams.Stream_Element_Array (1 .. 1);
         Last   : Ada.Streams.Stream_Element_Offset;
      begin
         if not Interactive then
            return True;
         end if;

         Context.Put_Error_Line ("rm: remove '" & Path & "'?");
         if not Context.Try_Read_Standard_Input (Buffer, Last) or else Last < Buffer'First then
            return False;
         end if;

         return Character'Val (Buffer (Buffer'First)) in 'y' | 'Y';
      end Confirm_Removal;
   begin
      while First <= Context.Argument_Count
        and then Context.Argument (First)'Length > 1
        and then Context.Argument (First) (1) = '-'
      loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         end if;
         for Ch of Context.Argument (First) (2 .. Context.Argument (First)'Last) loop
            case Ch is
               when 'r' | 'R' => Recursive := True;
               when 'f' =>
                  Force := True;
                  Interactive := False;
               when 'i' =>
                  Force := False;
                  Interactive := True;
               when 'd' => Directory := True;
               when 'v' => Verbose := True;
               when others =>
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                  return;
            end case;
         end loop;
         First := First + 1;
      end loop;
      if First > Context.Argument_Count and then not Force then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;
      for I in First .. Context.Argument_Count loop
         begin
            if Confirm_Removal (Context.Argument (I)) then
               if Recursive and then FS.Kind (Context.Argument (I)) = FS.Directory
               then
                  FS.Delete_Tree (Context.Argument (I));
               elsif Directory and then FS.Kind (Context.Argument (I)) = FS.Directory
               then
                  FS.Delete_Directory (Context.Argument (I));
               else
                  FS.Delete_File (Context.Argument (I));
               end if;
               if Verbose then
                  Context.Put_Line ("removed '" & Context.Argument (I) & "'");
               end if;
            end if;
         exception
            when others =>
               if not Force then
                  Ok := False;
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Context.Argument (I), "posix_tools.diagnostic.file.open_failed", "cannot open file");
               end if;
         end;
      end loop;
      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Rm;

   procedure Run_Rmdir
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Ok : Boolean := True;
      Parents : Boolean := False;
      First : Positive := 1;
   begin
      while First <= Context.Argument_Count
        and then Context.Argument (First)'Length > 1
        and then Context.Argument (First) (1) = '-'
      loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         end if;

         for Ch of Context.Argument (First) (2 .. Context.Argument (First)'Last) loop
            case Ch is
               when 'p' =>
                  Parents := True;
               when others =>
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                  return;
            end case;
         end loop;
         First := First + 1;
      end loop;

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;
      for I in First .. Context.Argument_Count loop
         begin
            if Parents then
               declare
                  Current : Unbounded_String := To_Unbounded_String (Context.Argument (I));
               begin
                  loop
                     begin
                        FS.Delete_Directory (To_String (Current));
                     exception
                        when others =>
                           Ok := False;
                           Posix_Tools.Commands.Helpers.Subject_Operational_Error
                             (Context,
                              To_String (Current),
                              "posix_tools.diagnostic.file.open_failed",
                              "cannot open file");
                           exit;
                     end;

                     declare
                        Parent : constant String := FS.Containing_Directory (To_String (Current));
                     begin
                        exit when Parent = "" or else Parent = "." or else Parent = To_String (Current);
                        Current := To_Unbounded_String (Parent);
                     end;
                  end loop;
               end;
            else
               FS.Delete_Directory (Context.Argument (I));
            end if;
         exception
            when others =>
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Context.Argument (I), "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end;
      end loop;
      Result.Status :=
        (if Ok then Posix_Tools.Exit_Status.Success else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Rmdir;

   procedure Run_Sort
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Files       : String_Vectors.Vector;
      Output_Path : Unbounded_String;
      Reverse_Order : Boolean := False;
      Fold_Case   : Boolean := False;
      Ignore_Leading_Blanks : Boolean := False;
      Dictionary_Order : Boolean := False;
      Ignore_Nonprinting : Boolean := False;
      Numeric_Sort : Boolean := False;
      Stable_Sort  : Boolean := False;
      Unique      : Boolean := False;
      Check_Only  : Boolean := False;
      Keys        : Sort_Key_Vectors.Vector;
      Key_Field   : constant Positive := 1;
      Key_End_Field : constant Natural := 0;
      Key_Character : constant Positive := 1;
      Key_End_Character : constant Natural := 0;
      Field_Separator : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Text        : Unbounded_String;
      Ok          : Boolean := True;
      Skip_Next   : Boolean := False;
      Parsing_Operands : Boolean := False;
      Locale      : constant String := Context.Effective_Locale;

      function Parse_Sort_Key
         (Text : String;
          Key  : out Sort_Key_Definition) return Boolean
      is
         Last : Natural := Text'First - 1;
         End_Last : Natural;
         Value : Natural := 0;
         Field      : Positive := 1;
         End_Field  : Natural := 0;
         Char_Start : Positive := 1;
         End_Char   : Natural := 0;
         Key_Dictionary_Order : Boolean := False;
         Key_Fold_Case : Boolean := False;
         Key_Ignore_Leading_Blanks : Boolean := False;
         Key_Ignore_Nonprinting : Boolean := False;
         Key_Numeric_Sort : Boolean := False;
         Key_Reverse_Order : Boolean := False;

         function Is_Key_Modifier (Ch : Character) return Boolean is
         begin
            return Ch in 'b' | 'd' | 'f' | 'i' | 'n' | 'r';
         end Is_Key_Modifier;

         procedure Note_Key_Modifier (Ch : Character) is
         begin
            if Ch = 'b' then
               Key_Ignore_Leading_Blanks := True;
            elsif Ch = 'd' then
               Key_Dictionary_Order := True;
            elsif Ch = 'f' then
               Key_Fold_Case := True;
            elsif Ch = 'i' then
               Key_Ignore_Nonprinting := True;
            elsif Ch = 'n' then
               Key_Numeric_Sort := True;
            elsif Ch = 'r' then
               Key_Reverse_Order := True;
            end if;
         end Note_Key_Modifier;

         procedure Parse_Key_Modifiers is
         begin
            while Last < Text'Last and then Is_Key_Modifier (Text (Last + 1)) loop
               Last := Last + 1;
               Note_Key_Modifier (Text (Last));
            end loop;
         end Parse_Key_Modifiers;

         function Parse_Positive_Number
           (Start : Positive;
            Stop  : Natural;
            Number : out Natural;
            Last_Digit : out Natural) return Boolean
         is
         begin
            Number := 0;
            Last_Digit := Start - 1;
            if Start > Stop then
               return False;
            end if;

            for I in Start .. Stop loop
               exit when Text (I) not in '0' .. '9';
               Last_Digit := I;
               if Number > (Natural'Last - (Character'Pos (Text (I)) - Character'Pos ('0'))) / 10 then
                  return False;
               end if;
               Number := Number * 10 + Character'Pos (Text (I)) - Character'Pos ('0');
            end loop;

            return Last_Digit >= Start and then Number > 0;
         end Parse_Positive_Number;
      begin
         Key := (others => <>);
         if Text = "" then
            return False;
         end if;

         if not Parse_Positive_Number (Text'First, Text'Last, Value, Last) then
            return False;
         end if;

         Field := Positive (Value);
         if Last < Text'Last and then Text (Last + 1) = '.' then
            if not Parse_Positive_Number (Last + 2, Text'Last, Value, Last) then
               return False;
            end if;
            Char_Start := Positive (Value);
         end if;

         Parse_Key_Modifiers;

         if Last < Text'Last and then Text (Last + 1) /= ',' then
            return False;
         end if;

         if Last < Text'Last then
            Value := 0;
            End_Last := Last + 1;
            if not Parse_Positive_Number (Last + 2, Text'Last, Value, End_Last) then
               return False;
            end if;
            End_Field := Value;
            if End_Last < Text'Last and then Text (End_Last + 1) = '.' then
               if not Parse_Positive_Number (End_Last + 2, Text'Last, Value, End_Last) then
                  return False;
               end if;
               End_Char := Value;
            end if;
            Last := End_Last;
            Parse_Key_Modifiers;
            if Last /= Text'Last
              or else End_Field < Field
              or else (End_Field = Field and then End_Char > 0 and then End_Char < Char_Start)
            then
               return False;
            end if;
         end if;

         Key :=
           (Field_Start => Field,
            Field_End => End_Field,
            Character_Start => Char_Start,
            Character_End => End_Char,
            Fold_Case => Key_Fold_Case,
            Numeric_Sort => Key_Numeric_Sort,
            Ignore_Leading_Blanks => Key_Ignore_Leading_Blanks,
            Dictionary_Order => Key_Dictionary_Order,
            Ignore_Nonprinting => Key_Ignore_Nonprinting,
            Reverse_Order => Key_Reverse_Order);
         return True;
      end Parse_Sort_Key;
   begin
      for I in 1 .. Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (I);
         begin
            if Skip_Next then
               Skip_Next := False;
            elsif not Parsing_Operands and then Arg = "--" then
               for J in I + 1 .. Context.Argument_Count loop
                  Files.Append (Context.Argument (J));
               end loop;
               exit;
            elsif not Parsing_Operands and then Arg = "-o" then
               if I = Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-o'");
                  return;
               end if;
               Output_Path := To_Unbounded_String (Context.Argument (I + 1));
               Skip_Next := True;
            elsif not Parsing_Operands and then Arg'Length > 2 and then Arg (Arg'First .. Arg'First + 1) = "-o" then
               Output_Path := To_Unbounded_String (Arg (Arg'First + 2 .. Arg'Last));
            elsif not Parsing_Operands and then Arg = "-k" then
               if I = Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-k'");
                  return;
               end if;
               declare
                  Key : Sort_Key_Definition;
               begin
                  if Parse_Sort_Key (Context.Argument (I + 1), Key) then
                     Keys.Append (Key);
                  else
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "invalid operand '" & Context.Argument (I + 1) & "'");
                     return;
                  end if;
               end;
               Skip_Next := True;
            elsif not Parsing_Operands and then Arg'Length > 2 and then Arg (Arg'First .. Arg'First + 1) = "-k" then
               declare
                  Key : Sort_Key_Definition;
                  Key_Text : constant String := Arg (Arg'First + 2 .. Arg'Last);
               begin
                  if Parse_Sort_Key (Key_Text, Key) then
                     Keys.Append (Key);
                  else
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "invalid operand '" & Key_Text & "'");
                     return;
                  end if;
               end;
            elsif not Parsing_Operands and then Arg = "-t" then
               if I = Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-t'");
                  return;
               elsif Context.Argument (I + 1)'Length /= 1 then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Context.Argument (I + 1) & "'");
                  return;
               end if;
               Field_Separator := Context.Argument (I + 1) (Context.Argument (I + 1)'First);
               Has_Field_Separator := True;
               Skip_Next := True;
            elsif not Parsing_Operands and then Arg'Length = 3 and then Arg (Arg'First .. Arg'First + 1) = "-t" then
               Field_Separator := Arg (Arg'Last);
               Has_Field_Separator := True;
            elsif not Parsing_Operands and then Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when 'c' | 'C' => Check_Only := True;
                     when 'b' => Ignore_Leading_Blanks := True;
                     when 'd' => Dictionary_Order := True;
                     when 'f' => Fold_Case := True;
                     when 'i' => Ignore_Nonprinting := True;
                     when 'm' => null;
                     when 'n' => Numeric_Sort := True;
                     when 'r' => Reverse_Order := True;
                     when 's' => Stable_Sort := True;
                     when 'u' => Unique := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                        return;
                  end case;
               end loop;
            else
               Files.Append (Arg);
               Parsing_Operands := True;
            end if;
         end;
      end loop;

      if Files.Length = 0 then
         Text := To_Unbounded_String (Read_Standard_Input (Context));
      else
         for I in 1 .. Natural (Files.Length) loop
            if Files.Element (I) = "-" then
               Append (Text, Read_Standard_Input (Context));
            else
               Append (Text, Read_File (Files.Element (I), Ok));
            end if;
            if not Ok then
               Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
               return;
            end if;
         end loop;
      end if;
      declare
         Lines : String_Vectors.Vector := Lines_Of (To_String (Text));
         Output : Unbounded_String;
         Previous : Unbounded_String;
         First : Boolean := True;
         Written : Boolean;
      begin
         if Check_Only then
            Result.Status :=
              (if Lines_Are_Sorted
                    (Lines,
                     Keys,
                     Fold_Case,
                     Numeric_Sort,
                     Ignore_Leading_Blanks,
                     Reverse_Order,
                     Unique,
                     Stable_Sort,
                     Dictionary_Order,
                     Ignore_Nonprinting,
                     Key_Field,
                     Key_End_Field,
                     Key_Character,
                     Key_End_Character,
                     Field_Separator,
                     Has_Field_Separator,
                     Locale)
               then Posix_Tools.Exit_Status.Success
               else Posix_Tools.Exit_Status.Operational_Failure);
            return;
         end if;

         Sort_Lines
           (Lines,
            Keys,
            Fold_Case,
            Numeric_Sort,
            Ignore_Leading_Blanks,
            Stable_Sort,
            Dictionary_Order,
            Ignore_Nonprinting,
            Key_Field,
            Key_End_Field,
            Key_Character,
            Key_End_Character,
            Field_Separator,
            Has_Field_Separator,
            Locale);
         if Reverse_Order and then Lines.Length > 0 then
            for I in reverse 1 .. Natural (Lines.Length) loop
               if (not Unique)
                 or else First
                 or else not Sort_Keys_Equal
                   (Lines.Element (I),
                    To_String (Previous),
                    Keys,
                    Fold_Case,
                    Ignore_Leading_Blanks,
                    Dictionary_Order,
                    Ignore_Nonprinting,
                    Key_Field,
                    Key_End_Field,
                    Key_Character,
                    Key_End_Character,
                    Field_Separator,
                    Has_Field_Separator,
                    Locale)
               then
                  Append (Output, Lines.Element (I) & LF);
               end if;
               Previous := To_Unbounded_String (Lines.Element (I));
               First := False;
            end loop;
         else
            for Line of Lines loop
               if (not Unique)
                 or else First
                 or else not Sort_Keys_Equal
                   (Line,
                    To_String (Previous),
                    Keys,
                    Fold_Case,
                    Ignore_Leading_Blanks,
                    Dictionary_Order,
                    Ignore_Nonprinting,
                    Key_Field,
                    Key_End_Field,
                    Key_Character,
                    Key_End_Character,
                    Field_Separator,
                    Has_Field_Separator,
                    Locale)
               then
                  Append (Output, Line & LF);
               end if;
               Previous := To_Unbounded_String (Line);
               First := False;
            end loop;
         end if;

         if Length (Output_Path) = 0 then
            Context.Put (To_String (Output));
         else
            Write_File (To_String (Output_Path), To_String (Output), False, Written);
            Ok := Written;
         end if;
      end;
      Set_Success (Context, Result);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run_Sort;

   procedure Run_Tee
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

      function Buffer_Text
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset) return String
      is
         Text : String (1 .. Natural (Last - Buffer'First + 1));
      begin
         for I in Text'Range loop
            Text (I) := Character'Val (Integer (Buffer (Buffer'First + Ada.Streams.Stream_Element_Offset (I - 1))));
         end loop;
         return Text;
      end Buffer_Text;
   begin
      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First)'Length > 1 and then Context.Argument (First) (1) = '-' then
            for Ch of Context.Argument (First) (2 .. Context.Argument (First)'Last) loop
               case Ch is
                  when 'a' => Append_Mode := True;
                  when 'i' => Ignore_Interrupt := True;
                  when others =>
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                     return;
               end case;
            end loop;
            First := First + 1;
         else
            exit;
         end if;
      end loop;
      if Ignore_Interrupt
        and then Posix_Tools.Host_Adapters.Signals.Is_Supported (Posix_Tools.Host_Adapters.Signals.Interrupt)
      then
         if Posix_Tools.Host_Adapters.Signals.Current_Disposition
             (Posix_Tools.Host_Adapters.Signals.Interrupt, Previous_Disposition)
           and then Posix_Tools.Host_Adapters.Signals.Set_Disposition
             (Posix_Tools.Host_Adapters.Signals.Interrupt, Posix_Tools.Host_Adapters.Signals.Ignore_Disposition)
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
               Write_File (Context.Argument (I), "", False, Written);
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
                     Write_File (Context.Argument (I), Data, True, Written);
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
   end Run_Tee;

   procedure Run_Test
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      type Signed_Parse_Status is (Signed_Valid, Signed_Invalid);

      type Signed_Parse_Result is record
         Status : Signed_Parse_Status := Signed_Invalid;
         Value  : Long_Long_Integer := 0;
      end record;

      function Parse_Signed (Text : String) return Signed_Parse_Result is
         First    : Positive := Text'First;
         Negative : Boolean := False;
         Parsed   : Posix_Tools.Numbers.Parse_Result;
      begin
         if Text = "" then
            return (Status => Signed_Invalid, Value => 0);
         elsif Text (First) = '-' or else Text (First) = '+' then
            Negative := Text (First) = '-';
            First := First + 1;
            if First > Text'Last then
               return (Status => Signed_Invalid, Value => 0);
            end if;
         end if;

         Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Text (First .. Text'Last));
         if Parsed.Status /= Posix_Tools.Numbers.Valid then
            return (Status => Signed_Invalid, Value => 0);
         end if;

         if Negative then
            return (Status => Signed_Valid, Value => -Long_Long_Integer (Parsed.Value));
         else
            return (Status => Signed_Valid, Value => Long_Long_Integer (Parsed.Value));
         end if;
      end Parse_Signed;

      function Numeric_Comparison (Left, Op, Right : String) return Boolean is
         A : constant Signed_Parse_Result := Parse_Signed (Left);
         B : constant Signed_Parse_Result := Parse_Signed (Right);
      begin
         if A.Status /= Signed_Valid or else B.Status /= Signed_Valid then
            return False;
         end if;

         return
           (if Op = "-eq" then A.Value = B.Value
            elsif Op = "-ne" then A.Value /= B.Value
            elsif Op = "-gt" then A.Value > B.Value
            elsif Op = "-ge" then A.Value >= B.Value
            elsif Op = "-lt" then A.Value < B.Value
            elsif Op = "-le" then A.Value <= B.Value
            else False);
      end Numeric_Comparison;

      function Evaluate_One (Operand : String) return Boolean is
      begin
         return Operand /= "";
      end Evaluate_One;

      function Evaluate_Three (Left, Op, Right : String) return Boolean is
      begin
         return
           (if Op = "=" then Left = Right
            elsif Op = "!=" then Left /= Right
            elsif Op = "<" then Left < Right
            elsif Op = ">" then Left > Right
            elsif Op = "-ef" then FS.Same_File (Left, Right)
            elsif Op in "-eq" | "-ne" | "-gt" | "-ge" | "-lt" | "-le" then
               Numeric_Comparison (Left, Op, Right)
            else False);
      exception
         when others =>
            return False;
      end Evaluate_Three;

      function Evaluate_Two (Op, Operand : String) return Boolean is
         function Has_Any_Mode_Bit (Mode, Mask : Natural) return Boolean is
            Bit : Natural := 1;
         begin
            while Bit <= 8#400# loop
               if (Mask / Bit) mod 2 = 1 and then (Mode / Bit) mod 2 = 1 then
                  return True;
               end if;
               Bit := Bit * 2;
            end loop;
            return False;
         end Has_Any_Mode_Bit;

         function Terminal_File_Descriptor return Boolean is
         begin
            if Operand = "0" then
               return Context.Standard_Input_Is_Terminal;
            elsif Operand = "1" then
               return Context.Standard_Output_Is_Terminal;
            elsif Operand = "2" then
               return Context.Standard_Error_Is_Terminal;
            else
               return False;
            end if;
         end Terminal_File_Descriptor;
      begin
         if Op = "-e" then
            return FS.Exists (Operand);
         elsif Op = "-h" or else Op = "-L" then
            return FS.Is_Link (Operand);
         elsif Op = "-n" then
            return Operand /= "";
         elsif Op = "-z" then
            return Operand = "";
         elsif Op = "-d" then
            return FS.Kind (Operand) = FS.Directory;
         elsif Op = "-f" then
            return FS.Kind (Operand) = FS.Ordinary_File;
         elsif Op in "-b" | "-c" | "-p" | "-S" then
            declare
               Info : constant FS.Special_File_Info := FS.Special_File_Info_Of (Operand);
            begin
               return Info.Available
                 and then
                   (if Op = "-b" then Info.Kind = FS.Block_Device
                    elsif Op = "-c" then Info.Kind = FS.Character_Device
                    elsif Op = "-p" then Info.Kind = FS.FIFO
                    else Info.Kind = FS.Socket);
            end;
         elsif Op = "-s" then
            return FS.Kind (Operand) = FS.Ordinary_File
              and then FS.Size (Operand) > 0;
         elsif Op = "-t" then
            return Terminal_File_Descriptor;
         elsif Op in "-g" | "-k" | "-u" then
            declare
               Available : Boolean;
               Mode      : constant Natural := FS.File_Permission_Bits (Operand, Available);
               Mask      : constant Natural :=
                 (if Op = "-u" then 8#4000#
                  elsif Op = "-g" then 8#2000#
                  else 8#1000#);
            begin
               return FS.Permissions_Supported
                 and then Available
                 and then (Mode / Mask) mod 2 = 1;
            end;
         elsif Op = "-r" then
            declare
               Ok      : Boolean := False;
               Ignored : constant String := Read_File (Operand, Ok);
            begin
               return Ok;
            end;
         elsif Op = "-w" or else Op = "-x" then
            declare
               Available : Boolean;
               Mode      : constant Natural := FS.File_Permission_Bits (Operand, Available);
               Mask      : constant Natural := (if Op = "-w" then 8#222# else 8#111#);
            begin
               return FS.Permissions_Supported
                 and then Available
                 and then Has_Any_Mode_Bit (Mode, Mask);
            end;
         elsif Op = "!" then
            return not Evaluate_One (Operand);
         else
            return False;
         end if;
      exception
         when others =>
            return False;
      end Evaluate_Two;

      function Is_Binary_Operator (Op : String) return Boolean is
      begin
         return Op in "=" | "!=" | "<" | ">" | "-ef" | "-eq" | "-ne" | "-gt" | "-ge" | "-lt" | "-le";
      end Is_Binary_Operator;

      function Is_Unary_Operator (Op : String) return Boolean is
      begin
         return Op in "-e" | "-h" | "-L" | "-n" | "-z" | "-d" | "-f" | "-s" | "-t"
           | "-b" | "-c" | "-g" | "-k" | "-p" | "-S" | "-u" | "-r" | "-w" | "-x";
      end Is_Unary_Operator;

      function Parentheses_Balanced (First : Positive; Last : Natural) return Boolean is
         Depth : Integer := 0;
      begin
         for I in First .. Last loop
            if Context.Argument (I) = "(" then
               Depth := Depth + 1;
            elsif Context.Argument (I) = ")" then
               Depth := Depth - 1;
               if Depth < 0 then
                  return False;
               end if;
            end if;
         end loop;

         return Depth = 0;
      end Parentheses_Balanced;

      function Evaluate_Range (First : Positive; Last : Natural) return Boolean is
         Count : constant Natural := (if Last < First then 0 else Last - First + 1);
         Depth : Integer;
      begin
         if Count = 0 then
            return False;
         elsif Count >= 3
           and then Context.Argument (First) = "("
           and then Context.Argument (Last) = ")"
         then
            return Evaluate_Range (First + 1, Last - 1);
         end if;

         Depth := 0;
         for I in reverse First .. Last loop
            if Context.Argument (I) = ")" then
               Depth := Depth + 1;
            elsif Context.Argument (I) = "(" then
               Depth := Depth - 1;
            elsif Depth = 0 and then Context.Argument (I) = "-o" then
               return Evaluate_Range (First, I - 1) or else Evaluate_Range (I + 1, Last);
            end if;
         end loop;

         Depth := 0;
         for I in reverse First .. Last loop
            if Context.Argument (I) = ")" then
               Depth := Depth + 1;
            elsif Context.Argument (I) = "(" then
               Depth := Depth - 1;
            elsif Depth = 0 and then Context.Argument (I) = "-a" then
               return Evaluate_Range (First, I - 1) and then Evaluate_Range (I + 1, Last);
            end if;
         end loop;

         if Context.Argument (First) = "!" then
            return not Evaluate_Range (First + 1, Last);
         elsif Count = 1 then
            return Evaluate_One (Context.Argument (First));
         elsif Count = 2 then
            return Evaluate_Two (Context.Argument (First), Context.Argument (Last));
         elsif Count = 3 then
            return Evaluate_Three (Context.Argument (First), Context.Argument (First + 1), Context.Argument (Last));
         else
            return False;
         end if;
      end Evaluate_Range;

      Truth : Boolean;
   begin
      if Context.Argument_Count > 0 and then not Parentheses_Balanced (1, Context.Argument_Count) then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid expression");
         return;
      elsif Context.Argument_Count >= 1
        and then Context.Argument (Context.Argument_Count) in "-a" | "-o" | "!"
      then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid expression");
         return;
      elsif Context.Argument_Count = 2
        and then Context.Argument (1)'Length > 0
        and then Context.Argument (1) (Context.Argument (1)'First) = '-'
        and then not Is_Unary_Operator (Context.Argument (1))
        and then Context.Argument (1) /= "!"
      then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "unknown option '" & Context.Argument (1) & "'");
         return;
      elsif Context.Argument_Count = 3
        and then Context.Argument (1) /= "!"
        and then (Context.Argument (2)'Length > 0
                  and then (Context.Argument (2) (Context.Argument (2)'First) in '-' | '=' | '<' | '>'))
        and then Context.Argument (2) not in "-a" | "-o"
        and then not Is_Binary_Operator (Context.Argument (2))
      then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "unknown operator '" & Context.Argument (2) & "'");
         return;
      end if;

      Truth := Evaluate_Range (1, Context.Argument_Count);
      Result.Status :=
        (if Truth then Posix_Tools.Exit_Status.Success else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Test;

   procedure Run_Touch
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Ok : Boolean := True;
      Written : Boolean;
      Create_Missing : Boolean := True;
      Target_Time : FS.File_Time := FS.Current_File_Time;
      Have_Target_Time : Boolean := False;
      Touch_Access : Boolean := True;
      Touch_Modify : Boolean := True;
      Have_Time_Selector : Boolean := False;
      First : Positive := 1;

      function Decimal_In_Range (Text : String; Low, High : Natural) return Boolean is
         Value : Natural := 0;
      begin
         if Text'Length = 0 or else (for some Ch of Text => Ch not in '0' .. '9') then
            return False;
         end if;
         for Ch of Text loop
            Value := Value * 10 + Character'Pos (Ch) - Character'Pos ('0');
         end loop;
         return Value in Low .. High;
      end Decimal_In_Range;

      function Valid_Touch_Timestamp (Text : String) return Boolean is
         Dot : Natural := 0;
      begin
         for I in Text'Range loop
            if Text (I) = '.' then
               if Dot /= 0 then
                  return False;
               end if;
               Dot := I;
            elsif Text (I) not in '0' .. '9' then
               return False;
            end if;
         end loop;

         declare
            Main_Last : constant Natural := (if Dot = 0 then Text'Last else Dot - 1);
            Main      : constant String := Text (Text'First .. Main_Last);
         begin
            if Dot /= 0
              and then (Dot = Text'Last
                        or else Text'Last - Dot /= 2
                        or else not Decimal_In_Range (Text (Dot + 1 .. Text'Last), 0, 61))
            then
               return False;
            elsif Main'Length not in 8 | 10 | 12 | 14 then
               return False;
            end if;

            return Decimal_In_Range (Main (Main'Last - 7 .. Main'Last - 6), 1, 12)
              and then Decimal_In_Range (Main (Main'Last - 5 .. Main'Last - 4), 1, 31)
              and then Decimal_In_Range (Main (Main'Last - 3 .. Main'Last - 2), 0, 23)
              and then Decimal_In_Range (Main (Main'Last - 1 .. Main'Last), 0, 59);
         end;
      exception
         when Constraint_Error =>
            return False;
      end Valid_Touch_Timestamp;

      function Parse_Touch_Timestamp (Text : String; Parsed : out FS.File_Time) return Boolean is
         Dot : Natural := 0;

         function Two_Digits (Value : String; First : Positive) return Natural is
         begin
            return (Character'Pos (Value (First)) - Character'Pos ('0')) * 10
              + Character'Pos (Value (First + 1)) - Character'Pos ('0');
         end Two_Digits;
      begin
         Parsed := FS.Current_File_Time;
         if not Valid_Touch_Timestamp (Text) then
            return False;
         end if;

         for I in Text'Range loop
            if Text (I) = '.' then
               Dot := I;
               exit;
            end if;
         end loop;

         declare
            Main_Last : constant Natural := (if Dot = 0 then Text'Last else Dot - 1);
            Main      : constant String := Text (Text'First .. Main_Last);
            YY        : Natural;
            Year      : Natural;
            Month     : constant Natural := Two_Digits (Main, Main'Last - 7);
            Day       : constant Natural := Two_Digits (Main, Main'Last - 5);
            Hour      : constant Natural := Two_Digits (Main, Main'Last - 3);
            Minute    : constant Natural := Two_Digits (Main, Main'Last - 1);
            Second    : constant Natural := (if Dot = 0 then 0 else Two_Digits (Text, Dot + 1));
         begin
            if Second > 59 then
               return False;
            end if;

            if Main'Length = 8 then
               Year := Natural (Ada.Calendar.Year (Ada.Calendar.Clock));
            elsif Main'Length = 10 then
               YY := Two_Digits (Main, Main'First);
               Year := (if YY <= 68 then 2000 else 1900) + YY;
            elsif Main'Length = 12 then
               Year := 100 * Two_Digits (Main, Main'First) + Two_Digits (Main, Main'First + 2);
            else
               Year :=
                 1_000 * (Character'Pos (Main (Main'First)) - Character'Pos ('0'))
                 + 100 * (Character'Pos (Main (Main'First + 1)) - Character'Pos ('0'))
                 + 10 * (Character'Pos (Main (Main'First + 2)) - Character'Pos ('0'))
                 + Character'Pos (Main (Main'First + 3)) - Character'Pos ('0');
            end if;

            return FS.File_Time_Of (Year, Month, Day, Hour, Minute, Second, Parsed);
         end;
      exception
         when Constraint_Error =>
            return False;
      end Parse_Touch_Timestamp;

      function Parse_Touch_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean is
         Date_Only : constant Boolean := Text'Length = 10;
         Minute_Precision : constant Boolean := Text'Length = 16;
         Second_Precision : constant Boolean := Text'Length = 19;
         Offset_Minute_Precision : constant Boolean :=
           (Text'Length in 17 | 19 | 21 | 22)
           and then (Text (Text'First + 16) = 'Z'
                     or else Text (Text'First + 16) in '+' | '-');
         Offset_Second_Precision : constant Boolean :=
           (Text'Length in 20 | 22 | 24 | 25)
           and then (Text (Text'First + 19) = 'Z'
                     or else Text (Text'First + 19) in '+' | '-');
         Offset_Precision : constant Boolean := Offset_Minute_Precision or else Offset_Second_Precision;
         Date_Time_Last : constant Natural :=
           (if Offset_Second_Precision then Text'First + 18
            elsif Offset_Minute_Precision then Text'First + 15
            else Text'Last);
         Offset_Minutes : Integer := 0;

         function Touch_Two_Digits (First : Positive) return Natural is
         begin
            return (Character'Pos (Text (First)) - Character'Pos ('0')) * 10
              + Character'Pos (Text (First + 1)) - Character'Pos ('0');
         end Touch_Two_Digits;

         function Touch_Four_Digits (First : Positive) return Natural is
         begin
            return Touch_Two_Digits (First) * 100 + Touch_Two_Digits (First + 2);
         end Touch_Four_Digits;

         function Parse_Offset (First : Positive; Minutes : out Integer) return Boolean is
            Sign : Integer := 1;
            Hour : Natural;
            Minute : Natural := 0;
         begin
            Minutes := 0;
            if Text (First) = 'Z' then
               return First = Text'Last;
            elsif Text (First) = '-' then
               Sign := -1;
            elsif Text (First) /= '+' then
               return False;
            end if;

            if Text'Last - First = 2 then
               if not Decimal_In_Range (Text (First + 1 .. First + 2), 0, 23) then
                  return False;
               end if;
               Hour := Touch_Two_Digits (First + 1);
            elsif Text'Last - First = 4 then
               if not Decimal_In_Range (Text (First + 1 .. First + 2), 0, 23)
                 or else not Decimal_In_Range (Text (First + 3 .. First + 4), 0, 59)
               then
                  return False;
               end if;
               Hour := Touch_Two_Digits (First + 1);
               Minute := Touch_Two_Digits (First + 3);
            elsif Text'Last - First = 5 and then Text (First + 3) = ':' then
               if not Decimal_In_Range (Text (First + 1 .. First + 2), 0, 23)
                 or else not Decimal_In_Range (Text (First + 4 .. First + 5), 0, 59)
               then
                  return False;
               end if;
               Hour := Touch_Two_Digits (First + 1);
               Minute := Touch_Two_Digits (First + 4);
            else
               return False;
            end if;

            Minutes := Sign * Integer (Hour * 60 + Minute);
            return True;
         end Parse_Offset;
      begin
         Parsed := FS.Current_File_Time;
         if not (Date_Only or else Minute_Precision or else Second_Precision or else Offset_Precision)
           or else Text (Text'First + 4) /= '-'
           or else Text (Text'First + 7) /= '-'
           or else ((Minute_Precision or else Second_Precision or else Offset_Precision)
                    and then Text (Text'First + 10) not in 'T' | ' ')
           or else ((Minute_Precision or else Second_Precision or else Offset_Precision)
                    and then Text (Text'First + 13) /= ':')
           or else ((Second_Precision or else Offset_Second_Precision) and then Text (Text'First + 16) /= ':')
         then
            return False;
         end if;

         for I in Text'First .. Date_Time_Last loop
            if I not in Text'First + 4 | Text'First + 7 | Text'First + 10 | Text'First + 13 | Text'First + 16
              and then Text (I) not in '0' .. '9'
            then
               return False;
            end if;
         end loop;

         if not Decimal_In_Range (Text (Text'First + 5 .. Text'First + 6), 1, 12)
           or else not Decimal_In_Range (Text (Text'First + 8 .. Text'First + 9), 1, 31)
           or else ((Minute_Precision or else Second_Precision or else Offset_Precision)
                    and then not Decimal_In_Range (Text (Text'First + 11 .. Text'First + 12), 0, 23))
           or else ((Minute_Precision or else Second_Precision or else Offset_Precision)
                    and then not Decimal_In_Range (Text (Text'First + 14 .. Text'First + 15), 0, 59))
           or else ((Second_Precision or else Offset_Second_Precision)
                    and then not Decimal_In_Range (Text (Text'First + 17 .. Text'First + 18), 0, 59))
           or else (Offset_Second_Precision
                    and then not Parse_Offset (Text'First + 19, Offset_Minutes))
           or else (Offset_Minute_Precision
                    and then not Parse_Offset (Text'First + 16, Offset_Minutes))
         then
            return False;
         end if;

         if Offset_Precision and then Offset_Minutes /= 0 then
            declare
               Normalized : constant Ada.Calendar.Time :=
                 Ada.Calendar.Time_Of
                   (Ada.Calendar.Year_Number (Touch_Four_Digits (Text'First)),
                    Ada.Calendar.Month_Number (Touch_Two_Digits (Text'First + 5)),
                    Ada.Calendar.Day_Number (Touch_Two_Digits (Text'First + 8)),
                    Duration
                      (Touch_Two_Digits (Text'First + 11) * 3_600
                       + Touch_Two_Digits (Text'First + 14) * 60
                       + (if Offset_Second_Precision then Touch_Two_Digits (Text'First + 17) else 0))
                    - Duration (Offset_Minutes * 60));
               Year : Ada.Calendar.Year_Number;
               Month : Ada.Calendar.Month_Number;
               Day : Ada.Calendar.Day_Number;
               Seconds : Duration;
            begin
               Ada.Calendar.Split (Normalized, Year, Month, Day, Seconds);
               return FS.File_Time_Of
                 (Natural (Year),
                  Natural (Month),
                  Natural (Day),
                  Natural (Seconds) / 3_600,
                  (Natural (Seconds) mod 3_600) / 60,
                  Natural (Seconds) mod 60,
                  Parsed);
            end;
         else
            return FS.File_Time_Of
              (Touch_Four_Digits (Text'First),
               Touch_Two_Digits (Text'First + 5),
               Touch_Two_Digits (Text'First + 8),
               (if Date_Only then 0 else Touch_Two_Digits (Text'First + 11)),
               (if Date_Only then 0 else Touch_Two_Digits (Text'First + 14)),
               (if Second_Precision or else Offset_Second_Precision
                then Touch_Two_Digits (Text'First + 17)
                else 0),
               Parsed);
         end if;
      exception
         when Constraint_Error =>
            return False;
      end Parse_Touch_Date_Time;

      function Parse_Touch_Normalized_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean is
         Normalized : Unbounded_String;
         Changed    : Boolean := False;
         I          : Positive := Text'First;
      begin
         Parsed := FS.Current_File_Time;
         if Text = "" then
            return False;
         end if;

         while I <= Text'Last loop
            if (I = Text'First + 4 or else I = Text'First + 7) and then Text (I) = '/' then
               Append (Normalized, '-');
               Changed := True;
               I := I + 1;
            elsif I = Text'First + 10 and then Text (I) = 't' then
               Append (Normalized, 'T');
               Changed := True;
               I := I + 1;
            elsif I = Text'First + 19 and then Text (I) = '.' then
               Changed := True;
               I := I + 1;
               if I > Text'Last or else Text (I) not in '0' .. '9' then
                  return False;
               end if;
               while I <= Text'Last and then Text (I) in '0' .. '9' loop
                  I := I + 1;
               end loop;
            else
               Append (Normalized, Text (I));
               I := I + 1;
            end if;
         end loop;

         return Changed and then Parse_Touch_Date_Time (To_String (Normalized), Parsed);
      exception
         when Constraint_Error =>
            return False;
      end Parse_Touch_Normalized_Date_Time;

      function Parse_Touch_Month_Name_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean is
         Tokens : String_Vectors.Vector;

         function Lowered (Value : String) return String is
            Result : String := Value;
         begin
            for I in Result'Range loop
               if Result (I) in 'A' .. 'Z' then
                  Result (I) := Character'Val
                    (Character'Pos (Result (I)) - Character'Pos ('A') + Character'Pos ('a'));
               end if;
            end loop;
            return Result;
         end Lowered;

         function Decimal_Value (Value : String; Low, High : Natural; Result : out Natural) return Boolean is
         begin
            Result := 0;
            if Value = "" or else (for some Ch of Value => Ch not in '0' .. '9') then
               return False;
            end if;
            for Ch of Value loop
               if Result > (Natural'Last - (Character'Pos (Ch) - Character'Pos ('0'))) / 10 then
                  return False;
               end if;
               Result := Result * 10 + Character'Pos (Ch) - Character'Pos ('0');
            end loop;
            return Result in Low .. High;
         end Decimal_Value;

         function Month_Number (Value : String) return Natural is
            Name : constant String := Lowered (Value);
         begin
            if Name in "jan" | "january" then
               return 1;
            elsif Name in "feb" | "february" then
               return 2;
            elsif Name in "mar" | "march" then
               return 3;
            elsif Name in "apr" | "april" then
               return 4;
            elsif Name = "may" then
               return 5;
            elsif Name in "jun" | "june" then
               return 6;
            elsif Name in "jul" | "july" then
               return 7;
            elsif Name in "aug" | "august" then
               return 8;
            elsif Name in "sep" | "sept" | "september" then
               return 9;
            elsif Name in "oct" | "october" then
               return 10;
            elsif Name in "nov" | "november" then
               return 11;
            elsif Name in "dec" | "december" then
               return 12;
            else
               return 0;
            end if;
         end Month_Number;

         function Without_Trailing_Comma (Value : String) return String is
         begin
            if Value'Length > 0 and then Value (Value'Last) = ',' then
               return Value (Value'First .. Value'Last - 1);
            else
               return Value;
            end if;
         end Without_Trailing_Comma;

         function Parse_Time (Value : String; Hour, Minute, Second : out Natural) return Boolean is
            First_Colon  : Natural := 0;
            Second_Colon : Natural := 0;
         begin
            Hour := 0;
            Minute := 0;
            Second := 0;
            for I in Value'Range loop
               if Value (I) = ':' then
                  if First_Colon = 0 then
                     First_Colon := I;
                  elsif Second_Colon = 0 then
                     Second_Colon := I;
                  else
                     return False;
                  end if;
               elsif Value (I) not in '0' .. '9' then
                  return False;
               end if;
            end loop;

            if First_Colon = 0 then
               return False;
            elsif not Decimal_Value (Value (Value'First .. First_Colon - 1), 0, 23, Hour) then
               return False;
            elsif Second_Colon = 0 then
               return Decimal_Value (Value (First_Colon + 1 .. Value'Last), 0, 59, Minute);
            else
               return Decimal_Value (Value (First_Colon + 1 .. Second_Colon - 1), 0, 59, Minute)
                 and then Decimal_Value (Value (Second_Colon + 1 .. Value'Last), 0, 59, Second);
            end if;
         end Parse_Time;

         procedure Tokenize is
            Start : Positive := Text'First;
         begin
            while Start <= Text'Last loop
               while Start <= Text'Last and then Text (Start) in ' ' | Character'Val (9) loop
                  Start := Start + 1;
               end loop;
               exit when Start > Text'Last;
               declare
                  Stop : Natural := Start;
               begin
                  while Stop <= Text'Last and then Text (Stop) not in ' ' | Character'Val (9) loop
                     Stop := Stop + 1;
                  end loop;
                  Tokens.Append (Text (Start .. Stop - 1));
                  Start := Stop + 1;
               end;
            end loop;
         end Tokenize;
      begin
         Parsed := FS.Current_File_Time;
         if Text = "" then
            return False;
         end if;

         Tokenize;
         if Natural (Tokens.Length) not in 3 | 4 then
            return False;
         end if;

         declare
            First_Month  : constant Natural := Month_Number (Tokens.Element (1));
            Second_Month : constant Natural :=
              (if Natural (Tokens.Length) >= 2 then Month_Number (Tokens.Element (2)) else 0);
            Month  : Natural;
            Day    : Natural;
            Year   : Natural;
            Hour   : Natural := 0;
            Minute : Natural := 0;
            Second : Natural := 0;
         begin
            if First_Month /= 0 then
               Month := First_Month;
               if not Decimal_Value (Without_Trailing_Comma (Tokens.Element (2)), 1, 31, Day) then
                  return False;
               end if;
            elsif Second_Month /= 0 then
               Month := Second_Month;
               if not Decimal_Value (Without_Trailing_Comma (Tokens.Element (1)), 1, 31, Day) then
                  return False;
               end if;
            else
               return False;
            end if;

            if not Decimal_Value (Tokens.Element (3), 1901, 2399, Year)
              or else (Natural (Tokens.Length) = 4 and then not Parse_Time (Tokens.Element (4), Hour, Minute, Second))
            then
               return False;
            end if;

            return FS.File_Time_Of (Year, Month, Day, Hour, Minute, Second, Parsed);
         end;
      exception
         when Constraint_Error =>
            return False;
      end Parse_Touch_Month_Name_Date_Time;

      function Parse_Touch_Free_Form_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean is
         Tokens : String_Vectors.Vector;

         function Lowered (Value : String) return String is
            Result : String := Value;
         begin
            for I in Result'Range loop
               if Result (I) in 'A' .. 'Z' then
                  Result (I) := Character'Val
                    (Character'Pos (Result (I)) - Character'Pos ('A') + Character'Pos ('a'));
               end if;
            end loop;
            return Result;
         end Lowered;

         function Decimal_Value (Value : String; Result : out Natural) return Boolean is
         begin
            Result := 0;
            if Value = "" or else (for some Ch of Value => Ch not in '0' .. '9') then
               return False;
            end if;
            for Ch of Value loop
               if Result > (Natural'Last - (Character'Pos (Ch) - Character'Pos ('0'))) / 10 then
                  return False;
               end if;
               Result := Result * 10 + Character'Pos (Ch) - Character'Pos ('0');
            end loop;
            return True;
         end Decimal_Value;

         function Unit_Seconds (Unit : String) return Long_Long_Integer is
            Name : constant String := Lowered (Unit);
         begin
            if Name in "second" | "seconds" | "sec" | "secs" then
               return 1;
            elsif Name in "minute" | "minutes" | "min" | "mins" then
               return 60;
            elsif Name in "hour" | "hours" then
               return 3_600;
            elsif Name in "day" | "days" then
               return 86_400;
            elsif Name in "week" | "weeks" then
               return 604_800;
            else
               return 0;
            end if;
         end Unit_Seconds;

         function Weekday_Number (Name : String) return Natural is
            Lower : constant String := Lowered (Name);
         begin
            if Lower in "mon" | "monday" then
               return 1;
            elsif Lower in "tue" | "tues" | "tuesday" then
               return 2;
            elsif Lower in "wed" | "wednesday" then
               return 3;
            elsif Lower in "thu" | "thur" | "thurs" | "thursday" then
               return 4;
            elsif Lower in "fri" | "friday" then
               return 5;
            elsif Lower in "sat" | "saturday" then
               return 6;
            elsif Lower in "sun" | "sunday" then
               return 7;
            else
               return 0;
            end if;
         end Weekday_Number;

         function Today_At (Seconds : Duration) return Ada.Calendar.Time is
            Now : constant Ada.Calendar.Time := Ada.Calendar.Clock;
            Year : Ada.Calendar.Year_Number;
            Month : Ada.Calendar.Month_Number;
            Day : Ada.Calendar.Day_Number;
            Ignored : Duration;
         begin
            Ada.Calendar.Split (Now, Year, Month, Day, Ignored);
            return Ada.Calendar.Time_Of (Year, Month, Day, Seconds);
         end Today_At;

         function Calendar_To_File_Time (Value : Ada.Calendar.Time) return Boolean is
            Year : Ada.Calendar.Year_Number;
            Month : Ada.Calendar.Month_Number;
            Day : Ada.Calendar.Day_Number;
            Seconds : Duration;
            Whole : Natural;
         begin
            Ada.Calendar.Split (Value, Year, Month, Day, Seconds);
            Whole := Natural (Seconds);
            return FS.File_Time_Of
              (Natural (Year),
               Natural (Month),
               Natural (Day),
               Whole / 3_600,
               (Whole mod 3_600) / 60,
               Whole mod 60,
               Parsed);
         end Calendar_To_File_Time;

         procedure Tokenize is
            Start : Positive := Text'First;
         begin
            while Start <= Text'Last loop
               while Start <= Text'Last and then Text (Start) in ' ' | Character'Val (9) loop
                  Start := Start + 1;
               end loop;
               exit when Start > Text'Last;
               declare
                  Stop : Natural := Start;
               begin
                  while Stop <= Text'Last and then Text (Stop) not in ' ' | Character'Val (9) loop
                     Stop := Stop + 1;
                  end loop;
                  Tokens.Append (Text (Start .. Stop - 1));
                  Start := Stop + 1;
               end;
            end loop;
         end Tokenize;
      begin
         Parsed := FS.Current_File_Time;
         if Text = "" then
            return False;
         end if;

         Tokenize;
         if Natural (Tokens.Length) = 0 then
            return False;
         end if;

         declare
            First : constant String := Lowered (Tokens.Element (1));
         begin
            if Natural (Tokens.Length) = 1 then
               if First = "now" then
                  Parsed := FS.Current_File_Time;
                  return True;
               elsif First = "today" then
                  return Calendar_To_File_Time (Today_At (0.0));
               elsif First = "yesterday" then
                  return Calendar_To_File_Time (Today_At (0.0) - 86_400.0);
               elsif First = "tomorrow" then
                  return Calendar_To_File_Time (Today_At (0.0) + 86_400.0);
               elsif First = "noon" then
                  return Calendar_To_File_Time (Today_At (12.0 * 3_600.0));
               elsif First = "midnight" then
                  return Calendar_To_File_Time (Today_At (0.0));
               end if;
            elsif Natural (Tokens.Length) = 2 and then First in "next" | "last" then
               declare
                  Target : constant Natural := Weekday_Number (Tokens.Element (2));
                  Now_Day : constant Natural :=
                    (case Ada.Calendar.Formatting.Day_Of_Week (Ada.Calendar.Clock) is
                       when Ada.Calendar.Formatting.Monday => 1,
                       when Ada.Calendar.Formatting.Tuesday => 2,
                       when Ada.Calendar.Formatting.Wednesday => 3,
                       when Ada.Calendar.Formatting.Thursday => 4,
                       when Ada.Calendar.Formatting.Friday => 5,
                       when Ada.Calendar.Formatting.Saturday => 6,
                       when Ada.Calendar.Formatting.Sunday => 7);
                  Day_Offset : Integer;
               begin
                  if Target = 0 then
                     return False;
                  end if;

                  if First = "next" then
                     Day_Offset := Integer (Target) - Integer (Now_Day);
                     if Day_Offset <= 0 then
                        Day_Offset := Day_Offset + 7;
                     end if;
                  else
                     Day_Offset := Integer (Target) - Integer (Now_Day);
                     if Day_Offset >= 0 then
                        Day_Offset := Day_Offset - 7;
                     end if;
                  end if;

                  return Calendar_To_File_Time (Today_At (0.0) + Duration (Day_Offset * 86_400));
               end;
            elsif Natural (Tokens.Length) = 2 and then First'Length >= 2 and then First (First'First) in '+' | '-' then
               declare
                  Count : Natural;
                  Sign : constant Long_Long_Integer := (if First (First'First) = '-' then -1 else 1);
                  Unit : constant Long_Long_Integer := Unit_Seconds (Tokens.Element (2));
               begin
                  if Unit = 0
                    or else not Decimal_Value (First (First'First + 1 .. First'Last), Count)
                  then
                     return False;
                  end if;

                  return Calendar_To_File_Time
                    (Ada.Calendar.Clock + Duration (Sign * Long_Long_Integer (Count) * Unit));
               end;
            elsif Natural (Tokens.Length) = 3 and then Lowered (Tokens.Element (3)) = "ago" then
               declare
                  Count : Natural;
                  Unit : constant Long_Long_Integer := Unit_Seconds (Tokens.Element (2));
               begin
                  if Unit = 0 or else not Decimal_Value (Tokens.Element (1), Count) then
                     return False;
                  end if;

                  return Calendar_To_File_Time
                    (Ada.Calendar.Clock - Duration (Long_Long_Integer (Count) * Unit));
               end;
            end if;
         end;

         return False;
      exception
         when Constraint_Error =>
            return False;
      end Parse_Touch_Free_Form_Date_Time;

      procedure Select_Reference_Time (Reference : String; Selected : out Boolean) is
      begin
         Selected := False;
         if not FS.Exists (Reference) then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Reference, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Ok := False;
         else
            if FS.File_Time_From_File (Reference, Target_Time) then
               Have_Target_Time := True;
               Selected := True;
            else
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Reference, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               Ok := False;
            end if;
         end if;
      exception
         when others =>
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Reference, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Ok := False;
      end Select_Reference_Time;

      procedure Select_Explicit_Time (Timestamp : String; Selected : out Boolean) is
      begin
         if Parse_Touch_Timestamp (Timestamp, Target_Time) then
            Have_Target_Time := True;
            Selected := True;
         else
            Selected := False;
         end if;
      end Select_Explicit_Time;

      procedure Select_Date_Time (Timestamp : String; Selected : out Boolean) is
      begin
         if Parse_Touch_Timestamp (Timestamp, Target_Time)
           or else Parse_Touch_Date_Time (Timestamp, Target_Time)
           or else Parse_Touch_Normalized_Date_Time (Timestamp, Target_Time)
           or else Parse_Touch_Month_Name_Date_Time (Timestamp, Target_Time)
           or else Parse_Touch_Free_Form_Date_Time (Timestamp, Target_Time)
         then
            Have_Target_Time := True;
            Selected := True;
         else
            Selected := False;
         end if;
      end Select_Date_Time;

      procedure Apply_Touch (Path : String) is
         procedure Apply_Selected_Time (Time : FS.File_Time) is
            Access_Time       : FS.File_Time := Time;
            Modification_Time : FS.File_Time := Time;
         begin
            if not Touch_Access and then not FS.File_Access_Time_From_File (Path, Access_Time) then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               return;
            end if;

            if not Touch_Modify and then not FS.File_Time_From_File (Path, Modification_Time) then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               return;
            end if;

            if not FS.Set_File_Times (Path, Access_Time, Modification_Time) then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            end if;
         end Apply_Selected_Time;
      begin
         if FS.Exists (Path) then
            if Have_Target_Time then
               Apply_Selected_Time (Target_Time);
            elsif not Touch_Access or else not Touch_Modify then
               Apply_Selected_Time (FS.Current_File_Time);
            elsif FS.Kind (Path) = FS.Ordinary_File then
               declare
                  File_Ok : Boolean;
                  Data : constant String := Read_File (Path, File_Ok);
               begin
                  if File_Ok then
                     Write_File (Path, Data, False, Written);
                     Ok := Ok and Written;
                  else
                     Ok := False;
                  end if;
               end;
            else
               Apply_Selected_Time (FS.Current_File_Time);
            end if;
         elsif Create_Missing then
            Write_File (Path, "", False, Written);
            Ok := Ok and Written;
            if Written then
               if Have_Target_Time then
                  Apply_Selected_Time (Target_Time);
               elsif not Touch_Access or else not Touch_Modify then
                  Apply_Selected_Time (FS.Current_File_Time);
               end if;
            end if;
         end if;
      end Apply_Touch;
   begin
      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First) = "-t" then
            if First = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-t'");
               return;
            end if;
            declare
               Selected : Boolean;
            begin
               Select_Explicit_Time (Context.Argument (First + 1), Selected);
               if not Selected then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid timestamp '" & Context.Argument (First + 1) & "'");
                  return;
               end if;
            end;
            First := First + 2;
         elsif Context.Argument (First) = "-d" then
            if First = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-d'");
               return;
            end if;
            declare
               Selected : Boolean;
            begin
               Select_Date_Time (Context.Argument (First + 1), Selected);
               if not Selected then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid timestamp '" & Context.Argument (First + 1) & "'");
                  return;
               end if;
            end;
            First := First + 2;
         elsif Context.Argument (First) = "-r" then
            if First = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-r'");
               return;
            end if;
            declare
               Selected : Boolean;
            begin
               Select_Reference_Time (Context.Argument (First + 1), Selected);
               if not Selected then
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                  return;
               end if;
            end;
            First := First + 2;
         elsif Context.Argument (First)'Length > 1 and then Context.Argument (First) (1) = '-' then
            for Ch of Context.Argument (First) (2 .. Context.Argument (First)'Last) loop
               case Ch is
                  when 'a' =>
                     if not Have_Time_Selector then
                        Touch_Modify := False;
                        Have_Time_Selector := True;
                     end if;
                     Touch_Access := True;
                  when 'm' =>
                     if not Have_Time_Selector then
                        Touch_Access := False;
                        Have_Time_Selector := True;
                     end if;
                     Touch_Modify := True;
                  when 'c' =>
                     Create_Missing := False;
                  when 'd' =>
                     if Context.Argument (First)'Length > 2 then
                        declare
                           Timestamp : constant String :=
                             Context.Argument (First)
                               (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last);
                           Selected : Boolean;
                        begin
                           Select_Date_Time (Timestamp, Selected);
                           if not Selected then
                              Posix_Tools.Commands.Helpers.Usage_Error
                                (Context, Result, "invalid timestamp '" & Timestamp & "'");
                              return;
                           end if;
                        end;
                        exit;
                     elsif First = Context.Argument_Count then
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-d'");
                        return;
                     else
                        declare
                           Selected : Boolean;
                        begin
                           Select_Date_Time (Context.Argument (First + 1), Selected);
                           if not Selected then
                              Posix_Tools.Commands.Helpers.Usage_Error
                                (Context, Result, "invalid timestamp '" & Context.Argument (First + 1) & "'");
                              return;
                           end if;
                        end;
                        First := First + 1;
                        exit;
                     end if;
                  when 'r' =>
                     if Context.Argument (First)'Length > 2 then
                        declare
                           Reference : constant String :=
                             Context.Argument (First)
                               (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last);
                           Selected : Boolean;
                        begin
                           Select_Reference_Time (Reference, Selected);
                           if not Selected then
                              Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                              return;
                           end if;
                        end;
                        exit;
                     elsif First = Context.Argument_Count then
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-r'");
                        return;
                     else
                        declare
                           Selected : Boolean;
                        begin
                           Select_Reference_Time (Context.Argument (First + 1), Selected);
                           if not Selected then
                              Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                              return;
                           end if;
                        end;
                        First := First + 1;
                        exit;
                     end if;
                  when 't' =>
                     if Context.Argument (First)'Length > 2 then
                        declare
                           Timestamp : constant String :=
                             Context.Argument (First)
                               (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last);
                           Selected : Boolean;
                        begin
                           Select_Explicit_Time (Timestamp, Selected);
                           if not Selected then
                              Posix_Tools.Commands.Helpers.Usage_Error
                                (Context, Result, "invalid timestamp '" & Timestamp & "'");
                              return;
                           end if;
                        end;
                        exit;
                     elsif First = Context.Argument_Count then
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-t'");
                        return;
                     else
                        declare
                           Selected : Boolean;
                        begin
                           Select_Explicit_Time (Context.Argument (First + 1), Selected);
                           if not Selected then
                              Posix_Tools.Commands.Helpers.Usage_Error
                                (Context, Result, "invalid timestamp '" & Context.Argument (First + 1) & "'");
                              return;
                           end if;
                        end;
                        First := First + 1;
                        exit;
                     end if;
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

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;
      for I in First .. Context.Argument_Count loop
         begin
            Apply_Touch (Context.Argument (I));
         exception
            when others =>
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Context.Argument (I), "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end;
      end loop;
      Result.Status :=
        (if Ok then Posix_Tools.Exit_Status.Success else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Touch;

   procedure Run_Tr
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Delete_Mode : Boolean := False;
      Complement  : Boolean := False;
      Squeeze     : Boolean := False;
      First       : Positive := 1;
      Data        : constant String := Read_Standard_Input (Context);
      Output      : Unbounded_String;
   begin
      while First <= Context.Argument_Count
        and then Context.Argument (First)'Length > 1
        and then Context.Argument (First) (Context.Argument (First)'First) = '-'
      loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         end if;

         for Ch of Context.Argument (First) (Context.Argument (First)'First + 1 .. Context.Argument (First)'Last) loop
            case Ch is
               when 'c' | 'C' => Complement := True;
               when 'd' => Delete_Mode := True;
               when 's' => Squeeze := True;
               when others =>
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                  return;
            end case;
         end loop;
         First := First + 1;
      end loop;
      if (Delete_Mode and then Squeeze and then Context.Argument_Count /= First + 1)
        or else (Delete_Mode and then (not Squeeze) and then Context.Argument_Count /= First)
        or else ((not Delete_Mode) and then Squeeze and then Context.Argument_Count not in First | First + 1)
        or else ((not Delete_Mode) and then (not Squeeze) and then Context.Argument_Count /= First + 1)
      then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      declare
         Locale : constant String := Context.Effective_Locale;
         Set1   : constant String := Expanded_Translation_Set (Context.Argument (First), Locale);
         Set2 : constant String :=
           (if (Delete_Mode and then Squeeze) or else ((not Delete_Mode) and then Context.Argument_Count = First + 1)
            then Expanded_Translation_Set (Context.Argument (First + 1), Locale)
            else "");
         Squeeze_Set : constant String :=
           (if Squeeze and then Set2 /= "" then Set2 elsif Squeeze then Set1 else "");
         Complement_Order : constant String := Locale_Collation_Order (Locale, Set1);
         Previous : Character := Character'Val (0);
         Have_Previous : Boolean := False;

         function In_Set (Set : String; Ch : Character) return Boolean is
         begin
            return (for some Item of Set => Item = Ch);
         end In_Set;

         function Complement_Position (Ch : Character) return Natural is
         begin
            for I in Complement_Order'Range loop
               if Complement_Order (I) = Ch then
                  return I - Complement_Order'First + 1;
               end if;
            end loop;
            return 0;
         end Complement_Position;

         procedure Append_Translated (Ch : Character) is
         begin
            if Squeeze
              and then Have_Previous
              and then Ch = Previous
              and then In_Set (Squeeze_Set, Ch)
            then
               return;
            end if;

            Append (Output, Ch);
            Previous := Ch;
            Have_Previous := True;
         end Append_Translated;
      begin
         for Ch of Data loop
            declare
               Index : Natural := 0;
               In_Original_Set : Boolean := False;
               Effective_Match : Boolean;
            begin
               for I in Set1'Range loop
                  if Set1 (I) = Ch then
                     Index := I - Set1'First + 1;
                     In_Original_Set := True;
                  end if;
               end loop;
               if Complement and then not In_Original_Set then
                  Index := Complement_Position (Ch);
               end if;
               Effective_Match := (if Complement then not In_Original_Set else In_Original_Set);
               if Delete_Mode then
                  if not Effective_Match then
                     Append_Translated (Ch);
                  end if;
               elsif Effective_Match and then Set2 /= "" then
                  declare
                     Pos : constant Natural := Natural'Min (Index, Set2'Length);
                  begin
                     Append_Translated (Set2 (Set2'First + Pos - 1));
                  end;
               else
                  Append_Translated (Ch);
               end if;
            end;
         end loop;
      end;
      Context.Put (To_String (Output));
      Set_Success (Context, Result);
      if Context.Output_Failed then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run_Tr;

   procedure Run_Uniq
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Files       : String_Vectors.Vector;
      Counts      : Boolean := False;
      Duplicates  : Boolean := False;
      Fold_Case   : Boolean := False;
      Unique_Only : Boolean := False;
      Skip_Fields : Natural := 0;
      Skip_Chars  : Natural := 0;
      Ok          : Boolean := True;
      Skip_Next   : Boolean := False;
      Parsing_Operands : Boolean := False;

      function Comparison_Key (Line : String) return String is
         Position : Natural := Line'First;

         function Is_Field_Separator_At (Index : Positive; Width : out Natural) return Boolean is
            Decoder    : Posix_Tools.Text.UTF_8.Decoder;
            Status     : Posix_Tools.Text.UTF_8.Decode_Status;
            Code_Point : Long_Long_Integer;
         begin
            Width := 1;
            for I in Index .. Line'Last loop
               Posix_Tools.Text.UTF_8.Decode
                 (Decoder, Character'Pos (Line (I)), Status, Code_Point);
               if Status = Posix_Tools.Text.UTF_8.Complete then
                  Width := I - Index + 1;
                  return Posix_Tools.Text.Classification.Is_Whitespace (Code_Point);
               elsif Status = Posix_Tools.Text.UTF_8.Invalid then
                  Width := 1;
                  return Line (Index) = ' ' or else Line (Index) = Character'Val (9);
               end if;
            end loop;

            return Line (Index) = ' ' or else Line (Index) = Character'Val (9);
         end Is_Field_Separator_At;

         procedure Advance_Character is
            Decoder    : Posix_Tools.Text.UTF_8.Decoder;
            Status     : Posix_Tools.Text.UTF_8.Decode_Status;
            Code_Point : Long_Long_Integer;
         begin
            if Position > Line'Last then
               return;
            end if;

            for I in Position .. Line'Last loop
               Posix_Tools.Text.UTF_8.Decode
                 (Decoder, Character'Pos (Line (I)), Status, Code_Point);
               if Status = Posix_Tools.Text.UTF_8.Complete then
                  Position := I + 1;
                  return;
               elsif Status = Posix_Tools.Text.UTF_8.Invalid then
                  Position := Position + 1;
                  return;
               end if;
            end loop;

            Position := Position + 1;
         end Advance_Character;
      begin
         for Field in 1 .. Skip_Fields loop
            while Position <= Line'Last loop
               declare
                  Width : Natural;
               begin
                  exit when not Is_Field_Separator_At (Position, Width);
                  Position := Position + Width;
               end;
            end loop;

            while Position <= Line'Last loop
               declare
                  Width : Natural;
               begin
                  exit when Is_Field_Separator_At (Position, Width);
                  Position := Position + Width;
               end;
            end loop;
         end loop;

         for Ch in 1 .. Skip_Chars loop
            exit when Position > Line'Last;
            Advance_Character;
         end loop;

         if Position > Line'Last then
            return "";
         else
            declare
               Text_Key : constant String :=
                 (if Fold_Case then Folded_Sort_Text (Line (Position .. Line'Last))
                  else Line (Position .. Line'Last));
            begin
               return Locale_Sort_Text (Context.Effective_Locale, Text_Key);
            end;
         end if;
      end Comparison_Key;
   begin
      for I in 1 .. Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (I);
         begin
            if Skip_Next then
               Skip_Next := False;
            elsif not Parsing_Operands and then Arg = "--" then
               for J in I + 1 .. Context.Argument_Count loop
                  Files.Append (Context.Argument (J));
               end loop;
               exit;
            elsif not Parsing_Operands and then Arg = "-f" then
               if I = Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-f'");
                  return;
               end if;
               if not Parse_Natural_Operand
                 (Context, Result, Context.Argument (I + 1), "field count", Skip_Fields)
               then
                  return;
               end if;
               Skip_Next := True;
            elsif not Parsing_Operands and then Arg'Length > 2 and then Arg (Arg'First .. Arg'First + 1) = "-f" then
               if not Parse_Natural_Operand
                 (Context, Result, Arg (Arg'First + 2 .. Arg'Last), "field count", Skip_Fields)
               then
                  return;
               end if;
            elsif not Parsing_Operands and then Arg = "-s" then
               if I = Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-s'");
                  return;
               end if;
               if not Parse_Natural_Operand
                 (Context, Result, Context.Argument (I + 1), "character count", Skip_Chars)
               then
                  return;
               end if;
               Skip_Next := True;
            elsif not Parsing_Operands and then Arg'Length > 2 and then Arg (Arg'First .. Arg'First + 1) = "-s" then
               if not Parse_Natural_Operand
                 (Context, Result, Arg (Arg'First + 2 .. Arg'Last), "character count", Skip_Chars)
               then
                  return;
               end if;
            elsif not Parsing_Operands and then Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when 'c' => Counts := True;
                     when 'd' => Duplicates := True;
                     when 'i' => Fold_Case := True;
                     when 'u' => Unique_Only := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                        return;
                  end case;
               end loop;
            else
               Files.Append (Arg);
               Parsing_Operands := True;
            end if;
         end;
      end loop;

      if Files.Length > 2 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "extra operand '" & Files.Element (3) & "'");
         return;
      end if;

      declare
         Text : constant String :=
           (if Files.Length = 0 or else Files.Element (1) = "-" then Read_Standard_Input (Context)
            else Read_File (Files.Element (1), Ok));
         Lines : constant String_Vectors.Vector := Lines_Of (Text);
         Output : Unbounded_String;
         Written : Boolean;

         function Count_Field (Count : Natural) return String is
            Raw : constant String := Natural_Image (Count);
         begin
            if Raw'Length >= 7 then
               return Raw;
            else
               declare
                  Padding : String (1 .. 7 - Raw'Length);
               begin
                  for I in Padding'Range loop
                     Padding (I) := ' ';
                  end loop;
                  return Padding & Raw;
               end;
            end if;
         end Count_Field;

         procedure Emit_Group (Line : String; Count : Natural) is
            Should_Emit : constant Boolean :=
              (if Duplicates then Count > 1 elsif Unique_Only then Count = 1 else True);
         begin
            if Should_Emit then
               if Counts then
                  Append (Output, Count_Field (Count) & " ");
               end if;
               Append (Output, Line & LF);
            end if;
         end Emit_Group;
      begin
         if not Ok then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         if Lines.Length > 0 then
            declare
               Previous : Unbounded_String := To_Unbounded_String (Lines.Element (1));
               Previous_Key : Unbounded_String := To_Unbounded_String (Comparison_Key (Lines.Element (1)));
               Count    : Natural := 1;
            begin
               for I in 2 .. Natural (Lines.Length) loop
                  if Comparison_Key (Lines.Element (I)) = To_String (Previous_Key) then
                     Count := Count + 1;
                  else
                     Emit_Group (To_String (Previous), Count);
                     Previous := To_Unbounded_String (Lines.Element (I));
                     Previous_Key := To_Unbounded_String (Comparison_Key (Lines.Element (I)));
                     Count := 1;
                  end if;
               end loop;
               Emit_Group (To_String (Previous), Count);
            end;
         end if;

         if Files.Length = 2 then
            Write_File (Files.Element (2), To_String (Output), False, Written);
            Ok := Written;
         else
            Context.Put (To_String (Output));
         end if;
      end;
      Set_Success (Context, Result);
      if not Ok or else Context.Output_Failed then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run_Uniq;

   procedure Run_Xargs
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Data        : constant String := Read_Standard_Input (Context);
      Fixed_Args  : String_Vectors.Vector;
      Input_Args  : String_Vectors.Vector;
      Batch_Size  : Natural := 0;
      Skip_Next   : Boolean := False;
      Null_Delimited : Boolean := False;
      No_Run_If_Empty : Boolean := False;
      Trace_Mode : Boolean := False;
      Exit_If_Size_Exceeded : Boolean := False;
      Has_Eof_Marker : Boolean := False;
      Eof_Marker : Unbounded_String;
      Replacement_Mode : Boolean := False;
      Replacement_String : Unbounded_String;
      Command_Size_Limit : Natural := 131_072;
      Parsing_Fixed_Args : Boolean := False;

      function Classified_Xargs_Status (Utility_Ran : Boolean; Utility_Status : Integer)
        return Posix_Tools.Exit_Status.Code
      is
      begin
         if not Utility_Ran then
            return Posix_Tools.Exit_Status.Utility_Not_Found;
         elsif Utility_Status = 126 then
            return Posix_Tools.Exit_Status.Utility_Cannot_Invoke;
         elsif Utility_Status = 127 then
            return Posix_Tools.Exit_Status.Utility_Not_Found;
         elsif Utility_Status = 255 then
            return Posix_Tools.Exit_Status.Code (124);
         elsif Utility_Status in 1 .. 125 then
            return Posix_Tools.Exit_Status.Code (123);
         else
            return Posix_Tools.Exit_Status.Operational_Failure;
         end if;
      end Classified_Xargs_Status;

      function Replace_All (Template, Pattern, Value : String) return String is
         Replaced : Unbounded_String;
         I        : Positive := Template'First;
      begin
         if Pattern = "" then
            return Template;
         end if;

         while I <= Template'Last loop
            if I + Pattern'Length - 1 <= Template'Last
              and then Template (I .. I + Pattern'Length - 1) = Pattern
            then
               Append (Replaced, Value);
               I := I + Pattern'Length;
            else
               Append (Replaced, Template (I));
               I := I + 1;
            end if;
         end loop;

         return To_String (Replaced);
      end Replace_All;

      procedure Add_Command_Size (Total : in out Natural; Item : String) is
         Cost : constant Natural := Item'Length + 1;
      begin
         if Total > Natural'Last - Cost then
            Total := Natural'Last;
         else
            Total := Total + Cost;
         end if;
      end Add_Command_Size;

      function Composed_Command_Size (First_Input, Last_Input : Natural) return Natural is
         Utility : constant String :=
           (if Fixed_Args.Length = 0 then "echo" else Fixed_Args.Element (1));
         Total : Natural := 0;
      begin
         Add_Command_Size (Total, Utility);

         if Replacement_Mode then
            for I in 2 .. Natural (Fixed_Args.Length) loop
               Add_Command_Size
                 (Total,
                  Replace_All
                    (Fixed_Args.Element (I),
                     To_String (Replacement_String),
                     (if First_Input <= Last_Input then Input_Args.Element (First_Input) else "")));
            end loop;
         else
            for I in 2 .. Natural (Fixed_Args.Length) loop
               Add_Command_Size (Total, Fixed_Args.Element (I));
            end loop;

            for I in First_Input .. Last_Input loop
               Add_Command_Size (Total, Input_Args.Element (I));
            end loop;
         end if;

         return Total;
      end Composed_Command_Size;

      function Render_Command (First_Input, Last_Input : Natural) return String is
         Utility : constant String :=
           (if Fixed_Args.Length = 0 then "echo" else Fixed_Args.Element (1));
         Line : Unbounded_String := To_Unbounded_String (Utility);

         procedure Append_Argument (Item : String) is
         begin
            Append (Line, " ");
            Append (Line, Item);
         end Append_Argument;
      begin
         if Replacement_Mode then
            for I in 2 .. Natural (Fixed_Args.Length) loop
               Append_Argument
                 (Replace_All
                    (Fixed_Args.Element (I),
                     To_String (Replacement_String),
                     (if First_Input <= Last_Input then Input_Args.Element (First_Input) else "")));
            end loop;
         else
            for I in 2 .. Natural (Fixed_Args.Length) loop
               Append_Argument (Fixed_Args.Element (I));
            end loop;

            for I in First_Input .. Last_Input loop
               Append_Argument (Input_Args.Element (I));
            end loop;
         end if;

         return To_String (Line);
      end Render_Command;

      procedure Execute_Batch (First_Input, Last_Input : Natural; Ok : out Boolean) is
         Utility : constant String :=
           (if Fixed_Args.Length = 0 then "echo" else Fixed_Args.Element (1));
         Arguments : Posix_Tools.Arguments.Vector;
         Exit_Code : Integer := 0;
      begin
         Ok := True;
         if Composed_Command_Size (First_Input, Last_Input) > Command_Size_Limit then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.resource.argument_list_too_large", "argument list too long");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            Ok := False;
            return;
         end if;

         if Trace_Mode then
            Context.Put_Error_Line (Render_Command (First_Input, Last_Input));
            if Context.Output_Failed then
               Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
               Ok := False;
               return;
            end if;
         end if;

         if Replacement_Mode then
            for I in 2 .. Natural (Fixed_Args.Length) loop
               Arguments.Append
                 (Replace_All
                    (Fixed_Args.Element (I),
                     To_String (Replacement_String),
                     (if First_Input <= Last_Input then Input_Args.Element (First_Input) else "")));
            end loop;
         else
            for I in 2 .. Natural (Fixed_Args.Length) loop
               Arguments.Append (Fixed_Args.Element (I));
            end loop;

            for I in First_Input .. Last_Input loop
               Arguments.Append (Input_Args.Element (I));
            end loop;
         end if;

         if not Context.Execute_Utility (Utility, Arguments, Exit_Code) then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Utility, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Result.Status := Classified_Xargs_Status (False, Exit_Code);
            Ok := False;
         elsif Exit_Code /= 0 then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Utility, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Result.Status := Classified_Xargs_Status (True, Exit_Code);
            Ok := False;
         end if;
      end Execute_Batch;

      function Is_Xargs_Blank (Ch : Character) return Boolean is
      begin
         return Ch in ' ' | Character'Val (9) | LF;
      end Is_Xargs_Blank;

      procedure Append_Blank_Delimited_Input (Ok : out Boolean) is
         I    : Positive := Data'First;
         Stop : Boolean := False;
      begin
         Ok := True;
         if Data = "" then
            return;
         end if;

         while I <= Data'Last and then not Stop loop
            while I <= Data'Last and then Is_Xargs_Blank (Data (I)) loop
               I := I + 1;
            end loop;
            exit when I > Data'Last;

            declare
               Item : Unbounded_String;
            begin
               while I <= Data'Last and then not Is_Xargs_Blank (Data (I)) loop
                  if Data (I) = Character'Val (39) then
                     I := I + 1;
                     while I <= Data'Last and then Data (I) /= Character'Val (39) loop
                        Append (Item, Data (I));
                        I := I + 1;
                     end loop;
                     if I > Data'Last then
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unmatched single quote");
                        Ok := False;
                        return;
                     end if;
                     I := I + 1;
                  elsif Data (I) = Character'Val (34) then
                     I := I + 1;
                     while I <= Data'Last and then Data (I) /= Character'Val (34) loop
                        if Data (I) = '\' and then I < Data'Last then
                           I := I + 1;
                        end if;
                        Append (Item, Data (I));
                        I := I + 1;
                     end loop;
                     if I > Data'Last then
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unmatched double quote");
                        Ok := False;
                        return;
                     end if;
                     I := I + 1;
                  elsif Data (I) = '\' then
                     if I = Data'Last then
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unfinished escape");
                        Ok := False;
                        return;
                     end if;
                     I := I + 1;
                     Append (Item, Data (I));
                     I := I + 1;
                  else
                     Append (Item, Data (I));
                     I := I + 1;
                  end if;
               end loop;

               if Has_Eof_Marker and then To_String (Item) = To_String (Eof_Marker) then
                  Stop := True;
               else
                  Input_Args.Append (To_String (Item));
               end if;
            end;
         end loop;
      end Append_Blank_Delimited_Input;

      procedure Append_Line_Delimited_Input is
         I : Positive := Data'First;
      begin
         if Data = "" then
            return;
         end if;

         while I <= Data'Last loop
            declare
               Start : constant Positive := I;
            begin
               while I <= Data'Last and then Data (I) /= LF loop
                  I := I + 1;
               end loop;

               if I > Start then
                  declare
                     Item : constant String := Data (Start .. I - 1);
                  begin
                     exit when Has_Eof_Marker and then Item = To_String (Eof_Marker);
                     Input_Args.Append (Item);
                  end;
               end if;

               I := I + 1;
            end;
         end loop;
      end Append_Line_Delimited_Input;
   begin
      for I in 1 .. Context.Argument_Count loop
         if Skip_Next then
            Skip_Next := False;
         elsif Parsing_Fixed_Args then
            Fixed_Args.Append (Context.Argument (I));
         elsif Context.Argument (I) = "--" then
            Parsing_Fixed_Args := True;
         elsif Context.Argument (I) = "-0" then
            Null_Delimited := True;
         elsif Context.Argument (I) = "-I" then
            if I = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-I'");
               return;
            end if;
            Replacement_Mode := True;
            Replacement_String := To_Unbounded_String (Context.Argument (I + 1));
            Batch_Size := 1;
            Skip_Next := True;
         elsif Context.Argument (I)'Length > 2
           and then Context.Argument (I) (Context.Argument (I)'First .. Context.Argument (I)'First + 1) = "-I"
         then
            Replacement_Mode := True;
            Replacement_String :=
              To_Unbounded_String
                (Context.Argument (I) (Context.Argument (I)'First + 2 .. Context.Argument (I)'Last));
            Batch_Size := 1;
         elsif Context.Argument (I) = "-r" or else Context.Argument (I) = "--no-run-if-empty" then
            No_Run_If_Empty := True;
         elsif Context.Argument (I) = "-t" then
            Trace_Mode := True;
         elsif Context.Argument (I) = "-x" then
            Exit_If_Size_Exceeded := True;
         elsif Context.Argument (I) = "-E" then
            if I = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-E'");
               return;
            end if;
            Has_Eof_Marker := True;
            Eof_Marker := To_Unbounded_String (Context.Argument (I + 1));
            Skip_Next := True;
         elsif Context.Argument (I) = "-n" then
            if I = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-n'");
               return;
            end if;
            if not Parse_Natural_Operand
              (Context, Result, Context.Argument (I + 1), "argument count", Batch_Size)
            then
               return;
            elsif Batch_Size = 0 then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid argument count '0'");
               return;
            end if;
            Skip_Next := True;
         elsif Context.Argument (I)'Length > 2
           and then Context.Argument (I) (Context.Argument (I)'First .. Context.Argument (I)'First + 1) = "-n"
         then
            if not Parse_Natural_Operand
              (Context,
               Result,
               Context.Argument (I) (Context.Argument (I)'First + 2 .. Context.Argument (I)'Last),
               "argument count",
               Batch_Size)
            then
               return;
            elsif Batch_Size = 0 then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid argument count '0'");
               return;
            end if;
         elsif Context.Argument (I) = "-s" then
            if I = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-s'");
               return;
            end if;
            if not Parse_Natural_Operand
              (Context, Result, Context.Argument (I + 1), "command size", Command_Size_Limit)
            then
               return;
            elsif Command_Size_Limit = 0 then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid command size '0'");
               return;
            end if;
            Skip_Next := True;
         elsif Context.Argument (I)'Length > 2
           and then Context.Argument (I) (Context.Argument (I)'First .. Context.Argument (I)'First + 1) = "-s"
         then
            if not Parse_Natural_Operand
              (Context,
               Result,
               Context.Argument (I) (Context.Argument (I)'First + 2 .. Context.Argument (I)'Last),
               "command size",
               Command_Size_Limit)
            then
               return;
            elsif Command_Size_Limit = 0 then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid command size '0'");
               return;
            end if;
         else
            Fixed_Args.Append (Context.Argument (I));
            Parsing_Fixed_Args := True;
         end if;
      end loop;

      declare
         I : Positive := Data'First;
      begin
         if Data /= "" then
            if Replacement_Mode and then not Null_Delimited then
               Append_Line_Delimited_Input;
            elsif Null_Delimited then
               while I <= Data'Last loop
                  declare
                     Start : constant Positive := I;
                  begin
                     while I <= Data'Last and then Data (I) /= Character'Val (0) loop
                        I := I + 1;
                     end loop;
                     declare
                        Item : constant String := Data (Start .. I - 1);
                     begin
                        exit when Has_Eof_Marker and then Item = To_String (Eof_Marker);
                        Input_Args.Append (Item);
                     end;
                     I := I + 1;
                  end;
               end loop;
            else
               declare
                  Parse_Ok : Boolean;
               begin
                  Append_Blank_Delimited_Input (Parse_Ok);
                  if not Parse_Ok then
                     return;
                  end if;
               end;
            end if;
         end if;
      end;

      if Batch_Size = 0 and then Input_Args.Length > 0 then
         Batch_Size := Natural (Input_Args.Length);
      end if;

      if Input_Args.Length = 0 then
         if No_Run_If_Empty then
            Set_Success (Context, Result);
            return;
         else
            declare
               Exec_Ok : Boolean;
            begin
               Execute_Batch (1, 0, Exec_Ok);
               if not Exec_Ok then
                  return;
               end if;
            end;
         end if;
      else
         declare
            First : Natural := 1;
            Last  : Natural;
            Exec_Ok : Boolean;
         begin
            while First <= Natural (Input_Args.Length) loop
               Last := Natural'Min (First + Batch_Size - 1, Natural (Input_Args.Length));
               if Exit_If_Size_Exceeded and then Composed_Command_Size (First, Last) > Command_Size_Limit then
                  Posix_Tools.Commands.Helpers.Operational_Error
                    (Context, "posix_tools.diagnostic.resource.argument_list_too_large", "argument list too long");
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                  return;
               end if;
               while Last > First and then Composed_Command_Size (First, Last) > Command_Size_Limit loop
                  Last := Last - 1;
               end loop;
               Execute_Batch (First, Last, Exec_Ok);
               if not Exec_Ok then
                  return;
               end if;
               First := Last + 1;
            end loop;
         end;
      end if;
      Set_Success (Context, Result);
   end Run_Xargs;

   procedure Read_All
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Data      : out Unbounded_String;
      Ok        : out Boolean)
   is
      procedure Append_Chunk
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset)
      is
         pragma Unreferenced (Context);
      begin
         if Last >= Buffer'First then
            for I in Buffer'First .. Last loop
               Append (Data, Character'Val (Integer (Buffer (I))));
            end loop;
         end if;
      end Append_Chunk;

      procedure Each_Chunk is new Posix_Tools.Commands.File_Helpers.For_Each_Chunk
        (Action => Append_Chunk);
   begin
      Data := Null_Unbounded_String;
      Each_Chunk (Context, File_Name, Ok);
   end Read_All;

   function Line_Count_Through (Text : String; Last : Natural) return Natural is
      Lines : Natural := 1;
   begin
      for I in Text'First .. Last loop
         if Text (I) = LF then
            Lines := Lines + 1;
         end if;
      end loop;
      return Lines;
   end Line_Count_Through;

   function Decimal_Image (Value : Long_Long_Integer) return String is
      Raw : constant String := Long_Long_Integer'Image (Value);
   begin
      return Raw (Raw'First + 1 .. Raw'Last);
   end Decimal_Image;

   function Octal_Image (Value : Natural; Width : Positive) return String is
      Octal_Digit : constant String := "01234567";
      Result : String (1 .. Width) := [others => '0'];
      Work   : Natural := Value;
   begin
      for I in reverse Result'Range loop
         Result (I) := Octal_Digit ((Work mod 8) + 1);
         Work := Work / 8;
      end loop;
      return Result;
   end Octal_Image;

   function Hex_Image (Value : Natural; Width : Positive) return String is
      Hex_Digit : constant String := "0123456789abcdef";
      Result : String (1 .. Width) := [others => '0'];
      Work   : Natural := Value;
   begin
      for I in reverse Result'Range loop
         Result (I) := Hex_Digit ((Work mod 16) + 1);
         Work := Work / 16;
      end loop;
      return Result;
   end Hex_Image;

   procedure Split_Lines (Text : String; Lines : in out String_Vectors.Vector) is
      Start : Positive := Text'First;
   begin
      Lines.Clear;
      if Text = "" then
         return;
      end if;

      for I in Text'Range loop
         if Text (I) = LF then
            Lines.Append (Text (Start .. I - 1));
            Start := I + 1;
         end if;
      end loop;

      if Start <= Text'Last then
         Lines.Append (Text (Start .. Text'Last));
      end if;
   end Split_Lines;

   type Range_Item is record
      First : Positive := 1;
      Last  : Natural := 0;
   end record;
   package Range_Vectors is new Ada.Containers.Vectors (Positive, Range_Item);

   function Parse_List (Text : String; Ranges : in out Range_Vectors.Vector) return Boolean is
      Index : Positive := Text'First;

      function Is_List_Separator (Ch : Character) return Boolean is
      begin
         return Ch = ',' or else Ch = ' ' or else Ch = Character'Val (9);
      end Is_List_Separator;

      function Parse_Number (Value : out Natural) return Boolean is
      begin
         Value := 0;
         if Index > Text'Last or else Text (Index) not in '0' .. '9' then
            return False;
         end if;
         while Index <= Text'Last and then Text (Index) in '0' .. '9' loop
            Value := Value * 10 + Character'Pos (Text (Index)) - Character'Pos ('0');
            Index := Index + 1;
         end loop;
         return Value > 0;
      end Parse_Number;
   begin
      Ranges.Clear;
      if Text = "" then
         return False;
      end if;

      while Index <= Text'Last loop
         declare
            First_Value : Natural := 0;
            Last_Value  : Natural := 0;
            Open_End    : Boolean := False;
         begin
            if Text (Index) = '-' then
               First_Value := 1;
               Index := Index + 1;
               if not Parse_Number (Last_Value) then
                  return False;
               end if;
            else
               if not Parse_Number (First_Value) then
                  return False;
               end if;
               if Index <= Text'Last and then Text (Index) = '-' then
                  Index := Index + 1;
                  if Index <= Text'Last and then Text (Index) in '0' .. '9' then
                     if not Parse_Number (Last_Value) then
                        return False;
                     end if;
                  else
                     Open_End := True;
                  end if;
               else
                  Last_Value := First_Value;
               end if;
            end if;

            if not Open_End and then Last_Value < First_Value then
               return False;
            end if;
            Ranges.Append
              (Range_Item'(Positive (First_Value), (if Open_End then 0 else Last_Value)));
            exit when Index > Text'Last;
            if not Is_List_Separator (Text (Index)) then
               return False;
            end if;
            while Index <= Text'Last and then Is_List_Separator (Text (Index)) loop
               Index := Index + 1;
            end loop;
            if Index > Text'Last then
               return False;
            end if;
         end;
      end loop;
      return True;
   end Parse_List;

   function Selected (Ranges : Range_Vectors.Vector; Position : Positive) return Boolean is
   begin
      for Item of Ranges loop
         if Position >= Item.First and then (Item.Last = 0 or else Position <= Item.Last) then
            return True;
         end if;
      end loop;
      return False;
   end Selected;

   procedure Run_Cksum
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Polynomial : constant Interfaces.Unsigned_32 := 16#04C11DB7#;
      All_Ok     : Boolean := True;
      First      : Positive := 1;

      function CRC_For (Text : String) return Interfaces.Unsigned_32 is
         use type Interfaces.Unsigned_32;
         CRC : Interfaces.Unsigned_32 := 0;
      begin
         for Ch of Text loop
            CRC := CRC xor Interfaces.Shift_Left (Interfaces.Unsigned_32 (Character'Pos (Ch)), 24);
            for Bit in 1 .. 8 loop
               if (CRC and 16#80000000#) /= 0 then
                  CRC := Interfaces.Shift_Left (CRC, 1) xor Polynomial;
               else
                  CRC := Interfaces.Shift_Left (CRC, 1);
               end if;
            end loop;
         end loop;

         declare
            Length_Value : Natural := Text'Length;
         begin
            while Length_Value /= 0 loop
               CRC := CRC xor Interfaces.Shift_Left (Interfaces.Unsigned_32 (Length_Value mod 256), 24);
               for Bit in 1 .. 8 loop
                  if (CRC and 16#80000000#) /= 0 then
                     CRC := Interfaces.Shift_Left (CRC, 1) xor Polynomial;
                  else
                     CRC := Interfaces.Shift_Left (CRC, 1);
                  end if;
               end loop;
               Length_Value := Length_Value / 256;
            end loop;
         end;
         return not CRC;
      end CRC_For;

      procedure Emit (Name : String) is
         Data : Unbounded_String;
         Ok   : Boolean;
      begin
         Read_All (Context, Name, Data, Ok);
         if Ok then
            Context.Put_Line
              (Decimal_Image (Long_Long_Integer (CRC_For (To_String (Data)))) & " "
               & Decimal_Image (Long_Long_Integer (Length (Data)))
               & (if Name = "-" then "" else " " & Name));
         else
            All_Ok := False;
         end if;
      end Emit;
   begin
      if Context.Argument_Count >= 1 and then Context.Argument (1) = "--" then
         First := 2;
      end if;

      if Context.Argument_Count < First then
         Emit ("-");
      else
         for I in First .. Context.Argument_Count loop
            Emit (Context.Argument (I));
         end loop;
      end if;
      Result.Status :=
        (if All_Ok and then not Context.Output_Failed then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Cksum;

   procedure Run_Cmp
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Silent : Boolean := False;
      List   : Boolean := False;
      First  : Positive := 1;
      Left   : Unbounded_String;
      Right  : Unbounded_String;
      Ok     : Boolean;
   begin
      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "-s" then
            Silent := True;
            First := First + 1;
         elsif Context.Argument (First) = "-l" then
            List := True;
            First := First + 1;
         elsif Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         else
            exit;
         end if;
      end loop;
      if Context.Argument_Count /= First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      Read_All (Context, Context.Argument (First), Left, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;
      Read_All (Context, Context.Argument (First + 1), Right, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      declare
         L : constant String := To_String (Left);
         R : constant String := To_String (Right);
         Different : Boolean := False;
      begin
         for I in 1 .. Natural'Min (L'Length, R'Length) loop
            if L (I) /= R (I) then
               Different := True;
               if List and then not Silent then
                  Context.Put_Line
                    (Decimal_Image (Long_Long_Integer (I)) & " "
                     & Octal_Image (Character'Pos (L (I)), 3) & " "
                     & Octal_Image (Character'Pos (R (I)), 3));
               elsif not Silent then
                  Context.Put_Line
                    (Context.Argument (First) & " " & Context.Argument (First + 1)
                     & " differ: byte " & Decimal_Image (Long_Long_Integer (I))
                     & ", line " & Decimal_Image (Long_Long_Integer (Line_Count_Through (L, I))));
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                  return;
               end if;
            end if;
         end loop;
         if L'Length /= R'Length then
            if not Silent then
               Context.Put_Line
                 ("cmp: EOF on "
                  & (if L'Length < R'Length then Context.Argument (First) else Context.Argument (First + 1)));
            end if;
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         elsif Different then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         else
            Set_Success (Context, Result);
         end if;
      end;
   end Run_Cmp;

   procedure Run_Paste
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      type Line_Vector_Array is array (Positive range <>) of String_Vectors.Vector;
      First       : Positive := 1;
      Serial      : Boolean := False;
      Delimiters  : Unbounded_String := To_Unbounded_String (Character'Val (9) & "");

      function Delimiter (Position : Positive) return String is
         Text : constant String := To_String (Delimiters);
      begin
         if Text = "" then
            return "";
         else
            return Text (((Position - 1) mod Text'Length) + 1) & "";
         end if;
      end Delimiter;
   begin
      while First <= Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (First);
         begin
            if Arg = "--" then
               First := First + 1;
               exit;
            elsif Arg = "-s" then
               Serial := True;
               First := First + 1;
            elsif Arg = "-d" then
               if First >= Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "missing option argument '-d'");
                  return;
               end if;
               Delimiters := To_Unbounded_String (Context.Argument (First + 1));
               First := First + 2;
            elsif Arg'Length > 2
              and then Arg (Arg'First) = '-'
              and then Arg (Arg'First + 1) = 'd'
            then
               Delimiters := To_Unbounded_String (Arg (Arg'First + 2 .. Arg'Last));
               First := First + 1;
            else
               exit;
            end if;
         end;
      end loop;
      declare
         Count : constant Natural :=
           (if Context.Argument_Count < First then 1 else Context.Argument_Count - First + 1);
         Files : Line_Vector_Array (1 .. Count);
         Max   : Natural := 0;
         Ok    : Boolean := True;
      begin
         for I in 1 .. Count loop
            declare
               Data : Unbounded_String;
               Name : constant String :=
                 (if Context.Argument_Count < First then "-" else Context.Argument (First + I - 1));
            begin
               Read_All (Context, Name, Data, Ok);
               exit when not Ok;
               Split_Lines (To_String (Data), Files (I));
               Max := Natural'Max (Max, Natural (Files (I).Length));
            end;
         end loop;
         if not Ok then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         if Serial then
            for File_Index in 1 .. Count loop
               declare
                  Output : Unbounded_String;
               begin
                  for Row in 1 .. Natural (Files (File_Index).Length) loop
                     if Row > 1 then
                        Append (Output, Delimiter (Row - 1));
                     end if;
                     Append (Output, Files (File_Index).Element (Row));
                  end loop;
                  if Natural (Files (File_Index).Length) > 0 then
                     Context.Put_Line (To_String (Output));
                     exit when Context.Output_Failed;
                  end if;
               end;
            end loop;
         else
            for Row in 1 .. Max loop
               declare
                  Output : Unbounded_String;
               begin
                  for File_Index in 1 .. Count loop
                     if File_Index > 1 then
                        Append (Output, Delimiter (File_Index - 1));
                     end if;
                     if Row <= Natural (Files (File_Index).Length) then
                        Append (Output, Files (File_Index).Element (Row));
                     end if;
                  end loop;
                  Context.Put_Line (To_String (Output));
                  if Context.Output_Failed then
                     exit;
                  end if;
               end;
            end loop;
         end if;
      end;
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run_Paste;

   procedure Run_Pathchk
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Portable_Mode : Boolean := False;
      First         : Positive := 1;
      All_Ok        : Boolean := True;

      function Path_Limit return Natural is
        (if Portable_Mode then 256 else 4_096);

      function Component_Limit return Natural is
        (if Portable_Mode then 14 else 255);

      function Is_Portable_Character (Ch : Character) return Boolean is
      begin
         return Ch in 'A' .. 'Z'
           or else Ch in 'a' .. 'z'
           or else Ch in '0' .. '9'
           or else Ch = '.'
           or else Ch = '_'
           or else Ch = '-';
      end Is_Portable_Character;

      procedure Reject (Path, Reason : String) is
      begin
         All_Ok := False;
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Path, "posix_tools.pathchk.invalid_path", Reason);
      end Reject;

      procedure Check_Component (Path, Component : String) is
      begin
         if Component'Length > Component_Limit then
            Reject (Path, "component too long");
         elsif Portable_Mode then
            for Ch of Component loop
               if not Is_Portable_Character (Ch) then
                  Reject (Path, "non-portable character");
                  return;
               end if;
            end loop;
         end if;
      end Check_Component;

      procedure Check_Path (Path : String) is
         Start : Natural := Path'First;
      begin
         if Path = "" then
            Reject (Path, "empty pathname");
            return;
         elsif Path'Length > Path_Limit then
            Reject (Path, "pathname too long");
            return;
         end if;

         while Start <= Path'Last loop
            while Start <= Path'Last and then Path (Start) = '/' loop
               Start := Start + 1;
            end loop;

            exit when Start > Path'Last;

            declare
               Stop : Natural := Start;
            begin
               while Stop <= Path'Last and then Path (Stop) /= '/' loop
                  Stop := Stop + 1;
               end loop;

               Check_Component (Path, Path (Start .. Stop - 1));
               Start := Stop + 1;
            end;
         end loop;
      end Check_Path;
   begin
      while First <= Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (First);
         begin
            if Arg = "--" then
               First := First + 1;
               exit;
            elsif Arg = "-p" then
               Portable_Mode := True;
               First := First + 1;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option " & Arg);
               return;
            else
               exit;
            end if;
         end;
      end loop;

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for Index in First .. Context.Argument_Count loop
         Check_Path (Context.Argument (Index));
      end loop;

      Result.Status :=
        (if All_Ok then Posix_Tools.Exit_Status.Success else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Pathchk;

   procedure Run_Cut
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Mode       : Character := Character'Val (0);
      Ranges     : Range_Vectors.Vector;
      Delimiter  : Character := Character'Val (9);
      Suppress   : Boolean := False;
      No_Split   : Boolean := False;
      First_File : Positive := 1;
      All_Ok     : Boolean := True;

      procedure Emit_Line (Line : String) is
         Clean  : constant String :=
           (if Line'Length > 0 and then Line (Line'Last) = LF
            then Line (Line'First .. Line'Last - 1)
            else Line);
         Output : Unbounded_String;
         Field  : Positive := 1;
         Start  : Positive := Clean'First;
         Seen_Delimiter : Boolean := False;
      begin
         if Mode = 'b' or else Mode = 'c' then
            for I in Clean'Range loop
               if Selected (Ranges, I - Clean'First + 1) then
                  Append (Output, Clean (I));
               end if;
            end loop;
            Context.Put_Line (To_String (Output));
         else
            for I in Clean'Range loop
               if Clean (I) = Delimiter then
                  Seen_Delimiter := True;
                  if Selected (Ranges, Field) then
                     if Length (Output) > 0 then
                        Append (Output, Delimiter);
                     end if;
                     Append (Output, Clean (Start .. I - 1));
                  end if;
                  Field := Field + 1;
                  Start := I + 1;
               end if;
            end loop;
            if Selected (Ranges, Field) then
               if Length (Output) > 0 then
                  Append (Output, Delimiter);
               end if;
               if Start <= Clean'Last then
                  Append (Output, Clean (Start .. Clean'Last));
               end if;
            end if;
            if Seen_Delimiter or else not Suppress then
               Context.Put_Line ((if Seen_Delimiter then To_String (Output) else Clean));
            end if;
         end if;
      end Emit_Line;

      procedure Cut_File (Name : String; Ok : out Boolean) is
         Data  : Unbounded_String;
         Lines : String_Vectors.Vector;
      begin
         Read_All (Context, Name, Data, Ok);
         if not Ok then
            return;
         end if;
         Split_Lines (To_String (Data), Lines);
         for Line of Lines loop
            Emit_Line (Line);
            if Context.Output_Failed then
               Ok := False;
               return;
            end if;
         end loop;
      end Cut_File;
   begin
      while First_File <= Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (First_File);
         begin
            if Arg = "-s" then
               Suppress := True;
               First_File := First_File + 1;
            elsif Arg = "-n" then
               No_Split := True;
               First_File := First_File + 1;
            elsif Arg = "-d" then
               if First_File >= Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "missing option argument '-d'");
                  return;
               elsif Context.Argument (First_File + 1)'Length /= 1 then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Context.Argument (First_File + 1) & "'");
                  return;
               end if;
               Delimiter := Context.Argument (First_File + 1) (Context.Argument (First_File + 1)'First);
               First_File := First_File + 2;
            elsif Arg'Length > 2
              and then Arg (Arg'First) = '-'
              and then Arg (Arg'First + 1) = 'd'
            then
               if Arg'Length /= 3 then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Arg (Arg'First + 2 .. Arg'Last) & "'");
                  return;
               end if;
               Delimiter := Arg (Arg'First + 2);
               First_File := First_File + 1;
            elsif Arg'Length >= 2
              and then Arg (Arg'First) = '-'
              and then Arg (Arg'First + 1) in 'b' | 'c' | 'f'
            then
               Mode := Arg (Arg'First + 1);
               declare
                  Spec : constant String :=
                    (if Arg'Length > 2 then Arg (Arg'First + 2 .. Arg'Last)
                     elsif First_File < Context.Argument_Count then Context.Argument (First_File + 1)
                     else "");
               begin
                  if Spec = "" then
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "missing option argument '-" & Mode & "'");
                     return;
                  end if;
                  if not Parse_List (Spec, Ranges) then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand '" & Spec & "'");
                     return;
                  end if;
                  First_File := First_File + (if Arg'Length > 2 then 1 else 2);
               end;
            elsif Arg = "--" then
               First_File := First_File + 1;
               exit;
            else
               exit;
            end if;
         end;
      end loop;

      if Mode = Character'Val (0) then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;
      if No_Split and then Mode /= 'b' then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand '-n'");
         return;
      end if;
      if Context.Argument_Count < First_File then
         Cut_File ("-", All_Ok);
      else
         for I in First_File .. Context.Argument_Count loop
            declare
               Ok : Boolean;
            begin
               Cut_File (Context.Argument (I), Ok);
               All_Ok := All_Ok and Ok;
            end;
         end loop;
      end if;
      Result.Status :=
        (if All_Ok and then not Context.Output_Failed then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Cut;

   procedure Run_Comm
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Suppress_1 : Boolean := False;
      Suppress_2 : Boolean := False;
      Suppress_3 : Boolean := False;
      First      : Positive := 1;
      Left_Data  : Unbounded_String;
      Right_Data : Unbounded_String;
      Left_Lines : String_Vectors.Vector;
      Right_Lines : String_Vectors.Vector;
      Ok         : Boolean;
      L          : Positive := 1;
      R          : Positive := 1;

      procedure Emit (Column : Positive; Text : String) is
         Prefix : Unbounded_String;
      begin
         if Column = 2 then
            if not Suppress_1 then
               Append (Prefix, Character'Val (9));
            end if;
         elsif Column = 3 then
            if not Suppress_1 then
               Append (Prefix, Character'Val (9));
            end if;
            if not Suppress_2 then
               Append (Prefix, Character'Val (9));
            end if;
         end if;
         Context.Put_Line (To_String (Prefix) & Text);
      end Emit;
   begin
      while First <= Context.Argument_Count
        and then Context.Argument (First)'Length > 1
        and then Context.Argument (First) (Context.Argument (First)'First) = '-'
      loop
         exit when Context.Argument (First) = "--";
         for Ch of Context.Argument (First) (Context.Argument (First)'First + 1 .. Context.Argument (First)'Last) loop
            case Ch is
               when '1' => Suppress_1 := True;
               when '2' => Suppress_2 := True;
               when '3' => Suppress_3 := True;
               when others =>
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                  return;
            end case;
         end loop;
         First := First + 1;
      end loop;
      if First <= Context.Argument_Count and then Context.Argument (First) = "--" then
         First := First + 1;
      end if;
      if Context.Argument_Count /= First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      Read_All (Context, Context.Argument (First), Left_Data, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;
      Read_All (Context, Context.Argument (First + 1), Right_Data, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;
      Split_Lines (To_String (Left_Data), Left_Lines);
      Split_Lines (To_String (Right_Data), Right_Lines);

      while L <= Natural (Left_Lines.Length) or else R <= Natural (Right_Lines.Length) loop
         if L > Natural (Left_Lines.Length) then
            if not Suppress_2 then
               Emit (2, Right_Lines.Element (R));
            end if;
            R := R + 1;
         elsif R > Natural (Right_Lines.Length) then
            if not Suppress_1 then
               Emit (1, Left_Lines.Element (L));
            end if;
            L := L + 1;
         elsif Left_Lines.Element (L) = Right_Lines.Element (R) then
            if not Suppress_3 then
               Emit (3, Left_Lines.Element (L));
            end if;
            L := L + 1;
            R := R + 1;
         elsif Left_Lines.Element (L) < Right_Lines.Element (R) then
            if not Suppress_1 then
               Emit (1, Left_Lines.Element (L));
            end if;
            L := L + 1;
         else
            if not Suppress_2 then
               Emit (2, Right_Lines.Element (R));
            end if;
            R := R + 1;
         end if;
      end loop;
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run_Comm;

   procedure Run_Od
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      type Address_Base is (No_Address, Octal_Address, Decimal_Address, Hex_Address);
      type Dump_Kind is
        (Named_Byte, Character_Byte, Signed_Integer, Floating_Point, Octal_Integer, Unsigned_Integer, Hex_Integer);
      type Dump_Spec is record
         Kind : Dump_Kind := Octal_Integer;
         Size : Positive := 1;
      end record;
      package Dump_Spec_Vectors is new Ada.Containers.Vectors (Positive, Dump_Spec);

      Address : Address_Base := Octal_Address;
      Formats : Dump_Spec_Vectors.Vector;
      Skip    : Natural := 0;
      Limit   : Natural := 0;
      Has_Limit : Boolean := False;
      Verbose : Boolean := False;
      First : Positive := 1;
      Data  : Unbounded_String;
      Ok    : Boolean := True;

      function Address_Image (Value : Natural) return String is
      begin
         case Address is
            when No_Address =>
               return "";
            when Octal_Address =>
               return Octal_Image (Value, 7);
            when Decimal_Address =>
               return Decimal_Image (Long_Long_Integer (Value));
            when Hex_Address =>
               return Hex_Image (Value, 7);
         end case;
      end Address_Image;

      function Decimal_U64_Image (Value : Interfaces.Unsigned_64) return String is
         Decimal_Digit : constant String := "0123456789";
         Result : String (1 .. 20) := [others => '0'];
         Work   : Interfaces.Unsigned_64 := Value;
         First  : Positive := Result'Last;
      begin
         loop
            Result (First) := Decimal_Digit (Natural (Work mod 10) + 1);
            Work := Work / 10;
            exit when Work = 0;
            First := First - 1;
         end loop;
         return Result (First .. Result'Last);
      end Decimal_U64_Image;

      function Hex_U64_Image (Value : Interfaces.Unsigned_64; Width : Positive) return String is
         Hex_Digit : constant String := "0123456789abcdef";
         Result : String (1 .. Width) := [others => '0'];
         Work   : Interfaces.Unsigned_64 := Value;
      begin
         for I in reverse Result'Range loop
            Result (I) := Hex_Digit (Natural (Work mod 16) + 1);
            Work := Work / 16;
         end loop;
         return Result;
      end Hex_U64_Image;

      function Octal_U64_Image (Value : Interfaces.Unsigned_64; Width : Positive) return String is
         Octal_Digit : constant String := "01234567";
         Result : String (1 .. Width) := [others => '0'];
         Work   : Interfaces.Unsigned_64 := Value;
      begin
         for I in reverse Result'Range loop
            Result (I) := Octal_Digit (Natural (Work mod 8) + 1);
            Work := Work / 8;
         end loop;
         return Result;
      end Octal_U64_Image;

      function Floating_Image (Value : Interfaces.Unsigned_64; Size : Positive) return String is
         subtype U32 is Interfaces.Unsigned_32;
         subtype U64 is Interfaces.Unsigned_64;
         function To_Float_32 is new Ada.Unchecked_Conversion (U32, Interfaces.IEEE_Float_32);
         function To_Float_64 is new Ada.Unchecked_Conversion (U64, Interfaces.IEEE_Float_64);
      begin
         if Size = 4 then
            return Interfaces.IEEE_Float_32'Image (To_Float_32 (U32 (Value)));
         else
            return Interfaces.IEEE_Float_64'Image (To_Float_64 (Value));
         end if;
      end Floating_Image;

      function Set_Address_Base (Spec : String) return Boolean is
      begin
         if Spec = "n" then
            Address := No_Address;
         elsif Spec = "o" then
            Address := Octal_Address;
         elsif Spec = "d" then
            Address := Decimal_Address;
         elsif Spec = "x" then
            Address := Hex_Address;
         else
            return False;
         end if;
         return True;
      end Set_Address_Base;

      function Named_Field (Item : Character) return String is
         Names : constant array (Natural range 0 .. 127) of String (1 .. 3) :=
           [0 => "nul", 1 => "soh", 2 => "stx", 3 => "etx", 4 => "eot", 5 => "enq", 6 => "ack", 7 => "bel",
            8 => " bs", 9 => " ht", 10 => " nl", 11 => " vt", 12 => " ff", 13 => " cr", 14 => " so", 15 => " si",
            16 => "dle", 17 => "dc1", 18 => "dc2", 19 => "dc3", 20 => "dc4", 21 => "nak", 22 => "syn",
            23 => "etb", 24 => "can", 25 => " em", 26 => "sub", 27 => "esc", 28 => " fs", 29 => " gs",
            30 => " rs", 31 => " us", 32 => " sp", 127 => "del", others => "   "];
         Value : constant Natural := Character'Pos (Item) mod 128;
      begin
         if Value in 33 .. 126 then
            return "   " & Character'Val (Value);
         else
            return " " & Names (Value);
         end if;
      end Named_Field;

      function Character_Field (Item : Character) return String is
      begin
         case Item is
            when NUL =>
               return "  \\0";
            when BS =>
               return "  \\b";
            when HT =>
               return "  \\t";
            when LF =>
               return "  \\n";
            when FF =>
               return "  \\f";
            when CR =>
               return "  \\r";
            when ' ' .. '~' =>
               return "   " & Item;
            when others =>
               return " " & Octal_Image (Character'Pos (Item), 3);
         end case;
      end Character_Field;

      function Parse_Offset_Count
        (Text         : String;
         Allow_Suffix : Boolean;
         Value        : out Natural) return Boolean
      is
         Base       : Natural := 10;
         Index      : Positive := Text'First;
         Last_Index : Natural := Text'Last;
         Multiplier : Natural := 1;
      begin
         Value := 0;
         if Text = "" then
            return False;
         elsif Text'Length > 2
           and then Text (Text'First) = '0'
           and then Text (Text'First + 1) in 'x' | 'X'
         then
            Base := 16;
            Index := Text'First + 2;
         elsif Text'Length > 1 and then Text (Text'First) = '0' then
            Base := 8;
         end if;

         if Allow_Suffix and then Base /= 16 and then Last_Index >= Index then
            case Text (Last_Index) is
               when 'b' =>
                  Multiplier := 512;
                  Last_Index := Last_Index - 1;
               when 'k' =>
                  Multiplier := 1_024;
                  Last_Index := Last_Index - 1;
               when 'm' =>
                  Multiplier := 1_048_576;
                  Last_Index := Last_Index - 1;
               when others =>
                  null;
            end case;
         end if;

         if Index > Last_Index then
            return False;
         end if;

         while Index <= Last_Index loop
            declare
               Digit : Natural;
            begin
               if Text (Index) in '0' .. '9' then
                  Digit := Character'Pos (Text (Index)) - Character'Pos ('0');
               elsif Text (Index) in 'a' .. 'f' then
                  Digit := Character'Pos (Text (Index)) - Character'Pos ('a') + 10;
               elsif Text (Index) in 'A' .. 'F' then
                  Digit := Character'Pos (Text (Index)) - Character'Pos ('A') + 10;
               else
                  return False;
               end if;

               if Digit >= Base or else Value > (Natural'Last - Digit) / Base then
                  return False;
               end if;
               Value := Value * Base + Digit;
               Index := Index + 1;
            end;
         end loop;
         if Value > Natural'Last / Multiplier then
            return False;
         end if;
         Value := Value * Multiplier;
         return True;
      end Parse_Offset_Count;

      function Type_Size (Marker : Character; Default : Positive; Size : out Positive) return Boolean is
      begin
         case Marker is
            when '0' =>
               Size := Default;
            when 'C' =>
               Size := 1;
            when 'S' =>
               Size := 2;
            when 'I' =>
               Size := 4;
            when 'L' =>
               Size := 8;
            when others =>
               return False;
         end case;
         return True;
      end Type_Size;

      function Append_Dump_Formats (Spec : String) return Boolean is
         Index : Positive := Spec'First;
      begin
         if Spec = "" then
            return False;
         end if;

         while Index <= Spec'Last loop
            declare
               Kind : Dump_Kind;
               Default_Size : Positive := 1;
               Size : Positive := 1;
            begin
               case Spec (Index) is
                  when 'a' =>
                     Formats.Append (Dump_Spec'(Kind => Named_Byte, Size => 1));
                     Index := Index + 1;
                     goto Continue;
                  when 'c' =>
                     Formats.Append (Dump_Spec'(Kind => Character_Byte, Size => 1));
                     Index := Index + 1;
                     goto Continue;
                  when 'd' =>
                     Kind := Signed_Integer;
                     Default_Size := 2;
                  when 'f' =>
                     Kind := Floating_Point;
                     Default_Size := 8;
                  when 'o' =>
                     Kind := Octal_Integer;
                     Default_Size := 2;
                  when 'u' =>
                     Kind := Unsigned_Integer;
                     Default_Size := 2;
                  when 'x' =>
                     Kind := Hex_Integer;
                     Default_Size := 2;
                  when others =>
                     return False;
               end case;

               Index := Index + 1;
               if Index <= Spec'Last and then Spec (Index) in '0' .. '9' then
                  declare
                     Value : Natural := 0;
                     Start : constant Positive := Index;
                  begin
                     while Index <= Spec'Last and then Spec (Index) in '0' .. '9' loop
                        if Value > (Natural'Last - (Character'Pos (Spec (Index)) - Character'Pos ('0'))) / 10 then
                           return False;
                        end if;
                        Value := Value * 10 + Character'Pos (Spec (Index)) - Character'Pos ('0');
                        Index := Index + 1;
                     end loop;
                     if Value not in 1 | 2 | 4 | 8 then
                        return False;
                     end if;
                     pragma Assert (Start <= Spec'Last);
                     Size := Positive (Value);
                  end;
               elsif Index <= Spec'Last and then Spec (Index) in 'C' | 'S' | 'I' | 'L' | 'F' | 'D' then
                  if Kind = Floating_Point then
                     case Spec (Index) is
                        when 'F' =>
                           Size := 4;
                        when 'D' | 'L' =>
                           Size := 8;
                        when others =>
                           return False;
                     end case;
                  elsif not Type_Size (Spec (Index), Default_Size, Size) then
                     return False;
                  end if;
                  Index := Index + 1;
               else
                  Size := Default_Size;
               end if;

               if Kind = Floating_Point and then Size not in 4 | 8 then
                  return False;
               end if;

               Formats.Append (Dump_Spec'(Kind => Kind, Size => Size));
               <<Continue>>
            end;
         end loop;
         return True;
      end Append_Dump_Formats;

      procedure Set_Required_Number_Option
        (Option  : String;
         Text    : String;
         Present : Boolean;
         Target  : out Natural;
         Valid   : out Boolean)
      is
      begin
         if not Present then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "missing option argument '" & Option & "'");
            Valid := False;
         elsif not Parse_Offset_Count (Text, Option = "-j", Target) then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid operand '" & Text & "'");
            Valid := False;
         else
            Valid := True;
         end if;
      end Set_Required_Number_Option;

      function Unit_Value (Text : String; First : Positive; Size : Positive) return Interfaces.Unsigned_64 is
         Value : Interfaces.Unsigned_64 := 0;
      begin
         for Offset in 0 .. Size - 1 loop
            declare
               Index : constant Natural := First + Offset;
               Byte  : constant Interfaces.Unsigned_64 :=
                 (if Index <= Text'Last then Interfaces.Unsigned_64 (Character'Pos (Text (Index))) else 0);
            begin
               Value := Value or Interfaces.Shift_Left (Byte, Offset * 8);
            end;
         end loop;
         return Value;
      end Unit_Value;

      function Signed_Image (Value : Interfaces.Unsigned_64; Size : Positive) return String is
         Bits : constant Natural := Size * 8;
         Sign_Bit : constant Interfaces.Unsigned_64 := Interfaces.Shift_Left (1, Bits - 1);
      begin
         if (Value and Sign_Bit) = 0 then
            return Decimal_U64_Image (Value);
         elsif Size = 8 then
            return "-" & Decimal_U64_Image (Interfaces.Unsigned_64'Last - Value + 1);
         else
            return "-" & Decimal_U64_Image (Interfaces.Shift_Left (1, Bits) - Value);
         end if;
      end Signed_Image;

      function Unit_Field (Spec : Dump_Spec; Text : String; First : Positive) return String is
         Value : constant Interfaces.Unsigned_64 := Unit_Value (Text, First, Spec.Size);
      begin
         case Spec.Kind is
            when Named_Byte =>
               return Named_Field (Text (First));
            when Character_Byte =>
               return Character_Field (Text (First));
            when Signed_Integer =>
               return " " & Signed_Image (Value, Spec.Size);
            when Floating_Point =>
               return " " & Floating_Image (Value, Spec.Size);
            when Octal_Integer =>
               return " " & Octal_U64_Image (Value, Spec.Size * 3);
            when Unsigned_Integer =>
               return " " & Decimal_U64_Image (Value);
            when Hex_Integer =>
               return " " & Hex_U64_Image (Value, Spec.Size * 2);
         end case;
      end Unit_Field;

      function Append_Shorthand_Format (Option : Character) return Boolean is
      begin
         case Option is
            when 'a' =>
               Formats.Append (Dump_Spec'(Kind => Named_Byte, Size => 1));
            when 'b' =>
               Formats.Append (Dump_Spec'(Kind => Octal_Integer, Size => 1));
            when 'c' =>
               Formats.Append (Dump_Spec'(Kind => Character_Byte, Size => 1));
            when 'd' =>
               Formats.Append (Dump_Spec'(Kind => Unsigned_Integer, Size => 2));
            when 'o' =>
               Formats.Append (Dump_Spec'(Kind => Octal_Integer, Size => 2));
            when 's' =>
               Formats.Append (Dump_Spec'(Kind => Signed_Integer, Size => 2));
            when 'x' =>
               Formats.Append (Dump_Spec'(Kind => Hex_Integer, Size => 2));
            when others =>
               return False;
         end case;
         return True;
      end Append_Shorthand_Format;

      function Append_Shorthand_Formats (Option : String) return Boolean is
      begin
         if Option'Length <= 1 then
            return False;
         end if;

         for I in Option'First + 1 .. Option'Last loop
            if Option (I) not in 'a' | 'b' | 'c' | 'd' | 'o' | 's' | 'x' then
               return False;
            end if;
         end loop;

         for I in Option'First + 1 .. Option'Last loop
            if not Append_Shorthand_Format (Option (I)) then
               return False;
            end if;
         end loop;
         return True;
      end Append_Shorthand_Formats;
   begin
      while First <= Context.Argument_Count and then Context.Argument (First)'Length > 0
        and then Context.Argument (First) (Context.Argument (First)'First) = '-'
      loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First) in "-a" | "-b" | "-c" | "-d" | "-o" | "-s" | "-x" then
            if not Append_Shorthand_Format (Context.Argument (First) (Context.Argument (First)'First + 1)) then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (First) & "'");
               return;
            end if;
            First := First + 1;
         elsif Context.Argument (First) = "-v" then
            Verbose := True;
            First := First + 1;
         elsif Context.Argument (First) = "-A" then
            if First >= Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "missing option argument '-A'");
               return;
            elsif not Set_Address_Base (Context.Argument (First + 1)) then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (First + 1) & "'");
               return;
            end if;
            First := First + 2;
         elsif Context.Argument (First)'Length > 2
           and then Context.Argument (First) (Context.Argument (First)'First .. Context.Argument (First)'First + 1)
             = "-A"
         then
            if not Set_Address_Base
              (Context.Argument (First) (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last))
            then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '"
                  & Context.Argument (First) (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last)
                  & "'");
               return;
            end if;
            First := First + 1;
         elsif Context.Argument (First) = "-j" then
            declare
               Valid : Boolean;
            begin
               Set_Required_Number_Option
                 ("-j",
                  (if First < Context.Argument_Count then Context.Argument (First + 1) else ""),
                  First < Context.Argument_Count,
                  Skip,
                  Valid);
               if not Valid then
                  return;
               end if;
            end;
            First := First + 2;
         elsif Context.Argument (First)'Length > 2
           and then Context.Argument (First) (Context.Argument (First)'First .. Context.Argument (First)'First + 1)
             = "-j"
         then
            declare
               Valid : Boolean;
            begin
               Set_Required_Number_Option
                 ("-j",
                  Context.Argument (First) (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last),
                  True,
                  Skip,
                  Valid);
               if not Valid then
                  return;
               end if;
            end;
            First := First + 1;
         elsif Context.Argument (First) = "-N" then
            declare
               Valid : Boolean;
            begin
               Set_Required_Number_Option
                 ("-N",
                  (if First < Context.Argument_Count then Context.Argument (First + 1) else ""),
                  First < Context.Argument_Count,
                  Limit,
                  Valid);
               if not Valid then
                  return;
               end if;
            end;
            Has_Limit := True;
            First := First + 2;
         elsif Context.Argument (First)'Length > 2
           and then Context.Argument (First) (Context.Argument (First)'First .. Context.Argument (First)'First + 1)
             = "-N"
         then
            declare
               Valid : Boolean;
            begin
               Set_Required_Number_Option
                 ("-N",
                  Context.Argument (First) (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last),
                  True,
                  Limit,
                  Valid);
               if not Valid then
                  return;
               end if;
            end;
            Has_Limit := True;
            First := First + 1;
         elsif Context.Argument (First) = "-t" then
            if First >= Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "missing option argument '-t'");
               return;
            elsif not Append_Dump_Formats (Context.Argument (First + 1)) then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (First + 1) & "'");
               return;
            end if;
            First := First + 2;
         elsif Context.Argument (First)'Length > 2
           and then Context.Argument (First) (Context.Argument (First)'First .. Context.Argument (First)'First + 1)
             = "-t"
         then
            if not Append_Dump_Formats
              (Context.Argument (First) (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last))
            then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '"
                  & Context.Argument (First) (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last)
                  & "'");
               return;
            end if;
            First := First + 1;
         elsif Context.Argument (First)'Length > 2
           and then Append_Shorthand_Formats (Context.Argument (First))
         then
            First := First + 1;
         else
            exit;
         end if;
      end loop;
      if Formats.Is_Empty then
         Formats.Append (Dump_Spec'(Kind => Octal_Integer, Size => 2));
      end if;
      if Context.Argument_Count < First then
         Read_All (Context, "-", Data, Ok);
      else
         for I in First .. Context.Argument_Count loop
            declare
               Chunk : Unbounded_String;
            begin
               Read_All (Context, Context.Argument (I), Chunk, Ok);
               exit when not Ok;
               Append (Data, To_String (Chunk));
            end;
         end loop;
      end if;
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      declare
         Source : constant String := To_String (Data);
         Actual_Skip : constant Natural := Natural'Min (Skip, Source'Length);
         Available : constant Natural := Source'Length - Actual_Skip;
         Selected_Length : constant Natural := (if Has_Limit then Natural'Min (Limit, Available) else Available);
         Text   : constant String :=
           (if Selected_Length = 0 then ""
            else Source (Source'First + Actual_Skip .. Source'First + Actual_Skip + Selected_Length - 1));
         Offset : Natural := 0;
         Previous_Block : String_Vectors.Vector;
         Have_Previous  : Boolean := False;
         Suppressed     : Boolean := False;
      begin
         if Skip > Source'Length then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.resource.count_too_large", "count too large");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         while Offset < Text'Length loop
            declare
               Line_Last : constant Natural := Natural'Min (Text'Length, Offset + 16);
               Current_Block : String_Vectors.Vector;
            begin
               for Format_Index in Formats.First_Index .. Formats.Last_Index loop
                  declare
                     Spec : constant Dump_Spec := Formats.Element (Format_Index);
                     Output : Unbounded_String;
                  begin
                     declare
                        I : Natural := Text'First + Offset;
                     begin
                        while I <= Text'First + Line_Last - 1 loop
                           Append (Output, Unit_Field (Spec, Text, I));
                           I := I + Spec.Size;
                        end loop;
                     end;
                     Current_Block.Append (To_String (Output));
                  end;
               end loop;

               if not Verbose and then Have_Previous and then String_Vectors."=" (Current_Block, Previous_Block) then
                  if not Suppressed then
                     Context.Put_Line ("*");
                     Suppressed := True;
                  end if;
               else
                  for Format_Index in Current_Block.First_Index .. Current_Block.Last_Index loop
                     Context.Put_Line
                       ((if Address = No_Address or else Format_Index /= Current_Block.First_Index
                         then ""
                         else Address_Image (Actual_Skip + Offset))
                        & Current_Block.Element (Format_Index));
                  end loop;
                  Previous_Block := Current_Block;
                  Have_Previous := True;
                  Suppressed := False;
               end if;
               Offset := Line_Last;
            end;
         end loop;
         if Address /= No_Address then
            Context.Put_Line (Address_Image (Actual_Skip + Text'Length));
         end if;
      end;
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run_Od;

   procedure Run_Ls
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      type Hidden_Mode is (Hide_Hidden, Almost_All, All_Entries);

      Hidden        : Hidden_Mode := Hide_Hidden;
      Directory_As_File : Boolean := False;
      First         : Positive := 1;
      Ok            : Boolean := True;
      Emitted       : Boolean := False;

      procedure Emit_Line (Text : String) is
      begin
         Context.Put_Line (Text);
         Emitted := True;
      end Emit_Line;

      function Visible (Name : String) return Boolean is
      begin
         case Hidden is
            when All_Entries =>
               return True;
            when Almost_All =>
               return Name /= "." and then Name /= "..";
            when Hide_Hidden =>
               return Name = "" or else Name (Name'First) /= '.';
         end case;
      end Visible;

      procedure List_Path (Path : String; With_Header : Boolean) is
         Names : String_Vectors.Vector;
         Listed : Boolean := True;

         procedure Add_Entry (Name : String; Full_Name : String; Stop : in out Boolean) is
            pragma Unreferenced (Full_Name, Stop);
         begin
            if Visible (Name) then
               Names.Append (Name);
            end if;
         end Add_Entry;

         procedure Each is new FS.For_Each_Directory_Entry (Add_Entry);
      begin
         if FS.Kind (Path) = FS.Directory and then not Directory_As_File then
            if With_Header then
               if Emitted then
                  Context.Put_Line ("");
               end if;
               Emit_Line (Path & ":");
            end if;
            Each (Path, Listed);
            if not Listed then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Path, "posix_tools.diagnostic.file.read_failed", "cannot read file");
               return;
            end if;
            String_Vector_Sorting.Sort (Names);
            for Name of Names loop
               Emit_Line (Name);
            end loop;
         elsif FS.Exists (Path) then
            Emit_Line (Path);
         else
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.read_failed", "cannot read file");
         end if;
      end List_Path;
   begin
      while First <= Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (First);
         begin
            if Arg = "--" then
               First := First + 1;
               exit;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when '1' => null;
                     when 'a' => Hidden := All_Entries;
                     when 'A' =>
                        if Hidden /= All_Entries then
                           Hidden := Almost_All;
                        end if;
                     when 'd' => Directory_As_File := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                        return;
                  end case;
               end loop;
               First := First + 1;
            else
               exit;
            end if;
         end;
      end loop;
      if Context.Argument_Count < First then
         List_Path (".", False);
      else
         for I in First .. Context.Argument_Count loop
            List_Path
              (Context.Argument (I),
               With_Header =>
                 Context.Argument_Count - First + 1 > 1
                 and then FS.Kind (Context.Argument (I)) = FS.Directory
                 and then not Directory_As_File);
         end loop;
      end if;
      Result.Status :=
        (if Ok and then not Context.Output_Failed then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run_Ls;

   procedure Run_Split
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Lines_Per_File : Natural := 1000;
      Bytes_Per_File : Natural := 0;
      Suffix_Length  : Positive := 2;
      First          : Positive := 1;
      Input          : Unbounded_String := To_Unbounded_String ("-");
      Prefix         : Unbounded_String := To_Unbounded_String ("x");
      Data           : Unbounded_String;
      Ok             : Boolean;

      function Suffix_Capacity return Natural is
         Result : Natural := 1;
      begin
         for I in 1 .. Suffix_Length loop
            if Result > Natural'Last / 26 then
               return Natural'Last;
            end if;
            Result := Result * 26;
         end loop;
         return Result;
      end Suffix_Capacity;

      function Suffix (Index : Natural) return String is
         Result : String (1 .. Suffix_Length) := [others => 'a'];
         Work   : Natural := Index;
      begin
         for I in reverse Result'Range loop
            Result (I) := Character'Val (Character'Pos ('a') + Work mod 26);
            Work := Work / 26;
         end loop;
         return Result;
      end Suffix;

      function Write_Output (Name, Text : String) return Boolean is
         File : Ada.Streams.Stream_IO.File_Type;
      begin
         Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Name);
         for Ch of Text loop
            declare
               Item : Ada.Streams.Stream_Element_Array (1 .. 1);
            begin
               Item (1) := Ada.Streams.Stream_Element (Character'Pos (Ch));
               Ada.Streams.Stream_IO.Write (File, Item);
            end;
         end loop;
         Ada.Streams.Stream_IO.Close (File);
         return True;
      exception
         when others =>
            if Ada.Streams.Stream_IO.Is_Open (File) then
               Ada.Streams.Stream_IO.Close (File);
            end if;
            return False;
      end Write_Output;
   begin
      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "-a" and then First < Context.Argument_Count then
            declare
               Parsed : Natural;
            begin
               if not Parse_Natural_Text (Context.Argument (First + 1), Parsed)
                 or else Parsed = 0
                 or else Parsed > 12
               then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Context.Argument (First + 1) & "'");
                  return;
               end if;
               Suffix_Length := Positive (Parsed);
            end;
            First := First + 2;
         elsif Context.Argument (First) = "-l" and then First < Context.Argument_Count then
            if not Parse_Natural_Text (Context.Argument (First + 1), Lines_Per_File)
              or else Lines_Per_File = 0
            then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (First + 1) & "'");
               return;
            end if;
            First := First + 2;
         elsif Context.Argument (First) = "-b" and then First < Context.Argument_Count then
            if not Parse_Natural_Text (Context.Argument (First + 1), Bytes_Per_File)
              or else Bytes_Per_File = 0
            then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (First + 1) & "'");
               return;
            end if;
            First := First + 2;
         elsif Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First) = "-a"
           or else Context.Argument (First) = "-l"
           or else Context.Argument (First) = "-b"
         then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "missing option argument '" & Context.Argument (First) & "'");
            return;
         else
            exit;
         end if;
      end loop;
      declare
         Remaining : constant Natural :=
           (if First > Context.Argument_Count then 0 else Context.Argument_Count - First + 1);
      begin
         if Remaining > 2 then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "extra operand '" & Context.Argument (First + 2) & "'");
            return;
         elsif Remaining >= 1 then
            Input := To_Unbounded_String (Context.Argument (First));
            if Remaining = 2 then
               Prefix := To_Unbounded_String (Context.Argument (First + 1));
            end if;
         end if;
      end;

      Read_All (Context, To_String (Input), Data, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      declare
         Text  : constant String := To_String (Data);
         Start : Positive := 1;
         Part  : Natural := 0;
      begin
         while Start <= Text'Length loop
            declare
               Last : Natural := Start - 1;
            begin
               if Bytes_Per_File > 0 then
                  Last := Natural'Min (Text'Length, Start + Bytes_Per_File - 1);
               else
                  for Count in 1 .. Lines_Per_File loop
                     exit when Last >= Text'Length;
                     Last := Last + 1;
                     while Last < Text'Length and then Text (Last) /= LF loop
                        Last := Last + 1;
                     end loop;
                  end loop;
               end if;
               if Part >= Suffix_Capacity then
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context,
                     To_String (Prefix),
                     "posix_tools.diagnostic.resource.limit",
                     "resource limit exceeded");
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                  return;
               end if;
               if not Write_Output (To_String (Prefix) & Suffix (Part), Text (Start .. Last)) then
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context,
                     To_String (Prefix) & Suffix (Part),
                     "posix_tools.diagnostic.file.open_failed",
                     "cannot open file");
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                  return;
               end if;
               Part := Part + 1;
               Start := Last + 1;
            end;
         end loop;
      end;
      Set_Success (Context, Result);
   end Run_Split;

   procedure Run
     (Command : Expanded_Command;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      case Command is
         when Chgrp_Command => Run_Chgrp (Context, Result);
         when Chmod_Command => Run_Chmod (Context, Result);
         when Chown_Command => Run_Chown (Context, Result);
         when Cksum_Command => Run_Cksum (Context, Result);
         when Cmp_Command => Run_Cmp (Context, Result);
         when Comm_Command => Run_Comm (Context, Result);
         when Cp_Command => Run_Cp (Context, Result);
         when Cut_Command => Run_Cut (Context, Result);
         when Date_Command => Run_Date (Context, Result);
         when Dd_Command => Run_Dd (Context, Result);
         when Env_Command => Run_Env (Context, Result);
         when File_Command => Run_File (Context, Result);
         when Find_Command => Run_Find (Context, Result);
         when Id_Command => Run_Id (Context, Result);
         when Kill_Command => Run_Kill (Context, Result);
         when Link_Command => Run_Link (Context, Result);
         when Ln_Command => Run_Ln (Context, Result);
         when Logname_Command => Run_Logname (Context, Result);
         when Ls_Command => Run_Ls (Context, Result);
         when Mkdir_Command => Run_Mkdir (Context, Result);
         when Mv_Command => Run_Mv (Context, Result);
         when Od_Command => Run_Od (Context, Result);
         when Paste_Command => Run_Paste (Context, Result);
         when Pathchk_Command => Run_Pathchk (Context, Result);
         when Printf_Command => Run_Printf (Context, Result);
         when Readlink_Command => Run_Readlink (Context, Result);
         when Realpath_Command => Run_Realpath (Context, Result);
         when Rm_Command => Run_Rm (Context, Result);
         when Rmdir_Command => Run_Rmdir (Context, Result);
         when Sleep_Command => Run_Sleep (Context, Result);
         when Split_Command => Run_Split (Context, Result);
         when Sort_Command => Run_Sort (Context, Result);
         when Tee_Command => Run_Tee (Context, Result);
         when Test_Command => Run_Test (Context, Result);
         when Timeout_Command => Run_Timeout (Context, Result);
         when Touch_Command => Run_Touch (Context, Result);
         when Tr_Command => Run_Tr (Context, Result);
         when Tty_Command => Run_Tty (Context, Result);
         when Uname_Command => Run_Uname (Context, Result);
         when Uniq_Command => Run_Uniq (Context, Result);
         when Whoami_Command => Run_Whoami (Context, Result);
         when Xargs_Command => Run_Xargs (Context, Result);
      end case;
   end Run;
end Posix_Tools.Commands.Expanded;
