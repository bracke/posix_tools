with Posix_Tools.Commands.Helpers;
with Posix_Tools.Localization;

package body Posix_Tools.Commands.Operation_Reports is
   use type Posix_Tools.File_Operations.Removal_Question;

   --  Default with Shown in place of its "{path}".
   function Expand (Default : String; Shown : String) return String;

   function Ask
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Key     : String;
      Default : String;
      Path    : String) return Boolean
   is
      Shown : constant String := Posix_Tools.Commands.Helpers.Escape_Untrusted (Path);
   begin
      --  Default is the English text with "{path}" where the path goes.
      Context.Put_Error_Line
        (Posix_Tools.Localization.Text_1
           (Context.Effective_Locale, Key, "path", Shown, Expand (Default, Shown)));
      --  The whole answer line, so that the next question reads the next.
      return Posix_Tools.Commands.Helpers.Read_Affirmative_Response (Context, Wait_For_Line_End => True);
   end Ask;

   overriding function Confirm_Removal
     (Self     : in out Context_Observer;
      Path     : String;
      Question : Posix_Tools.File_Operations.Removal_Question) return Boolean
   is
   begin
      if Self.Prompt /= Removal then
         return True;
      elsif Question = Posix_Tools.File_Operations.Descend_Into then
         return Ask
           (Self.Context.all, "posix_tools.rm.descend.prompt", "rm: descend into directory '{path}'?", Path);
      elsif Question = Posix_Tools.File_Operations.Remove_Directory then
         return Ask
           (Self.Context.all, "posix_tools.rm.remove_directory.prompt", "rm: remove directory '{path}'?", Path);
      else
         return Ask (Self.Context.all, "posix_tools.rm.remove.prompt", "rm: remove '{path}'?", Path);
      end if;
   end Confirm_Removal;

   function Expand (Default : String; Shown : String) return String is
      Marker : constant String := "{path}";
   begin
      for I in Default'First .. Default'Last - Marker'Length + 1 loop
         if Default (I .. I + Marker'Length - 1) = Marker then
            return Default (Default'First .. I - 1) & Shown & Default (I + Marker'Length .. Default'Last);
         end if;
      end loop;

      return Default;
   end Expand;

   overriding procedure Report_Error
     (Self  : in out Context_Observer;
      Path  : String;
      Error : Posix_Tools.File_Operations.Operation_Error)
   is
   begin
      Posix_Tools.Commands.Helpers.Subject_Operational_Error
        (Self.Context.all,
         Path,
         Posix_Tools.File_Operations.Message_Key (Error),
         Posix_Tools.File_Operations.Default_Message (Error));
   end Report_Error;

   overriding function Resolve_Conflict
     (Self   : in out Context_Observer;
      Source : String;
      Target : String) return Posix_Tools.File_Operations.Conflict_Choice
   is
      pragma Unreferenced (Source);
   begin
      if Self.Prompt /= Copy_Overwrite then
         return Posix_Tools.File_Operations.Overwrite;
      end if;

      return
        (if Ask (Self.Context.all, "posix_tools.cp.overwrite.prompt", "cp: overwrite '{path}'?", Target)
         then Posix_Tools.File_Operations.Overwrite
         else Posix_Tools.File_Operations.Skip);
   end Resolve_Conflict;
end Posix_Tools.Commands.Operation_Reports;
