with Ada.Strings.Unbounded;

separate (Awk_CLI.Output)
function Diagnostic_Text
  (Catalog : L.Catalog;
   Item    : Awk_CLI.Diagnostics.Diagnostic;
   Destination_Is_Terminal : Boolean;
   No_Color_Active        : Boolean := False) return String
is
   package U renames Ada.Strings.Unbounded;

   LF : constant String := [1 => ASCII.LF];

   function Image (Value : Natural) return String is
      Raw : constant String := Natural'Image (Value);
   begin
      if Raw'Length > 0 and then Raw (Raw'First) = ' ' then
         return Raw (Raw'First + 1 .. Raw'Last);
      else
         return Raw;
      end if;
   end Image;

   function Source_Display_Name (Source_Name : String) return String is
   begin
      if Source_Name = "awk.source.command_line" then
         return L.Text (Catalog, Source_Name);
      else
         return Source_Name;
      end if;
   end Source_Display_Name;

   Label  : constant String := L.Label (Catalog, Item.Severity);
   Result : U.Unbounded_String :=
     U.To_Unbounded_String
       (Styled
          (L.Text
             (Catalog,
              "awk.diagnostic.header",
              "severity",
              Label,
              L.Primary (Catalog, Item)),
           P.Error,
           Destination_Is_Terminal,
           No_Color_Active));
begin
   if U.Length (Item.Source_Name) > 0
     and then Item.Line > 0
   then
      declare
         Location : constant String :=
           Image (Item.Line)
           & (if Item.Column > 0 then ":" & Image (Item.Column) else "");
      begin
         U.Append
           (Result,
            LF & L.Text
              (Catalog,
               "awk.diagnostic.source_location",
               "path",
               Source_Display_Name (U.To_String (Item.Source_Name)),
               Location));
      end;
   end if;

   if U.Length (Item.Detail) > 0 then
      U.Append
        (Result,
         LF & L.Text
           (Catalog,
            "awk.diagnostic.detail",
            Detail => U.To_String (Item.Detail)));
   end if;

   if U.Length (Item.Hint_Id) > 0 then
      U.Append
        (Result,
         LF & L.Text
           (Catalog,
            "awk.diagnostic.hint",
            "detail",
            L.Text (Catalog, U.To_String (Item.Hint_Id))));
   end if;

   U.Append (Result, LF);
   return U.To_String (Result);
end Diagnostic_Text;
