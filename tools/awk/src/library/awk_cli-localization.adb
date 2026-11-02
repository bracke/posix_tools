with Awk_CLI.Localization.Defaults;
with Posix_Tools.Localization;

package body Awk_CLI.Localization is
   --  Template with "{Name}" and "{detail}" replaced by Value and Detail.
   function Fill (Template, Name, Value, Detail : String) return String;

   function Fill (Template, Name, Value, Detail : String) return String is
      Result : U.Unbounded_String;
      I      : Natural := Template'First;

      --  Whether "{" & Placeholder & "}" starts at I.
      function At_Placeholder (Placeholder : String) return Boolean is
        (Placeholder /= ""
         and then I + Placeholder'Length + 1 <= Template'Last
         and then Template (I .. I + Placeholder'Length + 1) = "{" & Placeholder & "}");
   begin
      while I <= Template'Last loop
         if At_Placeholder (Name) then
            U.Append (Result, Value);
            I := I + Name'Length + 2;
         elsif At_Placeholder ("detail") then
            U.Append (Result, Detail);
            I := I + 8;
         else
            U.Append (Result, Template (I));
            I := I + 1;
         end if;
      end loop;
      return U.To_String (Result);
   end Fill;

   procedure Initialize
     (Item         : in out Catalog;
      Catalog_Path : String;
      Locale       : String)
   is
   begin
      Item.Path := U.To_Unbounded_String (Catalog_Path);
      Item.Locale := U.To_Unbounded_String (Locale);
   end Initialize;

   function Text
     (Item : Catalog;
      Key  : String;
      Name : String := "";
      Value : String := "";
      Detail : String := "") return String
   is
      Fallback_Key : constant String := "awk.internal.localization_failed";
      Names        : constant String :=
        (if Name /= "" and then Detail /= "" then Name & " detail"
         elsif Name /= "" then Name
         elsif Detail /= "" then "detail"
         else "");
      Template     : constant String :=
        Posix_Tools.Localization.Catalog_Pattern
          (Catalog_Path => U.To_String (Item.Path),
           Locale       => U.To_String (Item.Locale),
           Key          => Key,
           Names        => Names,
           Default      => Defaults.Template (Key));
   begin
      if Template /= "" then
         return Fill
           (Template,
            Name,
            (if Name /= "" then Awk_CLI.Diagnostics.Escape (Value) else ""),
            (if Detail /= "" then Awk_CLI.Diagnostics.Escape (Detail) else ""));
      elsif Key /= Fallback_Key then
         --  Not a message of the catalog, which the tests rule out.
         return Text (Item, Fallback_Key, Detail => Key);
      else
         return Awk_CLI.Diagnostics.Escape (Key);
      end if;
   end Text;

   function Primary (Item : Catalog; Diagnostic : Awk_CLI.Diagnostics.Diagnostic) return String is
   begin
      return Text
        (Item,
         U.To_String (Diagnostic.Message_Id),
         U.To_String (Diagnostic.Name),
         U.To_String (Diagnostic.Value),
         U.To_String (Diagnostic.Detail));
   end Primary;

   function Label (Item : Catalog; Severity : Awk_CLI.Diagnostics.Diagnostic_Severity) return String is
   begin
      case Severity is
         when Awk_CLI.Diagnostics.Information =>
            return Text (Item, "awk.diagnostic.label.info");
         when Awk_CLI.Diagnostics.Warning =>
            return Text (Item, "awk.diagnostic.label.warning");
         when Awk_CLI.Diagnostics.Error =>
            return Text (Item, "awk.diagnostic.label.error");
         when Awk_CLI.Diagnostics.Internal_Error =>
            return Text (Item, "awk.diagnostic.label.internal_error");
      end case;
   end Label;
end Awk_CLI.Localization;
