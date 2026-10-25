with Posix_Tools.Exit_Status;
with Posix_Tools.Localization;

procedure Posix_Tools.Commands.Run_Entry
  (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
   Result  : out Posix_Tools.Commands.Results.Result)
is
begin
   Run (Context, Result);
exception
   when others =>
      Context.Put_Error_Line
        (Command_Name & ": "
         & Posix_Tools.Localization.Text
             (Context.Effective_Locale,
              "posix_tools.diagnostic.internal_failure",
              "internal failure"));
      Result.Status := Posix_Tools.Exit_Status.Internal_Failure;
end Posix_Tools.Commands.Run_Entry;
