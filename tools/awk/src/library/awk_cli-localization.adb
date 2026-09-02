with Messages.Arguments;
with Messages.Result;

package body Awk_CLI.Localization is
   use type Messages.Result.Render_Status;
   procedure Initialize
     (Item         : in out Catalog;
      Catalog_Path : String;
      Locale       : String)
   is
   begin
      Messages.Runtime.Initialize (Item.Runtime, Catalog_Path);
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
      Args   : Messages.Arguments.Arguments;
      Result : Messages.Result.Render_Result;
   begin
      if Name /= "" then
         Messages.Arguments.Set (Args, Name, Awk_CLI.Diagnostics.Escape (Value));
      end if;
      if Detail /= "" then
         Messages.Arguments.Set (Args, "detail", Awk_CLI.Diagnostics.Escape (Detail));
      end if;
      Result := Messages.Runtime.Render (Item.Runtime, U.To_String (Item.Locale), Key, Args);
      if Result.Status = Messages.Result.Success then
         return Messages.Result.Output_Text (Result.Text);
      elsif Key /= Fallback_Key then
         declare
            Fallback_Args   : Messages.Arguments.Arguments;
            Fallback_Result : Messages.Result.Render_Result;
         begin
            Messages.Arguments.Set
              (Fallback_Args, "detail", Awk_CLI.Diagnostics.Escape (Key));
            Fallback_Result :=
              Messages.Runtime.Render
                (Item.Runtime, U.To_String (Item.Locale), Fallback_Key, Fallback_Args);
            if Fallback_Result.Status = Messages.Result.Success then
               return Messages.Result.Output_Text (Fallback_Result.Text);
            end if;
         end;
         return Awk_CLI.Diagnostics.Escape (Key);
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
