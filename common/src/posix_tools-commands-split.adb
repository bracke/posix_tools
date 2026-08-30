with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Suffixes;
with Posix_Tools.Text.Tab_Stops;

package body Posix_Tools.Commands.Split is
   use Ada.Strings.Unbounded;

   LF : constant Character := Character'Val (10);

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Lines_Per_File : Natural := 1000;
      Bytes_Per_File : Natural := 0;
      Suffix_Length  : Positive := 2;
      First          : Positive := 1;
      Input          : Unbounded_String := To_Unbounded_String ("-");
      Prefix         : Unbounded_String := To_Unbounded_String ("x");
      Data           : Unbounded_String;
      Ok             : Boolean;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "-a" and then First < Context.Argument_Count then
            declare
               Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
                 Posix_Tools.Text.Decimal_Parsing.Natural_In_Range
                   (Context.Argument (First + 1), 1, 12);
            begin
               if not Parsed.Valid then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Context.Argument (First + 1) & "'");
                  return;
               end if;
               Suffix_Length := Positive (Parsed.Value);
            end;
            First := First + 2;
         elsif Context.Argument (First) = "-l" and then First < Context.Argument_Count then
            declare
               Parsed : constant Posix_Tools.Text.Tab_Stops.Parsed_Stop :=
                 Posix_Tools.Text.Tab_Stops.Parse_Stop (Context.Argument (First + 1), 0);
            begin
               if not Parsed.Valid then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Context.Argument (First + 1) & "'");
                  return;
               end if;
               Lines_Per_File := Parsed.Value;
            end;
            First := First + 2;
         elsif Context.Argument (First) = "-b" and then First < Context.Argument_Count then
            declare
               Parsed : constant Posix_Tools.Text.Tab_Stops.Parsed_Stop :=
                 Posix_Tools.Text.Tab_Stops.Parse_Stop (Context.Argument (First + 1), 0);
            begin
               if not Parsed.Valid then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Context.Argument (First + 1) & "'");
                  return;
               end if;
               Bytes_Per_File := Parsed.Value;
            end;
            First := First + 2;
         elsif Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First) = "-a"
           or else Context.Argument (First) = "-l"
           or else Context.Argument (First) = "-b"
         then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "missing option argument '" & Context.Argument (First) & "'");
            return;
         else
            exit;
         end if;
      end loop;
      declare
         Remaining : constant Natural :=
           (if First > Context.Argument_Count then 0 else Context.Argument_Count - First + 1);
      begin
         if Remaining > 2 then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "extra operand '" & Context.Argument (First + 2) & "'");
            return;
         elsif Remaining >= 1 then
            Input := To_Unbounded_String (Context.Argument (First));
            if Remaining = 2 then
               Prefix := To_Unbounded_String (Context.Argument (First + 1));
            end if;
         end if;
      end;

      Posix_Tools.Commands.File_Helpers.Read_All (Context, To_String (Input), Data, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      declare
         Text  : constant String := To_String (Data);
         Start : Positive := 1;
         Part  : Natural := 0;
      begin
         while Start <= Text'Length loop
            declare
               Last : Natural := Start - 1;
            begin
               if Bytes_Per_File > 0 then
                  Last := Natural'Min (Text'Length, Start + Bytes_Per_File - 1);
               else
                  for Count in 1 .. Lines_Per_File loop
                     exit when Last >= Text'Length;
                     Last := Last + 1;
                     while Last < Text'Length and then Text (Last) /= LF loop
                        Last := Last + 1;
                     end loop;
                  end loop;
               end if;
               if Part >= Posix_Tools.Text.Suffixes.Lowercase_Capacity (Suffix_Length) then
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context,
                     To_String (Prefix),
                     "posix_tools.diagnostic.resource.limit",
                     "resource limit exceeded");
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                  return;
               end if;
               Posix_Tools.Commands.File_Helpers.Write_File
                 (To_String (Prefix)
                  & Posix_Tools.Text.Suffixes.Lowercase_Image (Part, Suffix_Length),
                  Text (Start .. Last),
                  False,
                  Ok);
               if not Ok then
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context,
                     To_String (Prefix)
                     & Posix_Tools.Text.Suffixes.Lowercase_Image (Part, Suffix_Length),
                     "posix_tools.diagnostic.file.open_failed",
                     "cannot open file");
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                  return;
               end if;
               Part := Part + 1;
               Start := Last + 1;
            end;
         end loop;
      end;
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;

end Posix_Tools.Commands.Split;
