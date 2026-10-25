with Ada.Characters.Handling;
with Explore.Screen;
with Explore.String_Vectors;
with Posix_Tools.Text.Numeric_Images;
with Tomllib.Documents;
with Tomllib.Errors;
with Tomllib.Parsers;

package body Explore.Settings is
   package Documents renames Tomllib.Documents;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Documents.Value_Kind;

   LF : constant Character := Character'Val (10);

   function Image (Value : Natural) return String renames Posix_Tools.Text.Numeric_Images.Natural_Image;

   --  A document being read, and what was found wrong with it so far. Every
   --  reader below takes one, so that each can report and carry on.
   type Reading is limited record
      Document : Documents.Document;
      Problems : Problem_Vectors.Vector;
   end record;

   --  The fields an [[open]] or a [[preview]] table may have.
   type Command_Fields is record
      Patterns : Explore.String_Vectors.Vector;
      Run      : Unbounded.Unbounded_String;
      --  Whether a run that is a string was found.
      Has_Run  : Boolean := False;
      Detach   : Boolean := False;
   end record;

   --  The colour Text names: "default", one of the eight colours, one of
   --  them after "bright_", or a palette index.
   procedure Color_Value (Text : String; Value : out Explore.Screen.Color; Ok : out Boolean);

   --  Whether Item is of Kind; reported as a bad value at Where when not.
   function Is_Kind
     (From  : in out Reading;
      Item  : Documents.Node;
      Kind  : Documents.Value_Kind;
      Where : String) return Boolean;

   --  The fields of the table Table, the opener or previewer at Where, into
   --  Fields. Detach is a field only when With_Detach. A field explore does
   --  not know is reported and skipped.
   procedure Read_Command_Fields
     (From        : in out Reading;
      Table       : Documents.Node;
      Where       : String;
      With_Detach : Boolean;
      Fields      : out Command_Fields);

   --  The readers of the parts of the configuration, each from the node of
   --  its own table or array of tables.
   procedure Read_Keys (From : in out Reading; Table : Documents.Node; Into : in out Settings);
   procedure Read_Openers (From : in out Reading; List : Documents.Node; Into : in out Settings);
   procedure Read_Options (From : in out Reading; Table : Documents.Node; Into : in out Settings);
   procedure Read_Previewers (From : in out Reading; List : Documents.Node; Into : in out Settings);
   procedure Read_Theme (From : in out Reading; Table : Documents.Node; Into : in out Settings);

   --  The style of one theme role, at Where, from the table Table: fields
   --  left out are those of a plain style.
   procedure Read_Style
     (From  : in out Reading;
      Table : Documents.Node;
      Where : String;
      Style : out Explore.Screen.Style);

   procedure Report (From : in out Reading; Kind : Problem_Kind; Where : String);

   --  The role the theme names Name, if there is one.
   procedure Role_Named (Name : String; Role : out Explore.Themes.Theme_Role; Found : out Boolean);

   --  Item as a boolean, into Value; reported at Where, and Value left as it
   --  was, when it is something else.
   procedure Take_Boolean (From : in out Reading; Item : Documents.Node; Where : String; Value : in out Boolean);

   --  Item as a colour, by name or palette index, into Value; reported at
   --  Where, and Value left as it was, when it is neither.
   procedure Take_Color
     (From  : in out Reading;
      Item  : Documents.Node;
      Where : String;
      Value : in out Explore.Screen.Color);

   --  One string or an array of strings, as the patterns of an opener or
   --  a previewer.
   procedure Take_Patterns
     (From     : in out Reading;
      Item     : Documents.Node;
      Where    : String;
      Patterns : out Explore.String_Vectors.Vector);

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

   function Is_Kind
     (From  : in out Reading;
      Item  : Documents.Node;
      Kind  : Documents.Value_Kind;
      Where : String) return Boolean
   is
   begin
      if Documents.Kind (From.Document, Item) = Kind then
         return True;
      end if;

      Report (From, Bad_Value, Where);
      return False;
   end Is_Kind;

   procedure Parse (Text : String; Into : out Settings; Problems : out Problem_Vectors.Vector) is
      From  : Reading;
      Error : Tomllib.Errors.Error_Info;
   begin
      Into := (others => <>);
      Tomllib.Parsers.Parse (Text, From.Document, Error);

      if Tomllib.Errors.Failed (Error) then
         Problems.Clear;
         Problems.Append (Problem'(Kind => Syntax_Error, Where => <>, Line => Error.At_Position.Line));
         return;
      end if;

      declare
         Root : constant Documents.Node := Documents.Root (From.Document);
      begin
         for I in 1 .. Documents.Length (From.Document, Root) loop
            declare
               Name  : constant String := Documents.Name (From.Document, Root, I);
               Value : constant Documents.Node := Documents.Element (From.Document, Root, I);
            begin
               if Name = "options" then
                  Read_Options (From, Value, Into);
               elsif Name = "keys" then
                  Read_Keys (From, Value, Into);
               elsif Name = "theme" then
                  Read_Theme (From, Value, Into);
               elsif Name = "open" then
                  Read_Openers (From, Value, Into);
               elsif Name = "preview" then
                  Read_Previewers (From, Value, Into);
               else
                  Report (From, Unknown_Setting, Name);
               end if;
            end;
         end loop;
      end;

      Problems := From.Problems;
   end Parse;

   procedure Read_Command_Fields
     (From        : in out Reading;
      Table       : Documents.Node;
      Where       : String;
      With_Detach : Boolean;
      Fields      : out Command_Fields)
   is
   begin
      Fields := (others => <>);

      for I in 1 .. Documents.Length (From.Document, Table) loop
         declare
            Name  : constant String := Documents.Name (From.Document, Table, I);
            Value : constant Documents.Node := Documents.Element (From.Document, Table, I);
         begin
            if Name = "match" then
               Take_Patterns (From, Value, Where & ".match", Fields.Patterns);
            elsif Name = "run" then
               if Is_Kind (From, Value, Documents.String_Value, Where & ".run") then
                  Fields.Run := Unbounded.To_Unbounded_String (Documents.As_String (From.Document, Value));
                  Fields.Has_Run := True;
               end if;
            elsif Name = "detach" and then With_Detach then
               Take_Boolean (From, Value, Where & ".detach", Fields.Detach);
            else
               Report (From, Unknown_Setting, Where & "." & Name);
            end if;
         end;
      end loop;
   end Read_Command_Fields;

   procedure Read_Keys (From : in out Reading; Table : Documents.Node; Into : in out Settings) is
   begin
      if not Is_Kind (From, Table, Documents.Table_Value, "keys") then
         return;
      end if;

      for I in 1 .. Documents.Length (From.Document, Table) loop
         declare
            Name  : constant String := Documents.Name (From.Document, Table, I);
            Value : constant Documents.Node := Documents.Element (From.Document, Table, I);
            Ok    : Boolean := False;
         begin
            if Documents.Kind (From.Document, Value) = Documents.String_Value then
               Explore.Keymap.Bind (Into.Keys, Name, Documents.As_String (From.Document, Value), Ok);
            end if;

            if not Ok then
               Report (From, Bad_Value, "keys." & Name);
            end if;
         end;
      end loop;
   end Read_Keys;

   procedure Read_Openers (From : in out Reading; List : Documents.Node; Into : in out Settings) is
   begin
      if not Is_Kind (From, List, Documents.Array_Value, "open") then
         return;
      end if;

      for I in 1 .. Documents.Length (From.Document, List) loop
         declare
            Where  : constant String := "open[" & Image (I) & "]";
            Table  : constant Documents.Node := Documents.Element (From.Document, List, I);
            Fields : Command_Fields;
         begin
            if Is_Kind (From, Table, Documents.Table_Value, Where) then
               Read_Command_Fields (From, Table, Where, With_Detach => True, Fields => Fields);

               if Fields.Has_Run then
                  Into.Openers.Append
                    (Explore.Launch.Opener'(Patterns => Fields.Patterns, Run => Fields.Run, Detach => Fields.Detach));
               else
                  Report (From, Bad_Value, Where & ".run");
               end if;
            end if;
         end;
      end loop;
   end Read_Openers;

   procedure Read_Options (From : in out Reading; Table : Documents.Node; Into : in out Settings) is
   begin
      if not Is_Kind (From, Table, Documents.Table_Value, "options") then
         return;
      end if;

      for I in 1 .. Documents.Length (From.Document, Table) loop
         declare
            Name  : constant String := Documents.Name (From.Document, Table, I);
            Value : constant Documents.Node := Documents.Element (From.Document, Table, I);
            Where : constant String := "options." & Name;
            Key   : Posix_Tools.File_Operations.Listing.Sort_Key;
            Ok    : Boolean := False;
         begin
            if Name = "show_hidden" then
               Take_Boolean (From, Value, Where, Into.Show_Hidden);
            elsif Name = "sort_descending" then
               Take_Boolean (From, Value, Where, Into.Descending);
            elsif Name = "thumbnails" then
               Take_Boolean (From, Value, Where, Into.Thumbnails);
            elsif Name = "sort" then
               --  The order is sort_descending, so only the key is taken here.
               if Documents.Kind (From.Document, Value) = Documents.String_Value then
                  Explore.Keymap.Parse_Sort_Key (Documents.As_String (From.Document, Value), Key, Ok);
               end if;

               if Ok then
                  Into.Sort_Key := Key;
               else
                  Report (From, Bad_Value, Where);
               end if;
            else
               Report (From, Unknown_Setting, Where);
            end if;
         end;
      end loop;
   end Read_Options;

   procedure Read_Previewers (From : in out Reading; List : Documents.Node; Into : in out Settings) is
   begin
      if not Is_Kind (From, List, Documents.Array_Value, "preview") then
         return;
      end if;

      for I in 1 .. Documents.Length (From.Document, List) loop
         declare
            Where  : constant String := "preview[" & Image (I) & "]";
            Table  : constant Documents.Node := Documents.Element (From.Document, List, I);
            Fields : Command_Fields;
         begin
            if Is_Kind (From, Table, Documents.Table_Value, Where) then
               Read_Command_Fields (From, Table, Where, With_Detach => False, Fields => Fields);

               --  A previewer without patterns would preview every file.
               if not Fields.Has_Run then
                  Report (From, Bad_Value, Where & ".run");
               elsif Fields.Patterns.Is_Empty then
                  Report (From, Bad_Value, Where & ".match");
               else
                  Into.Previewers.Append
                    (Explore.Previews.Preview_Rule'(Patterns => Fields.Patterns, Run => Fields.Run));
               end if;
            end if;
         end;
      end loop;
   end Read_Previewers;

   procedure Read_Style
     (From  : in out Reading;
      Table : Documents.Node;
      Where : String;
      Style : out Explore.Screen.Style)
   is
   begin
      Style := Explore.Screen.Plain;

      for I in 1 .. Documents.Length (From.Document, Table) loop
         declare
            Field : constant String := Documents.Name (From.Document, Table, I);
            Item  : constant Documents.Node := Documents.Element (From.Document, Table, I);
            At_It : constant String := Where & "." & Field;
         begin
            if Field = "fg" then
               Take_Color (From, Item, At_It, Style.Foreground);
            elsif Field = "bg" then
               Take_Color (From, Item, At_It, Style.Background);
            elsif Field = "bold" then
               Take_Boolean (From, Item, At_It, Style.Bold);
            elsif Field = "dim" then
               Take_Boolean (From, Item, At_It, Style.Dim);
            elsif Field = "underline" then
               Take_Boolean (From, Item, At_It, Style.Underline);
            elsif Field = "inverse" then
               Take_Boolean (From, Item, At_It, Style.Inverse);
            else
               Report (From, Unknown_Setting, At_It);
            end if;
         end;
      end loop;
   end Read_Style;

   procedure Read_Theme (From : in out Reading; Table : Documents.Node; Into : in out Settings) is
   begin
      if not Is_Kind (From, Table, Documents.Table_Value, "theme") then
         return;
      end if;

      for I in 1 .. Documents.Length (From.Document, Table) loop
         declare
            Name  : constant String := Documents.Name (From.Document, Table, I);
            Value : constant Documents.Node := Documents.Element (From.Document, Table, I);
            Where : constant String := "theme." & Name;
            Role  : Explore.Themes.Theme_Role;
            Found : Boolean;
         begin
            Role_Named (Name, Role, Found);

            if not Found then
               Report (From, Unknown_Setting, Where);
            elsif Is_Kind (From, Value, Documents.Table_Value, Where) then
               Read_Style (From, Value, Where, Into.Colors (Role));
            end if;
         end;
      end loop;
   end Read_Theme;

   procedure Report (From : in out Reading; Kind : Problem_Kind; Where : String) is
   begin
      From.Problems.Append (Problem'(Kind => Kind, Where => Unbounded.To_Unbounded_String (Where), Line => 0));
   end Report;

   procedure Role_Named (Name : String; Role : out Explore.Themes.Theme_Role; Found : out Boolean) is
   begin
      Role := Explore.Themes.Theme_Role'First;
      Found := False;

      for Candidate in Explore.Themes.Theme_Role loop
         if Explore.Themes.Role_Name (Candidate) = Name then
            Role := Candidate;
            Found := True;
            return;
         end if;
      end loop;
   end Role_Named;

   procedure Take_Boolean (From : in out Reading; Item : Documents.Node; Where : String; Value : in out Boolean) is
   begin
      if Is_Kind (From, Item, Documents.Boolean_Value, Where) then
         Value := Documents.As_Boolean (From.Document, Item);
      end if;
   end Take_Boolean;

   procedure Take_Color
     (From  : in out Reading;
      Item  : Documents.Node;
      Where : String;
      Value : in out Explore.Screen.Color)
   is
      Shade : Explore.Screen.Color := Explore.Screen.Default_Color;
      Ok    : Boolean := False;
   begin
      case Documents.Kind (From.Document, Item) is
         when Documents.String_Value =>
            Color_Value (Documents.As_String (From.Document, Item), Shade, Ok);
         when Documents.Integer_Value =>
            Ok := Documents.As_Integer (From.Document, Item) in 0 .. 255;

            if Ok then
               Shade := Explore.Screen.Color (Documents.As_Integer (From.Document, Item));
            end if;
         when others =>
            null;
      end case;

      if Ok then
         Value := Shade;
      else
         Report (From, Bad_Value, Where);
      end if;
   end Take_Color;

   procedure Take_Patterns
     (From     : in out Reading;
      Item     : Documents.Node;
      Where    : String;
      Patterns : out Explore.String_Vectors.Vector)
   is
   begin
      Patterns.Clear;

      if Documents.Kind (From.Document, Item) = Documents.String_Value then
         Patterns.Append (Documents.As_String (From.Document, Item));
      elsif Is_Kind (From, Item, Documents.Array_Value, Where) then
         for I in 1 .. Documents.Length (From.Document, Item) loop
            declare
               Element : constant Documents.Node := Documents.Element (From.Document, Item, I);
            begin
               if Is_Kind (From, Element, Documents.String_Value, Where) then
                  Patterns.Append (Documents.As_String (From.Document, Element));
               end if;
            end;
         end loop;
      end if;
   end Take_Patterns;
end Explore.Settings;
