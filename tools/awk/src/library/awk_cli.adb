with Awk_CLI.Context_IO;
with Awk_CLI.Diagnostics;
with Awk_CLI.Invocation;
with Awk_CLI.Localization;
with Awk_CLI.Options;
with Awk_CLI.Output;
with Awk_CLI.Platform;

package body Awk_CLI is
   package D renames Awk_CLI.Diagnostics;

   procedure Clear (Context : in out Invocation_Context) is
   begin
      Context.Config := (others => <>);
      Context.IO := (others => <>);
      Context.Last_Diagnostic := (others => <>);
   end Clear;

   procedure Initialize_From_Process (Context : in out Invocation_Context) is
   begin
      Clear (Context);
      for Argument of Awk_CLI.Platform.Process_Arguments loop
         Context.Config.Arguments.Append (Argument);
      end loop;
      Context.Config.Locale := U.To_Unbounded_String (Awk_CLI.Platform.Locale);
      Context.Config.Catalog_Path := U.To_Unbounded_String (Awk_CLI.Platform.Catalog_Path);
      Context.Config.Use_Process := True;
      Context.Config.Stdout_Terminal := Awk_CLI.Platform.Standard_Output_Is_Terminal;
      Context.Config.Stderr_Terminal := Awk_CLI.Platform.Standard_Error_Is_Terminal;
      Context.Config.No_Color := Awk_CLI.Platform.No_Color_Active;
   end Initialize_From_Process;

   function Run (Context : in out Invocation_Context) return Exit_Code is
      Catalog : Awk_CLI.Localization.Catalog;

      procedure Record_Diagnostic (Item : D.Diagnostic) is
      begin
         Context.Last_Diagnostic.Set := True;
         Context.Last_Diagnostic.Id := Item.Message_Id;
         Context.Last_Diagnostic.Category := U.To_Unbounded_String (D.Diagnostic_Category'Image (Item.Category));
         Context.Last_Diagnostic.Severity := U.To_Unbounded_String (D.Diagnostic_Severity'Image (Item.Severity));
      end Record_Diagnostic;

      function Emit_Diagnostic (Item : D.Diagnostic) return Exit_Code is
      begin
         Record_Diagnostic (Item);
         if not Awk_CLI.Context_IO.Write_Standard_Error
           (Context,
            Awk_CLI.Output.Diagnostic_Text
              (Catalog, Item, Context.Config.Stderr_Terminal, Context.Config.No_Color))
         then
            return Exit_Code (D.IO_Exit);
         end if;
         return Exit_Code (D.Status_For (Item));
      end Emit_Diagnostic;

      function Emit_Internal_Diagnostic return Exit_Code is
         Item : constant D.Diagnostic :=
           D.Make
             ("awk.internal.unexpected_exception",
              D.Internal_Error,
              D.Internal);
      begin
         Record_Diagnostic (Item);
         if not Awk_CLI.Context_IO.Write_Standard_Error
           (Context,
            Awk_CLI.Output.Diagnostic_Text
              (Catalog, Item, Context.Config.Stderr_Terminal, Context.Config.No_Color))
         then
            return Exit_Code (D.Internal_Exit);
         end if;
         return Exit_Code (D.Internal_Exit);
      exception
         when others =>
            return Exit_Code (D.Internal_Exit);
      end Emit_Internal_Diagnostic;

      function Emit_CLI_Standard_Output (Text : String) return Exit_Code is
      begin
         if Awk_CLI.Context_IO.Write_Standard_Output (Context, Text) then
            return Exit_Code (D.Success_Exit);
         else
            return Exit_Code (D.IO_Exit);
         end if;
      end Emit_CLI_Standard_Output;

      function Execute_Parsed
        (Parsed : Awk_CLI.Options.Parse_Result) return Exit_Code
      is
      begin
         if not Parsed.Ok then
            Awk_CLI.Output.Set_Color (Parsed.Color);
            return Emit_Diagnostic (Parsed.Diagnostic);
         end if;

         Awk_CLI.Output.Set_Color (Parsed.Options.Color);

         if Parsed.Options.Help_Requested then
            return Emit_CLI_Standard_Output
              (Awk_CLI.Output.Help
                 (Catalog, Context.Config.Stdout_Terminal, Context.Config.No_Color));
         elsif Parsed.Options.Version_Requested then
            return Emit_CLI_Standard_Output (Awk_CLI.Output.Version (Catalog));
         end if;

         declare
            Result : constant Awk_CLI.Invocation.Invocation_Result :=
              Awk_CLI.Invocation.Execute (Context, Parsed.Options);
         begin
            if Result.Ok then
               return Result.Exit_Status;
            else
               return Emit_Diagnostic (Result.Diagnostic);
            end if;
         end;
      exception
         when others =>
            return Emit_Internal_Diagnostic;
      end Execute_Parsed;
   begin
      Awk_CLI.Localization.Initialize
        (Catalog, U.To_String (Context.Config.Catalog_Path), U.To_String (Context.Config.Locale));

      return Execute_Parsed (Awk_CLI.Options.Parse (Context.Config.Arguments));
   exception
      when others =>
         return Emit_Internal_Diagnostic;
   end Run;
end Awk_CLI;
