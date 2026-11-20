with Terminal_Styles;

package body Posix_Tools.Commands.Rg.Rendering is
   use Ada.Strings.Unbounded;

   Escape : constant String := Character'Val (16#1B#) & "[";
   Reset  : constant String := Escape & "0m";

   function Positive_Image (Value : Positive) return String;
   function Natural_Image (Value : Natural) return String;
   function Color_Output_Enabled (Style : Format) return Boolean;
   function Decorate_Field
     (Text  : String;
      Style : Format;
      Role  : Posix_Tools.Commands.Rg.Colors.Output_Role) return String;

   function Color_Output_Enabled (Style : Format) return Boolean is
   begin
      case Style.Color is
         when Color_Automatic =>
            return Terminal_Styles.Color_Enabled (Style.Destination_Is_Terminal);
         when Color_Always =>
            return True;
         when Color_Never =>
            return False;
      end case;
   end Color_Output_Enabled;

   function Decorate_Field
     (Text  : String;
      Style : Format;
      Role  : Posix_Tools.Commands.Rg.Colors.Output_Role) return String
   is
      Item : constant Posix_Tools.Commands.Rg.Colors.Text_Style :=
        Posix_Tools.Commands.Rg.Colors.Style (Style.Colors, Role);
   begin
      if Text'Length = 0
        or else not Posix_Tools.Commands.Rg.Colors.Enabled (Item)
        or else not Color_Output_Enabled (Style)
      then
         return Text;
      end if;
      return Posix_Tools.Commands.Rg.Colors.Prefix (Item) & Text & Reset;
   end Decorate_Field;

   function Highlight_Match (Text : String; Style : Format) return String is
   begin
      if Text'Length = 0 then
         return Text;
      end if;
      return Decorate_Field (Text, Style, Posix_Tools.Commands.Rg.Colors.Match_Role);
   end Highlight_Match;

   function Highlight_Text (Text : String; Style : Format) return String is
   begin
      return Decorate_Field (Text, Style, Posix_Tools.Commands.Rg.Colors.Highlight_Role);
   end Highlight_Text;

   function Positive_Image (Value : Positive) return String is
      Result : constant String := Positive'Image (Value);
   begin
      return Result (Result'First + 1 .. Result'Last);
   end Positive_Image;

   function Natural_Image (Value : Natural) return String is
      Result : constant String := Natural'Image (Value);
   begin
      return Result (Result'First + 1 .. Result'Last);
   end Natural_Image;

   procedure Put_Selected_Line
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Label       : String;
      Line        : Unbounded_String;
      Line_Number : Positive;
      Column      : Positive;
      Style       : Format;
      Count_Output : access procedure (Count : Natural) := null;
      Highlight    : Boolean := False;
      Logical_Length : Natural := Natural'Last)
   is
      Prefix : Unbounded_String;
   begin
      if Style.Prefix_Name then
         Append
           (Prefix,
            Decorate_Field (Label, Style, Posix_Tools.Commands.Rg.Colors.Path_Role));
         Append (Prefix, (if Style.Null_Pathnames then ASCII.NUL else ':'));
      end if;
      if Style.Show_Line_Number then
         Append
           (Prefix,
            Decorate_Field
              (Positive_Image (Line_Number), Style, Posix_Tools.Commands.Rg.Colors.Line_Role));
         Append (Prefix, ':');
      end if;
      if Style.Show_Column then
         Append
           (Prefix,
            Decorate_Field
              (Positive_Image (Column), Style, Posix_Tools.Commands.Rg.Colors.Column_Role));
         Append (Prefix, ':');
      end if;

      declare
         Text : constant String := To_String (Line);
         Output : constant String :=
           To_String (Prefix)
           & (if Highlight then Highlight_Match (Text, Style) else Text)
           & Style.Record_Terminator;
      begin
         Context.Put (Output);
         if Count_Output /= null then
            Count_Output
              ((if Style.Prefix_Name then Label'Length + 1 else 0)
               + (if Style.Show_Line_Number then Positive_Image (Line_Number)'Length + 1 else 0)
               + (if Style.Show_Column then Positive_Image (Column)'Length + 1 else 0)
               + (if Logical_Length = Natural'Last then Text'Length else Logical_Length)
               + 1);
         end if;
      end;
   end Put_Selected_Line;

   procedure Put_Context_Line
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Label       : String;
      Line        : Unbounded_String;
      Line_Number : Positive;
      Style       : Format;
      Count_Output : access procedure (Count : Natural) := null)
   is
      Prefix : Unbounded_String;
   begin
      if Style.Prefix_Name then
         Append
           (Prefix,
            Decorate_Field (Label, Style, Posix_Tools.Commands.Rg.Colors.Path_Role));
         Append (Prefix, (if Style.Null_Pathnames then ASCII.NUL else '-'));
      end if;
      if Style.Show_Line_Number then
         Append
           (Prefix,
            Decorate_Field
              (Positive_Image (Line_Number), Style, Posix_Tools.Commands.Rg.Colors.Line_Role));
         Append (Prefix, '-');
      end if;

      declare
         Output : constant String := To_String (Prefix) & To_String (Line) & Style.Record_Terminator;
      begin
         Context.Put (Output);
         if Count_Output /= null then
            Count_Output
              ((if Style.Prefix_Name then Label'Length + 1 else 0)
               + (if Style.Show_Line_Number then Positive_Image (Line_Number)'Length + 1 else 0)
               + To_String (Line)'Length
               + 1);
         end if;
      end;
   end Put_Context_Line;

   procedure Put_Context_Separator
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      Separator : String;
      Terminator : Character;
      Count_Output : access procedure (Count : Natural) := null;
      Style        : Format := (others => <>)) is
   begin
      Context.Put
        ((if Color_Output_Enabled (Style)
          then Escape & "0m" & Escape & "36m" & Separator & Reset
          else Separator)
         & Terminator);
      if Count_Output /= null then
         Count_Output (Separator'Length + 1);
      end if;
   end Put_Context_Separator;

   procedure Put_Count
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Label       : String;
      Count       : Natural;
      Style       : Format) is
   begin
      Context.Put
        ((if Style.Prefix_Name
          then Decorate_Field (Label, Style, Posix_Tools.Commands.Rg.Colors.Path_Role)
            & (if Style.Null_Pathnames then String'(1 => ASCII.NUL) else ":")
          else "")
         & Natural_Image (Count) & Style.Record_Terminator);
   end Put_Count;

   procedure Put_Heading
     (Context      : in out Posix_Tools.Commands.Contexts.Context'Class;
      Label        : String;
      Style        : Format;
      Count_Output : access procedure (Count : Natural) := null)
   is
      Output : constant String :=
        Decorate_Field (Label, Style, Posix_Tools.Commands.Rg.Colors.Path_Role)
        & (if Style.Null_Pathnames
           then String'(1 => ASCII.NUL)
           else String'(1 => Style.Record_Terminator));
   begin
      Context.Put (Output);
      if Count_Output /= null then
         Count_Output (Label'Length + 1);
      end if;
   end Put_Heading;

   procedure Put_Path
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Label   : String;
      Terminator : Character := ASCII.LF;
      Style      : Format := (others => <>)) is
   begin
      Context.Put
        (Decorate_Field (Label, Style, Posix_Tools.Commands.Rg.Colors.Path_Role)
         & Terminator);
   end Put_Path;
end Posix_Tools.Commands.Rg.Rendering;
