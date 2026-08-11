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
      Index      : Positive := 1;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while Index <= Count loop
         if Context.Argument (Index) = "--" then
            Index := Index + 1;
            exit;
         elsif Context.Argument (Index) = "-n" then
            if Index = Count then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "missing option argument '-n'");
               return;
            end if;

            Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Context.Argument (Index + 1));
            if Parsed.Status /= Posix_Tools.Numbers.Valid then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid line count '" & Context.Argument (Index + 1) & "'");
               return;
            end if;

            Requested := Parsed.Value;
            Index := Index + 2;
         elsif Context.Argument (Index)'Length > 2
           and then Context.Argument (Index) (1 .. 2) = "-n"
         then
            Parsed := Posix_Tools.Numbers.Parse_Nonnegative
              (Context.Argument (Index) (3 .. Context.Argument (Index)'Last));
            if Parsed.Status /= Posix_Tools.Numbers.Valid then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid line count '" & Context.Argument (Index) & "'");
               return;
            end if;

            Requested := Parsed.Value;
            Index := Index + 1;
         else
            exit;
         end if;
      end loop;
      First_File := Index;

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
