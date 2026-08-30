with Posix_Tools.Arguments;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Env is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Pairs       : Posix_Tools.Arguments.Vector;
      First       : Positive := 1;
      End_Options : Boolean := False;

      function Equal_Position (Text : String) return Natural;

      procedure Remove_Name (Name : String);

      procedure Replace_Or_Append (Pair : String);

      function Equal_Position (Text : String) return Natural is
      begin
         for I in Text'Range loop
            if Text (I) = '=' then
               return I;
            end if;
         end loop;
         return 0;
      end Equal_Position;

      procedure Remove_Name (Name : String) is
         I : Natural := 1;
      begin
         while I <= Natural (Pairs.Length) loop
            declare
               Existing       : constant String := Pairs.Element (I);
               Existing_Equal : constant Natural := Equal_Position (Existing);
            begin
               if Existing_Equal > 0
                 and then Existing (Existing'First .. Existing_Equal - 1) = Name
               then
                  Pairs.Delete (I);
               else
                  I := I + 1;
               end if;
            end;
         end loop;
      end Remove_Name;

      procedure Replace_Or_Append (Pair : String) is
         Equal : constant Natural := Equal_Position (Pair);
      begin
         if Equal = 0 then
            return;
         end if;

         for I in 1 .. Natural (Pairs.Length) loop
            declare
               Existing       : constant String := Pairs.Element (I);
               Existing_Equal : constant Natural := Equal_Position (Existing);
            begin
               if Existing_Equal > 0
                 and then Existing (Existing'First .. Existing_Equal - 1) = Pair (Pair'First .. Equal - 1)
               then
                  Pairs.Replace_Element (I, Pair);
                  return;
               end if;
            end;
         end loop;

         Pairs.Append (Pair);
      end Replace_Or_Append;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Pairs := Context.Environment_Pairs;
      while First <= Context.Argument_Count loop
         if not End_Options and then Context.Argument (First) = "--" then
            End_Options := True;
            First := First + 1;
         elsif not End_Options and then Context.Argument (First) = "-i" then
            Pairs.Clear;
            First := First + 1;
         elsif not End_Options and then Context.Argument (First) = "-u" then
            if First = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-u'");
               return;
            elsif Context.Argument (First + 1) = ""
              or else (for some Ch of Context.Argument (First + 1) => Ch = '=')
            then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (First + 1) & "'");
               return;
            end if;
            Remove_Name (Context.Argument (First + 1));
            First := First + 2;
         elsif (for some Ch of Context.Argument (First) => Ch = '=') then
            if Context.Argument (First) (Context.Argument (First)'First) = '=' then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (First) & "'");
               return;
            end if;
            Replace_Or_Append (Context.Argument (First));
            First := First + 1;
         else
            exit;
         end if;
      end loop;

      if First <= Context.Argument_Count then
         declare
            Utility   : constant String := Context.Argument (First);
            Arguments : Posix_Tools.Arguments.Vector;
            Exit_Code : Integer := 0;
         begin
            for I in First + 1 .. Context.Argument_Count loop
               Arguments.Append (Context.Argument (I));
            end loop;

            if not Context.Execute_Utility_With_Environment (Utility, Arguments, Pairs, Exit_Code) then
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Utility, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               if Exit_Code in Integer (Posix_Tools.Exit_Status.Utility_Cannot_Invoke)
                 .. Integer (Posix_Tools.Exit_Status.Utility_Not_Found)
               then
                  Result.Status := Posix_Tools.Exit_Status.Code (Exit_Code);
               else
                  Result.Status := Posix_Tools.Exit_Status.Utility_Not_Found;
               end if;
            elsif Exit_Code = 0 then
               Result.Status :=
                 (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
                  else Posix_Tools.Exit_Status.Success);
            elsif Exit_Code in Integer (Posix_Tools.Exit_Status.Code'First)
              .. Integer (Posix_Tools.Exit_Status.Code'Last)
            then
               Result.Status := Posix_Tools.Exit_Status.Code (Exit_Code);
            else
               Result.Status := Posix_Tools.Exit_Status.Internal_Failure;
            end if;
            return;
         end;
      end if;

      for I in 1 .. Natural (Pairs.Length) loop
         Context.Put_Line (Pairs.Element (I));
      end loop;

      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Env;
