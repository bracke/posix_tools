separate (Awk_CLI.Execution.Callbacks)
procedure Write_Redirection
  (User_Data : System.Address;
   Name      : String;
   Text      : String;
   Append    : Boolean;
   Truncate  : Boolean)
is
   pragma Unreferenced (Truncate);
   State : constant Stream_State_Access.Object_Pointer :=
     Stream_State_Access.To_Pointer (User_Data);
   Result : Awk_CLI.Redirections.Write_Status;
begin
   if State.Has_Failure then
      return;
   end if;

   if State.Live_Redirection = null then
      State.Redirs.Append
        (Awk_CLI.Redirections.Redirected_Output'
           (Path    => U.To_Unbounded_String (Name),
            Content => U.To_Unbounded_String (Text),
            Append  => Append));
   else
      Result := State.Live_Redirection.all (State.Live_User_Data, Name, Text, Append);
      case Result is
         when Awk_CLI.Redirections.Write_Success =>
            null;
         when Awk_CLI.Redirections.Open_Failed =>
            Set_Failure
              (State.all,
               Awk_CLI.Diagnostics.Make
                 ("awk.output_file.open_failed",
                  Awk_CLI.Diagnostics.Error,
                  Awk_CLI.Diagnostics.Output,
                  Name => "path",
                  Value => Name));
         when Awk_CLI.Redirections.Write_Failed =>
            Set_Failure
              (State.all,
               Awk_CLI.Diagnostics.Make
                 ("awk.output_file.write_failed",
                  Awk_CLI.Diagnostics.Error,
                  Awk_CLI.Diagnostics.Output,
                  Name => "path",
                  Value => Name));
      end case;
   end if;
end Write_Redirection;
