with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Numbers;

package body Posix_Tools.Commands.Head is
   use type Posix_Tools.Numbers.Parse_Status;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First_File : Positive := 1;
      Count      : constant Natural := Context.Argument_Count;
      Parsed     : Posix_Tools.Numbers.Parse_Result;
      Ok         : Boolean;
      All_Ok     : Boolean := True;
      Sources    : Natural;
      Requested  : Posix_Tools.Numbers.Count := 10;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Count >= 1 and then Context.Argument (1) = "-n" then
         if Count = 1 then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "missing option argument '-n'");
            return;
         end if;

         Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Context.Argument (2));
         if Parsed.Status /= Posix_Tools.Numbers.Valid then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid line count '" & Context.Argument (2) & "'");
            return;
         end if;

         Requested := Parsed.Value;
         First_File := 3;
      elsif Count >= 1 and then Context.Argument (1)'Length > 2
        and then Context.Argument (1) (1 .. 2) = "-n"
      then
         Parsed := Posix_Tools.Numbers.Parse_Nonnegative
           (Context.Argument (1) (3 .. Context.Argument (1)'Last));
         if Parsed.Status /= Posix_Tools.Numbers.Valid then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid line count '" & Context.Argument (1) & "'");
            return;
         end if;

         Requested := Parsed.Value;
         First_File := 2;
      end if;

      if First_File <= Count and then Context.Argument (First_File) = "--" then
         First_File := First_File + 1;
      end if;

      Sources := (if First_File > Count then 1 else Count - First_File + 1);
      if First_File > Count then
         Posix_Tools.Commands.File_Helpers.Copy_Line_Prefix (Context, "-", Requested, Ok);
         All_Ok := Ok;
      else
         for I in First_File .. Count loop
            if Sources > 1 then
               if I > First_File then
                  Context.Put_Line ("");
                  if Context.Output_Failed then
                     All_Ok := False;
                     exit;
                  end if;
               end if;
               Context.Put_Line ("==> " & Context.Argument (I) & " <==");
               if Context.Output_Failed then
                  All_Ok := False;
                  exit;
               end if;
            end if;

            Posix_Tools.Commands.File_Helpers.Copy_Line_Prefix
              (Context, Context.Argument (I), Requested, Ok);
            All_Ok := All_Ok and Ok;
         end loop;
      end if;

      Result.Status :=
        (if All_Ok then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Head;
