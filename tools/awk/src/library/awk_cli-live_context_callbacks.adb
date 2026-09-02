with Awk_CLI.Context_IO;
with Awk_CLI.Platform;

package body Awk_CLI.Live_Context_Callbacks is
   function Write_Output
     (Context : in out Invocation_Context;
      Content : String) return Boolean is
   begin
      return Awk_CLI.Context_IO.Write_Standard_Output (Context, Content);
   end Write_Output;

   function Write_Redirection
     (Context : in out Invocation_Context;
      Path    : String;
      Content : String;
      Append  : Boolean) return Awk_CLI.Redirections.Write_Status is
   begin
      return Awk_CLI.Context_IO.Write_File (Context, Path, Content, Append);
   end Write_Redirection;

   function Read_Command
     (Context : in out Invocation_Context;
      Command : String;
      Output  : out U.Unbounded_String) return Boolean
   is
   begin
      for Item of Context.IO.Commands loop
         if U.To_String (Item.Command) = Command then
            Output := Item.Output;
            return True;
         end if;
      end loop;

      if Context.Config.Use_Process then
         --  Only awklib reaches this callback after parsing/evaluating
         --  command-getline. The CLI does not inspect AWK source for commands.
         return Awk_CLI.Platform.Run_Command (Command, Output);
      end if;

      Output := U.Null_Unbounded_String;
      return False;
   end Read_Command;
end Awk_CLI.Live_Context_Callbacks;
