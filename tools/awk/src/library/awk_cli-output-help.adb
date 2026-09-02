with Ada.Strings.Unbounded;

separate (Awk_CLI.Output)
function Help
  (Catalog : L.Catalog;
   Destination_Is_Terminal : Boolean;
   No_Color_Active        : Boolean := False) return String
is
   package U renames Ada.Strings.Unbounded;

   type Help_Line is record
      Key         : U.Unbounded_String;
      Is_Header   : Boolean := False;
      Blank_After : Natural := 0;
   end record;

   function Line
     (Key         : String;
      Is_Header   : Boolean := False;
      Blank_After : Natural := 0) return Help_Line is
     (Key         => U.To_Unbounded_String (Key),
      Is_Header   => Is_Header,
      Blank_After => Blank_After);

   Help_Lines : constant array (Positive range <>) of Help_Line :=
     [Line ("awk.help.title", Is_Header => True),
      Line ("awk.help.summary", Blank_After => 1),
      Line ("awk.help.usage.direct_program"),
      Line ("awk.help.usage.program_files", Blank_After => 1),
      Line ("awk.help.options.field_separator"),
      Line ("awk.help.options.variable"),
      Line ("awk.help.options.program_file"),
      Line ("awk.help.options.color"),
      Line ("awk.help.options.help"),
      Line ("awk.help.options.version"),
      Line ("awk.help.options.terminator", Blank_After => 1),
      Line ("awk.help.operands"),
      Line ("awk.help.stdin"),
      Line ("awk.help.exit_statuses", Blank_After => 1),
      Line ("awk.help.compatibility.heading", Is_Header => True),
      Line ("awk.help.compatibility.awklib_limitations")];

   procedure Append_Help_Line
     (Result : in out U.Unbounded_String;
      Item   : Help_Line)
   is
      LF   : constant String := [1 => ASCII.LF];
      Text : constant String := L.Text (Catalog, U.To_String (Item.Key));
   begin
      if Item.Is_Header then
         U.Append
           (Result,
            Styled
              (Text, TS.Role_Header, Destination_Is_Terminal, No_Color_Active));
      else
         U.Append (Result, Text);
      end if;

      U.Append (Result, LF);
      for Blank in 1 .. Item.Blank_After loop
         U.Append (Result, LF);
      end loop;
   end Append_Help_Line;

   Result : U.Unbounded_String;
begin
   for Item of Help_Lines loop
      Append_Help_Line (Result, Item);
   end loop;

   return U.To_String (Result);
end Help;
