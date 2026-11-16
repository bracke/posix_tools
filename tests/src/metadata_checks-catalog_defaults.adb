with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Metadata_Checks.Ada_Lexing;
with Project_Tools.Files;
with Posix_Tools.Text.Line_Breaks;
with Tooling_Checks;
with Tooling_Support;

package body Metadata_Checks.Catalog_Defaults is
   use Ada.Strings.Unbounded;

   LF    : constant Character := ASCII.LF;
   Quote : constant Character := Character'Val (39);

   package Text_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type     => String,
      Element_Type => Unbounded_String);

   package Text_Sets is new Ada.Containers.Indefinite_Ordered_Sets (String);

   type Validation_Result is record
      Valid  : Boolean;
      Detail : Unbounded_String;
   end record;

   function Is_Valid_Key (Key : String) return Boolean is
      At_Segment_Start : Boolean := True;
   begin
      if Key = "" then
         return False;
      end if;
      for Ch of Key loop
         if Ch = '.' then
            if At_Segment_Start then
               return False;
            end if;
            At_Segment_Start := True;
         elsif Ch in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' then
            At_Segment_Start := False;
         else
            return False;
         end if;
      end loop;
      return not At_Segment_Start;
   end Is_Valid_Key;

   function Validate_Defaults
     (Catalog : String;
      Raw     : String) return Validation_Result
   is
      Catalog_Defaults : Text_Maps.Map;
      Catalog_Entries  : Text_Maps.Map;
      Catalog_Locales  : Text_Sets.Set;
      Source_Defaults  : Text_Maps.Map;
      Problem          : Unbounded_String;
      Start            : Positive := Catalog'First;
      Catalog_Line     : Positive := 1;
      Saw_Default_Locale : Boolean := False;

      function Entry_Name (Locale, Key : String) return String is
        (Locale & Character'Val (0) & Key);

      procedure Add
        (Items : in out Text_Maps.Map;
         Key   : String;
         Value : String) is
      begin
         if Items.Contains (Key) then
            if Length (Problem) = 0 then
               Problem := To_Unbounded_String (Key);
            end if;
         else
            Items.Insert (Key, To_Unbounded_String (Value));
         end if;
      end Add;

      procedure Check_Catalog_Line
        (Raw_Line    : String;
         Line_Number : Positive)
      is
         Line      : constant String :=
           Posix_Tools.Text.Line_Breaks.Without_Trailing_CR (Raw_Line);
         Separator : constant Natural :=
           Ada.Strings.Fixed.Index (Line, " = ");
         Dot       : constant Natural :=
           Ada.Strings.Fixed.Index (Line, ".");

         procedure Reject is
         begin
            if Length (Problem) = 0 then
               Problem := To_Unbounded_String
                 ("malformed catalog line" & Positive'Image (Line_Number));
            end if;
         end Reject;

         function Is_Valid_Locale (Locale : String) return Boolean is
           (Locale /= ""
            and then
              (for all Ch of Locale =>
                 Ch in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '-'));
      begin
         if Line = ""
           or else Line (Line'First) = '#'
         then
            return;
         elsif Line = "default_locale = en" then
            if Saw_Default_Locale then
               Reject;
            else
               Saw_Default_Locale := True;
            end if;
            return;
         elsif Line (Line'First) in ' ' | Character'Val (9)
           or else Separator = 0
           or else Dot = 0
           or else Dot >= Separator
           or else not Is_Valid_Locale (Line (Line'First .. Dot - 1))
           or else not Is_Valid_Key (Line (Dot + 1 .. Separator - 1))
         then
            Reject;
            return;
         end if;

         declare
            Locale : constant String := Line (Line'First .. Dot - 1);
            Key    : constant String := Line (Dot + 1 .. Separator - 1);
            Text   : constant String := Line (Separator + 3 .. Line'Last);
            Composite : constant String := Entry_Name (Locale, Key);
            Plain  : Unbounded_String;
            Index  : Natural := Text'First;
         begin
            while Index <= Text'Last loop
               Append (Plain, Text (Index));
               if Text (Index) = Quote
                 and then Index < Text'Last
                 and then Text (Index + 1) = Quote
               then
                  Index := Index + 1;
               end if;
               Index := Index + 1;
            end loop;

            Catalog_Locales.Include (Locale);
            if Catalog_Entries.Contains (Composite) then
               if Length (Problem) = 0 then
                  Problem := To_Unbounded_String (Locale & "." & Key);
               end if;
            else
               Catalog_Entries.Insert (Composite, Plain);
               if Locale = "en" then
                  Add (Catalog_Defaults, Key, To_String (Plain));
               end if;
            end if;
         end;
      end Check_Catalog_Line;

      procedure Parse_Source is
         Marker : constant String := "key = """;
         Lower_Raw : constant String :=
           Ada.Characters.Handling.To_Lower (Raw);
         Code : String (Raw'Range) := [others => ' '];
         Body_First : Natural := 0;
         Body_Last  : Natural := 0;
         Cursor     : Natural := Raw'First;
         Expected_Branch_Start : Natural := 0;
         First_Branch : Boolean := True;

         function Is_Whitespace (Ch : Character) return Boolean is
           (Ch in ' ' | Character'Val (9) | Character'Val (10)
              | Character'Val (13));

         function Is_Identifier_Character (Ch : Character) return Boolean is
           (Ch in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_');

         function Only_Whitespace
           (First : Natural;
            Last  : Natural) return Boolean
         is
         begin
            return First > Last
              or else
                (for all Index in First .. Last => Is_Whitespace (Code (Index)));
         end Only_Whitespace;

         procedure Locate_Template_Body is
            Lower_Code : constant String :=
              Ada.Characters.Handling.To_Lower (Code);
            Function_At : constant Natural :=
              Ada.Strings.Fixed.Index (Lower_Code, "function template");
            Begin_At : constant Natural :=
              (if Function_At = 0
               then 0
               else Ada.Strings.Fixed.Index
                 (Lower_Code, "begin", Function_At));
            End_At : constant Natural :=
              (if Begin_At = 0
               then 0
               else Ada.Strings.Fixed.Index
                 (Lower_Code, "end template;", Begin_At + 5));
         begin
            if Function_At = 0
              or else Begin_At = 0
              or else End_At = 0
              or else Ada.Strings.Fixed.Index
                (Lower_Code, "function template", Function_At + 1) /= 0
            then
               Problem := To_Unbounded_String ("Template function");
               return;
            end if;
            Body_First := Begin_At + 5;
            Body_Last := End_At - 1;
            Cursor := Body_First;
            Expected_Branch_Start := Body_First;
         end Locate_Template_Body;

         function Next_Code_Key (From : Natural) return Natural is
            Search_From : Natural := From;
         begin
            loop
               declare
                  Candidate : constant Natural :=
                    Ada.Strings.Fixed.Index
                      (Lower_Raw, Marker, Search_From);
               begin
                  if Candidate = 0 or else Candidate > Body_Last then
                     return 0;
                  elsif Candidate < Body_First then
                     Search_From := Body_First;
                  elsif
                    Ada.Characters.Handling.To_Lower
                      (Code (Candidate .. Candidate + 2)) = "key"
                  then
                     return Candidate;
                  else
                     Search_From := Candidate + Marker'Length;
                  end if;
               end;
            end loop;
         end Next_Code_Key;

         procedure Validate_Tail is
            Position  : Natural := Expected_Branch_Start;
            Quote_At  : Natural;
            Semicolon : Natural;

            function Next_Code (From : Natural) return Natural is
               Result : Natural := From;
            begin
               while Result <= Body_Last
                 and then Is_Whitespace (Code (Result))
               loop
                  Result := Result + 1;
               end loop;
               return Result;
            end Next_Code;

            procedure Consume_Keyword
              (Keyword : String;
               Valid   : in out Boolean) is
            begin
               Position := Next_Code (Position);
               if Position > Body_Last
                 or else Keyword'Length > Body_Last - Position + 1
                 or else Ada.Characters.Handling.To_Lower
                   (Code (Position .. Position + Keyword'Length - 1)) /=
                     Keyword
                 or else
                   (Position + Keyword'Length <= Body_Last
                    and then Is_Identifier_Character
                      (Code (Position + Keyword'Length)))
               then
                  Valid := False;
               else
                  Position := Position + Keyword'Length;
               end if;
            end Consume_Keyword;

            Valid : Boolean := True;
         begin
            if Source_Defaults.Is_Empty then
               Problem := To_Unbounded_String
                 (if Catalog_Defaults.Is_Empty
                  then "Template defaults"
                  else Text_Maps.Key (Catalog_Defaults.First));
               return;
            end if;

            Consume_Keyword ("else", Valid);
            Consume_Keyword ("return", Valid);
            if not Valid then
               Problem := To_Unbounded_String ("Template fallback");
               return;
            end if;

            Quote_At := Ada.Strings.Fixed.Index (Code, """", Position);
            Semicolon := Ada.Strings.Fixed.Index (Code, ";", Position);
            if Quote_At = 0
              or else Semicolon = 0
              or else Quote_At + 1 > Body_Last
              or else Quote_At > Semicolon
              or else Code (Quote_At .. Quote_At + 1) /= """"""
              or else Raw (Quote_At .. Quote_At + 1) /= """"""
              or else not Only_Whitespace (Position, Quote_At - 1)
              or else not Only_Whitespace (Quote_At + 2, Semicolon - 1)
            then
               Problem := To_Unbounded_String ("Template fallback");
               return;
            end if;

            Position := Semicolon + 1;
            Consume_Keyword ("end", Valid);
            Consume_Keyword ("if", Valid);
            Position := Next_Code (Position);
            if not Valid
              or else Position > Body_Last
              or else Code (Position) /= ';'
              or else not Only_Whitespace (Position + 1, Body_Last)
            then
               Problem := To_Unbounded_String ("Template fallback");
            end if;
         end Validate_Tail;
      begin
         Code := Metadata_Checks.Ada_Lexing.Code_View (Raw);
         Locate_Template_Body;
         if Length (Problem) > 0 then
            return;
         end if;
         while Cursor <= Raw'Last loop
            declare
               At_Key : constant Natural :=
                 Next_Code_Key (Cursor);
            begin
               exit when At_Key = 0;
               declare
                  Key_First : constant Natural := At_Key + Marker'Length;
                  Closing   : constant Natural :=
                    Ada.Strings.Fixed.Index (Raw, """", Key_First);
               begin
                  if Closing = 0 then
                     Problem := To_Unbounded_String ("malformed source default");
                     return;
                  end if;

                  declare
                     Key       : constant String :=
                       Raw (Key_First .. Closing - 1);
                     Before    : Natural := At_Key - 1;
                     After     : Natural := Closing + 1;
                     Scan      : Natural;
                     Exact_Condition : Boolean := False;
                     Branch_First : Natural := 0;
                     Value     : Unbounded_String;
                     Complete  : Boolean := False;
                  begin
                     if not Is_Valid_Key (Key) then
                        Problem := To_Unbounded_String ("invalid source key");
                        return;
                     end if;
                     while Before >= Raw'First
                       and then Is_Whitespace (Raw (Before))
                     loop
                        exit when Before = Raw'First;
                        Before := Before - 1;
                     end loop;
                     if Before >= Raw'First + 4
                       and then Ada.Characters.Handling.To_Lower
                         (Code (Before - 4 .. Before)) = "elsif"
                       and then
                         (Before = Raw'First + 4
                          or else not Is_Identifier_Character
                            (Raw (Before - 5)))
                     then
                        Exact_Condition := not First_Branch;
                        Branch_First := Before - 4;
                     elsif Before >= Raw'First + 1
                       and then Ada.Characters.Handling.To_Lower
                         (Code (Before - 1 .. Before)) = "if"
                       and then
                         (Before = Raw'First + 1
                          or else not Is_Identifier_Character
                            (Raw (Before - 2)))
                     then
                        Exact_Condition := First_Branch;
                        Branch_First := Before - 1;
                     end if;

                     while After <= Raw'Last
                       and then Is_Whitespace (Raw (After))
                     loop
                        After := After + 1;
                     end loop;
                     if not Exact_Condition
                       or else not Only_Whitespace
                         (Expected_Branch_Start, Branch_First - 1)
                       or else After + 3 > Raw'Last
                       or else Lower_Raw (After .. After + 3) /= "then"
                       or else
                         (After + 4 <= Raw'Last
                          and then Is_Identifier_Character
                            (Raw (After + 4)))
                     then
                        Problem := To_Unbounded_String (Key);
                        return;
                     end if;

                     Scan := After + 4;
                     while Scan <= Raw'Last
                       and then Is_Whitespace (Raw (Scan))
                     loop
                        Scan := Scan + 1;
                     end loop;
                     if Scan + 5 > Raw'Last
                       or else Lower_Raw (Scan .. Scan + 5) /= "return"
                       or else
                         (Scan + 6 <= Raw'Last
                          and then Is_Identifier_Character
                            (Raw (Scan + 6)))
                     then
                        Problem := To_Unbounded_String (Key);
                        return;
                     end if;
                     Scan := Scan + 6;

                     while Scan <= Raw'Last and then not Complete loop
                        if Raw (Scan) in ' ' | Character'Val (9)
                          | Character'Val (10) | Character'Val (13) | '&'
                        then
                           Scan := Scan + 1;
                        elsif Raw (Scan) = '"' then
                           Scan := Scan + 1;
                           loop
                              exit when Scan > Raw'Last;
                              if Raw (Scan) = '"' then
                                 if Scan < Raw'Last
                                   and then Raw (Scan + 1) = '"'
                                 then
                                    Append (Value, '"');
                                    Scan := Scan + 2;
                                 else
                                    Scan := Scan + 1;
                                    exit;
                                 end if;
                              else
                                 Append (Value, Raw (Scan));
                                 Scan := Scan + 1;
                              end if;
                           end loop;
                        elsif Raw (Scan) = ';' then
                           Complete := True;
                           Scan := Scan + 1;
                        else
                           exit;
                        end if;
                     end loop;

                     if not Complete then
                        if Length (Problem) = 0 then
                           Problem := To_Unbounded_String (Key);
                        end if;
                        return;
                     end if;
                     Add (Source_Defaults, Key, To_String (Value));
                     Cursor := Scan;
                     Expected_Branch_Start := Scan;
                     First_Branch := False;
                  end;
               end;
            end;
         end loop;
         Validate_Tail;
      end Parse_Source;
   begin
      for Index in Catalog'Range loop
         if Catalog (Index) = LF then
            Check_Catalog_Line
              (Catalog (Start .. Index - 1), Catalog_Line);
            Start := Index + 1;
            Catalog_Line := Catalog_Line + 1;
         end if;
      end loop;
      if Start <= Catalog'Last then
         Check_Catalog_Line
           (Catalog (Start .. Catalog'Last), Catalog_Line);
      end if;
      Parse_Source;

      if Length (Problem) > 0 then
         return (Valid => False, Detail => Problem);
      elsif not Saw_Default_Locale then
         return
           (Valid  => False,
            Detail => To_Unbounded_String ("default_locale"));
      elsif Catalog_Defaults.Is_Empty then
         return
           (Valid  => False,
            Detail => To_Unbounded_String ("catalog defaults"));
      end if;
      for Position in Catalog_Defaults.Iterate loop
         declare
            Key : constant String := Text_Maps.Key (Position);
         begin
            if not Source_Defaults.Contains (Key)
              or else Source_Defaults.Element (Key) /=
                Text_Maps.Element (Position)
            then
               return
                 (Valid  => False,
                  Detail => To_Unbounded_String (Key));
            end if;
         end;
      end loop;
      for Position in Source_Defaults.Iterate loop
         if not Catalog_Defaults.Contains (Text_Maps.Key (Position)) then
            return
              (Valid  => False,
               Detail => To_Unbounded_String (Text_Maps.Key (Position)));
         end if;
      end loop;

      for Locale of Catalog_Locales loop
         for Position in Catalog_Defaults.Iterate loop
            declare
               Key : constant String := Text_Maps.Key (Position);
            begin
               if not Catalog_Entries.Contains (Entry_Name (Locale, Key)) then
                  return
                    (Valid  => False,
                     Detail => To_Unbounded_String (Locale & "." & Key));
               end if;
            end;
         end loop;
      end loop;

      for Position in Catalog_Entries.Iterate loop
         declare
            Composite : constant String := Text_Maps.Key (Position);
            Separator : constant Natural :=
              Ada.Strings.Fixed.Index
                (Composite, String'(1 => Character'Val (0)));
            Locale_Key : constant String :=
              Composite (Separator + 1 .. Composite'Last);
         begin
            if not Catalog_Defaults.Contains (Locale_Key) then
               return
                 (Valid  => False,
                  Detail => To_Unbounded_String
                    (Composite (Composite'First .. Separator - 1)
                     & "." & Locale_Key));
            end if;
         end;
      end loop;
      return (Valid => True, Detail => Null_Unbounded_String);
   end Validate_Defaults;

   procedure Self_Test is separate;

   procedure Require_Matching_Defaults
     (Catalog_Path  : String;
      Defaults_Path : String)
   is
      Catalog : constant String :=
        Project_Tools.Files.Read_Raw_File
          (Project_Tools.Files.Join (Tooling_Support.Root, Catalog_Path));
      Raw     : constant String :=
        Project_Tools.Files.Read_Raw_File
          (Project_Tools.Files.Join (Tooling_Support.Root, Defaults_Path));
      Result : constant Validation_Result := Validate_Defaults (Catalog, Raw);
   begin
      if not Result.Valid then
         Tooling_Checks.Fail
           ("message " & To_String (Result.Detail)
            & " differs between " & Catalog_Path
            & " and " & Defaults_Path & ", is duplicated, or exists only once");
      end if;
   end Require_Matching_Defaults;
end Metadata_Checks.Catalog_Defaults;
