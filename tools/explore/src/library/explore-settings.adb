with Ada.Characters.Handling;
with Explore.Files;
with Explore.Screen;
with Explore.String_Vectors;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Numeric_Images;
with Tomllib.Documents;
with Tomllib.Errors;
with Tomllib.Parsers;

package body Explore.Settings is
   package Documents renames Tomllib.Documents;
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Documents.Value_Kind;

   LF : constant Character := Character'Val (10);

   --  The largest configuration or bookmarks file read.
   Max_File_Bytes : constant := 1024 * 1024;

   function Image (Value : Natural) return String renames Posix_Tools.Text.Numeric_Images.Natural_Image;

   --  The colour Text names: "default", one of the eight colours, one of
   --  them after "bright_", or a palette index.
   procedure Color_Value (Text : String; Value : out Explore.Screen.Color; Ok : out Boolean);

   --  Make Path a directory, with any of its parents that are missing.
   procedure Make_Directories (Path : String);

   function Bookmarks_Image (Marks : Bookmark_Maps.Map) return String is
      Result : Unbounded.Unbounded_String;
   begin
      for Position in Marks.Iterate loop
         Unbounded.Append
           (Result, Bookmark_Maps.Key (Position) & " " & Unbounded.To_String (Bookmark_Maps.Element (Position)) & LF);
      end loop;

      return Unbounded.To_String (Result);
   end Bookmarks_Image;

   function Bookmarks_Path (State_Home, Home : String) return String is
     (if State_Home'Length > 0 and then State_Home (State_Home'First) = '/' then State_Home & "/explore/bookmarks"
      elsif Home'Length > 0 then Home & "/.local/state/explore/bookmarks"
      else "");

   function Bookmarks_Value (Text : String) return Bookmark_Maps.Map is
      Result : Bookmark_Maps.Map;
      First  : Positive := Text'First;
   begin
      for I in Text'Range loop
         if Text (I) = LF or else I = Text'Last then
            declare
               Line : constant String := Text (First .. (if Text (I) = LF then I - 1 else I));
            begin
               if Line'Length >= 3 and then Line (Line'First) in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9'
                 and then Line (Line'First + 1) = ' ' and then Line (Line'First + 2) = '/'
               then
                  Result.Include
                    (Line (Line'First), Unbounded.To_Unbounded_String (Line (Line'First + 2 .. Line'Last)));
               end if;
            end;

            First := I + 1;
         end if;
      end loop;

      return Result;
   end Bookmarks_Value;

   procedure Color_Value (Text : String; Value : out Explore.Screen.Color; Ok : out Boolean) is
      type Color_Name is (Black, Red, Green, Yellow, Blue, Magenta, Cyan, White);

      Bright : constant String := "bright_";
   begin
      Value := Explore.Screen.Default_Color;
      Ok := True;

      if Text = "default" then
         return;
      end if;

      for Name in Color_Name loop
         declare
            Lower : constant String := Ada.Characters.Handling.To_Lower (Color_Name'Image (Name));
         begin
            if Text = Lower then
               Value := Explore.Screen.Color (Color_Name'Pos (Name));
               return;
            elsif Text = Bright & Lower then
               Value := Explore.Screen.Color (Color_Name'Pos (Name) + 8);
               return;
            end if;
         end;
      end loop;

      Ok := False;
   end Color_Value;

   function Configuration_Path (Config_Home, Home : String) return String is
     (if Config_Home'Length > 0 and then Config_Home (Config_Home'First) = '/'
      then Config_Home & "/explore/config.toml"
      elsif Home'Length > 0 then Home & "/.config/explore/config.toml"
      else "");

   procedure Load (Path : String; Into : out Settings; Problems : out Problem_Vectors.Vector) is
      Text : Unbounded.Unbounded_String;
      Ok   : Boolean;
   begin
      Into := (others => <>);
      Problems.Clear;

      if Path'Length = 0 or else not FS.Exists (Path) then
         return;
      end if;

      Explore.Files.Read_Head (Path, Max_File_Bytes, Text, Ok);

      if Ok then
         Parse (Unbounded.To_String (Text), Into, Problems);
      else
         Problems.Append (Problem'(Kind => Unreadable_File, Where => Unbounded.To_Unbounded_String (Path)));
      end if;
   end Load;

   procedure Make_Directories (Path : String) is
   begin
      if Path'Length = 0 or else FS.Exists (Path) then
         return;
      end if;

      for I in reverse Path'First + 1 .. Path'Last loop
         if Path (I) = '/' then
            Make_Directories (Path (Path'First .. I - 1));
            exit;
         end if;
      end loop;

      FS.Create_Directory (Path);
   end Make_Directories;

   procedure Parse (Text : String; Into : out Settings; Problems : out Problem_Vectors.Vector) is
      Document : Documents.Document;
      Error    : Tomllib.Errors.Error_Info;

      procedure Report (Kind : Problem_Kind; Where : String);

      --  The value of Name in Table as a boolean, into Value; reported when
      --  it is something else.
      procedure Take_Boolean (Item : Documents.Node; Where : String; Value : in out Boolean);

      --  One string or an array of strings, as the patterns of an opener or
      --  a previewer.
      procedure Take_Patterns (Item : Documents.Node; Where : String; Patterns : out Explore.String_Vectors.Vector);

      procedure Read_Keys (Table : Documents.Node);
      procedure Read_Openers (List : Documents.Node);
      procedure Read_Options (Table : Documents.Node);
      procedure Read_Previewers (List : Documents.Node);
      procedure Read_Theme (Table : Documents.Node);

      procedure Read_Keys (Table : Documents.Node) is
      begin
         if Documents.Kind (Document, Table) /= Documents.Table_Value then
            Report (Bad_Value, "keys");
            return;
         end if;

         for I in 1 .. Documents.Length (Document, Table) loop
            declare
               Name  : constant String := Documents.Name (Document, Table, I);
               Value : constant Documents.Node := Documents.Element (Document, Table, I);
               Ok    : Boolean := False;
            begin
               if Documents.Kind (Document, Value) = Documents.String_Value then
                  Explore.Keymap.Bind (Into.Keys, Name, Documents.As_String (Document, Value), Ok);
               end if;

               if not Ok then
                  Report (Bad_Value, "keys." & Name);
               end if;
            end;
         end loop;
      end Read_Keys;

      procedure Read_Openers (List : Documents.Node) is
      begin
         if Documents.Kind (Document, List) /= Documents.Array_Value then
            Report (Bad_Value, "open");
            return;
         end if;

         for I in 1 .. Documents.Length (Document, List) loop
            declare
               Where : constant String := "open[" & Image (I) & "]";
               Table : constant Documents.Node := Documents.Element (Document, List, I);
               Item  : Explore.Launch.Opener;
               Ran   : Boolean := False;
            begin
               if Documents.Kind (Document, Table) /= Documents.Table_Value then
                  Report (Bad_Value, Where);
               else
                  for J in 1 .. Documents.Length (Document, Table) loop
                     declare
                        Name  : constant String := Documents.Name (Document, Table, J);
                        Value : constant Documents.Node := Documents.Element (Document, Table, J);
                     begin
                        if Name = "match" then
                           Take_Patterns (Value, Where & ".match", Item.Patterns);
                        elsif Name = "run" and then Documents.Kind (Document, Value) = Documents.String_Value then
                           Item.Run := Unbounded.To_Unbounded_String (Documents.As_String (Document, Value));
                           Ran := True;
                        elsif Name = "detach" then
                           Take_Boolean (Value, Where & ".detach", Item.Detach);
                        elsif Name = "run" then
                           Report (Bad_Value, Where & ".run");
                        else
                           Report (Unknown_Setting, Where & "." & Name);
                        end if;
                     end;
                  end loop;

                  if Ran then
                     Into.Openers.Append (Item);
                  else
                     Report (Bad_Value, Where & ".run");
                  end if;
               end if;
            end;
         end loop;
      end Read_Openers;

      procedure Read_Options (Table : Documents.Node) is
      begin
         if Documents.Kind (Document, Table) /= Documents.Table_Value then
            Report (Bad_Value, "options");
            return;
         end if;

         for I in 1 .. Documents.Length (Document, Table) loop
            declare
               Name  : constant String := Documents.Name (Document, Table, I);
               Value : constant Documents.Node := Documents.Element (Document, Table, I);
            begin
               if Name = "show_hidden" then
                  Take_Boolean (Value, "options." & Name, Into.Show_Hidden);
               elsif Name = "sort_descending" then
                  Take_Boolean (Value, "options." & Name, Into.Descending);
               elsif Name = "thumbnails" then
                  Take_Boolean (Value, "options." & Name, Into.Thumbnails);
               elsif Name = "sort" then
                  declare
                     Sorting : Explore.Keymap.Command;
                     Ok      : Boolean := False;
                  begin
                     --  The sort keys are those the sort_entries action takes.
                     if Documents.Kind (Document, Value) = Documents.String_Value
                       and then Documents.As_String (Document, Value)'Length > 0
                     then
                        Explore.Keymap.Parse_Command
                          ("sort_entries:" & Documents.As_String (Document, Value), Sorting, Ok);
                        Ok := Ok and then not Sorting.Descending;
                     end if;

                     if Ok then
                        Into.Sort_Key := Sorting.Key;
                     else
                        Report (Bad_Value, "options.sort");
                     end if;
                  end;
               else
                  Report (Unknown_Setting, "options." & Name);
               end if;
            end;
         end loop;
      end Read_Options;

      procedure Read_Previewers (List : Documents.Node) is
      begin
         if Documents.Kind (Document, List) /= Documents.Array_Value then
            Report (Bad_Value, "preview");
            return;
         end if;

         for I in 1 .. Documents.Length (Document, List) loop
            declare
               Where : constant String := "preview[" & Image (I) & "]";
               Table : constant Documents.Node := Documents.Element (Document, List, I);
               Item  : Explore.Previews.Preview_Rule;
               Ran   : Boolean := False;
            begin
               if Documents.Kind (Document, Table) /= Documents.Table_Value then
                  Report (Bad_Value, Where);
               else
                  for J in 1 .. Documents.Length (Document, Table) loop
                     declare
                        Name  : constant String := Documents.Name (Document, Table, J);
                        Value : constant Documents.Node := Documents.Element (Document, Table, J);
                     begin
                        if Name = "match" then
                           Take_Patterns (Value, Where & ".match", Item.Patterns);
                        elsif Name = "run" and then Documents.Kind (Document, Value) = Documents.String_Value then
                           Item.Run := Unbounded.To_Unbounded_String (Documents.As_String (Document, Value));
                           Ran := True;
                        elsif Name = "run" then
                           Report (Bad_Value, Where & ".run");
                        else
                           Report (Unknown_Setting, Where & "." & Name);
                        end if;
                     end;
                  end loop;

                  --  A previewer without patterns would preview every file.
                  if not Ran then
                     Report (Bad_Value, Where & ".run");
                  elsif Item.Patterns.Is_Empty then
                     Report (Bad_Value, Where & ".match");
                  else
                     Into.Previewers.Append (Item);
                  end if;
               end if;
            end;
         end loop;
      end Read_Previewers;

      procedure Read_Theme (Table : Documents.Node) is
      begin
         if Documents.Kind (Document, Table) /= Documents.Table_Value then
            Report (Bad_Value, "theme");
            return;
         end if;

         for I in 1 .. Documents.Length (Document, Table) loop
            declare
               Name  : constant String := Documents.Name (Document, Table, I);
               Value : constant Documents.Node := Documents.Element (Document, Table, I);
               Where : constant String := "theme." & Name;
               Found : Boolean := False;
               Role  : Explore.Themes.Theme_Role := Explore.Themes.Theme_Role'First;
               Style : Explore.Screen.Style := Explore.Screen.Plain;
            begin
               for Candidate in Explore.Themes.Theme_Role loop
                  if Explore.Themes.Role_Name (Candidate) = Name then
                     Role := Candidate;
                     Found := True;
                  end if;
               end loop;

               if not Found then
                  Report (Unknown_Setting, Where);
               elsif Documents.Kind (Document, Value) /= Documents.Table_Value then
                  Report (Bad_Value, Where);
               else
                  for J in 1 .. Documents.Length (Document, Value) loop
                     declare
                        Field : constant String := Documents.Name (Document, Value, J);
                        Item  : constant Documents.Node := Documents.Element (Document, Value, J);
                        Ok    : Boolean := True;
                        Shade : Explore.Screen.Color := Explore.Screen.Default_Color;
                     begin
                        if Field in "fg" | "bg" then
                           case Documents.Kind (Document, Item) is
                              when Documents.String_Value =>
                                 Color_Value (Documents.As_String (Document, Item), Shade, Ok);
                              when Documents.Integer_Value =>
                                 Ok := Documents.As_Integer (Document, Item) in 0 .. 255;

                                 if Ok then
                                    Shade := Explore.Screen.Color (Documents.As_Integer (Document, Item));
                                 end if;
                              when others =>
                                 Ok := False;
                           end case;

                           if not Ok then
                              Report (Bad_Value, Where & "." & Field);
                           elsif Field = "fg" then
                              Style.Foreground := Shade;
                           else
                              Style.Background := Shade;
                           end if;
                        elsif Field = "bold" then
                           Take_Boolean (Item, Where & "." & Field, Style.Bold);
                        elsif Field = "dim" then
                           Take_Boolean (Item, Where & "." & Field, Style.Dim);
                        elsif Field = "underline" then
                           Take_Boolean (Item, Where & "." & Field, Style.Underline);
                        elsif Field = "inverse" then
                           Take_Boolean (Item, Where & "." & Field, Style.Inverse);
                        else
                           Report (Unknown_Setting, Where & "." & Field);
                        end if;
                     end;
                  end loop;

                  Into.Colors (Role) := Style;
               end if;
            end;
         end loop;
      end Read_Theme;

      procedure Report (Kind : Problem_Kind; Where : String) is
      begin
         Problems.Append (Problem'(Kind => Kind, Where => Unbounded.To_Unbounded_String (Where)));
      end Report;

      procedure Take_Boolean (Item : Documents.Node; Where : String; Value : in out Boolean) is
      begin
         if Documents.Kind (Document, Item) = Documents.Boolean_Value then
            Value := Documents.As_Boolean (Document, Item);
         else
            Report (Bad_Value, Where);
         end if;
      end Take_Boolean;

      procedure Take_Patterns (Item : Documents.Node; Where : String; Patterns : out Explore.String_Vectors.Vector)
      is
      begin
         Patterns.Clear;

         if Documents.Kind (Document, Item) = Documents.String_Value then
            Patterns.Append (Documents.As_String (Document, Item));
         elsif Documents.Kind (Document, Item) = Documents.Array_Value then
            for I in 1 .. Documents.Length (Document, Item) loop
               declare
                  Element : constant Documents.Node := Documents.Element (Document, Item, I);
               begin
                  if Documents.Kind (Document, Element) = Documents.String_Value then
                     Patterns.Append (Documents.As_String (Document, Element));
                  else
                     Report (Bad_Value, Where);
                  end if;
               end;
            end loop;
         else
            Report (Bad_Value, Where);
         end if;
      end Take_Patterns;
   begin
      Into := (others => <>);
      Problems.Clear;
      Tomllib.Parsers.Parse (Text, Document, Error);

      if Tomllib.Errors.Failed (Error) then
         Report (Syntax_Error, "line " & Image (Error.At_Position.Line));
         return;
      end if;

      declare
         Root : constant Documents.Node := Documents.Root (Document);
      begin
         for I in 1 .. Documents.Length (Document, Root) loop
            declare
               Name  : constant String := Documents.Name (Document, Root, I);
               Value : constant Documents.Node := Documents.Element (Document, Root, I);
            begin
               if Name = "options" then
                  Read_Options (Value);
               elsif Name = "keys" then
                  Read_Keys (Value);
               elsif Name = "theme" then
                  Read_Theme (Value);
               elsif Name = "open" then
                  Read_Openers (Value);
               elsif Name = "preview" then
                  Read_Previewers (Value);
               else
                  Report (Unknown_Setting, Name);
               end if;
            end;
         end loop;
      end;
   end Parse;

   function Read_Bookmarks (Path : String) return Bookmark_Maps.Map is
      Text : Unbounded.Unbounded_String;
      Ok   : Boolean;
   begin
      if Path'Length = 0 or else not FS.Exists (Path) then
         return Bookmark_Maps.Empty_Map;
      end if;

      Explore.Files.Read_Head (Path, Max_File_Bytes, Text, Ok);
      return (if Ok then Bookmarks_Value (Unbounded.To_String (Text)) else Bookmark_Maps.Empty_Map);
   end Read_Bookmarks;

   procedure Write_Bookmarks (Path : String; Marks : Bookmark_Maps.Map; Ok : out Boolean) is
   begin
      Ok := False;

      if Path'Length = 0 then
         return;
      end if;

      for I in reverse Path'Range loop
         if Path (I) = '/' then
            Make_Directories (Path (Path'First .. I - 1));
            exit;
         end if;
      end loop;

      FS.Write_File (Path, Bookmarks_Image (Marks), Append_Mode => False, Ok => Ok);
   exception
      when others =>
         Ok := False;
   end Write_Bookmarks;
end Explore.Settings;
