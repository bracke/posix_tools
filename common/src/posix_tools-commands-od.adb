with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Od_Rendering;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.OD_Formats;

package body Posix_Tools.Commands.Od is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Text.OD_Formats.Address_Base;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Address : Posix_Tools.Text.OD_Formats.Address_Base := Posix_Tools.Text.OD_Formats.Octal_Address;
      Formats : Posix_Tools.Commands.Od_Rendering.Dump_Spec_Vectors.Vector;
      Skip    : Natural := 0;
      Limit   : Natural := 0;
      Has_Limit : Boolean := False;
      Verbose : Boolean := False;
      First : Positive := 1;
      Data  : Unbounded_String;
      Ok    : Boolean := True;

      function Set_Address_Base (Spec : String) return Boolean is
         Parsed : constant Posix_Tools.Text.OD_Formats.Parsed_Address_Base :=
           Posix_Tools.Text.OD_Formats.Address_Base_For (Spec);
      begin
         if not Parsed.Valid then
            return False;
         end if;
         Address := Parsed.Base;
         return True;
      end Set_Address_Base;

      function Append_Dump_Formats (Spec : String) return Boolean is
         Index : Positive := Spec'First;
      begin
         if Spec = "" then
            return False;
         end if;

         while Index <= Spec'Last loop
            declare
               Parsed : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
                 Posix_Tools.Text.OD_Formats.Dump_Format_Item (Spec, Index);
            begin
               if not Parsed.Valid then
                  return False;
               end if;

               Posix_Tools.Commands.Od_Rendering.Append_Dump_Format (Formats, Parsed);
               if Parsed.At_End then
                  exit;
               end if;
               Index := Parsed.Next_Index;
            end;
         end loop;
         return True;
      end Append_Dump_Formats;

      procedure Set_Required_Number_Option
        (Option  : String;
         Text    : String;
         Present : Boolean;
         Target  : out Natural;
         Valid   : out Boolean)
      is
         Parsed : constant Posix_Tools.Text.OD_Formats.Parsed_Offset_Count :=
           Posix_Tools.Text.OD_Formats.Offset_Count (Text, Option = "-j");
      begin
         if not Present then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "missing option argument '" & Option & "'");
            Valid := False;
            Target := 0;
         elsif not Parsed.Valid then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid operand '" & Text & "'");
            Valid := False;
            Target := 0;
         else
            Valid := True;
            Target := Parsed.Value;
         end if;
      end Set_Required_Number_Option;

      function Append_Shorthand_Formats (Option : String) return Boolean is
      begin
         return Posix_Tools.Commands.Od_Rendering.Append_Shorthand_Formats (Formats, Option);
      end Append_Shorthand_Formats;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count and then Context.Argument (First)'Length > 0
        and then Context.Argument (First) (Context.Argument (First)'First) = '-'
      loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First) in "-a" | "-b" | "-c" | "-d" | "-o" | "-s" | "-x" then
            if not Posix_Tools.Commands.Od_Rendering.Append_Shorthand_Format
              (Formats, Context.Argument (First) (Context.Argument (First)'First + 1))
            then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (First) & "'");
               return;
            end if;
            First := First + 1;
         elsif Context.Argument (First) = "-v" then
            Verbose := True;
            First := First + 1;
         elsif Context.Argument (First) = "-A" then
            if First >= Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "missing option argument '-A'");
               return;
            elsif not Set_Address_Base (Context.Argument (First + 1)) then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (First + 1) & "'");
               return;
            end if;
            First := First + 2;
         elsif Context.Argument (First)'Length > 2
           and then Context.Argument (First) (Context.Argument (First)'First .. Context.Argument (First)'First + 1)
             = "-A"
         then
            if not Set_Address_Base
              (Context.Argument (First) (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last))
            then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '"
                  & Context.Argument (First) (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last)
                  & "'");
               return;
            end if;
            First := First + 1;
         elsif Context.Argument (First) = "-j" then
            declare
               Valid : Boolean;
            begin
               Set_Required_Number_Option
                 ("-j",
                  (if First < Context.Argument_Count then Context.Argument (First + 1) else ""),
                  First < Context.Argument_Count,
                  Skip,
                  Valid);
               if not Valid then
                  return;
               end if;
            end;
            First := First + 2;
         elsif Context.Argument (First)'Length > 2
           and then Context.Argument (First) (Context.Argument (First)'First .. Context.Argument (First)'First + 1)
             = "-j"
         then
            declare
               Valid : Boolean;
            begin
               Set_Required_Number_Option
                 ("-j",
                  Context.Argument (First) (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last),
                  True,
                  Skip,
                  Valid);
               if not Valid then
                  return;
               end if;
            end;
            First := First + 1;
         elsif Context.Argument (First) = "-N" then
            declare
               Valid : Boolean;
            begin
               Set_Required_Number_Option
                 ("-N",
                  (if First < Context.Argument_Count then Context.Argument (First + 1) else ""),
                  First < Context.Argument_Count,
                  Limit,
                  Valid);
               if not Valid then
                  return;
               end if;
            end;
            Has_Limit := True;
            First := First + 2;
         elsif Context.Argument (First)'Length > 2
           and then Context.Argument (First) (Context.Argument (First)'First .. Context.Argument (First)'First + 1)
             = "-N"
         then
            declare
               Valid : Boolean;
            begin
               Set_Required_Number_Option
                 ("-N",
                  Context.Argument (First) (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last),
                  True,
                  Limit,
                  Valid);
               if not Valid then
                  return;
               end if;
            end;
            Has_Limit := True;
            First := First + 1;
         elsif Context.Argument (First) = "-t" then
            if First >= Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "missing option argument '-t'");
               return;
            elsif not Append_Dump_Formats (Context.Argument (First + 1)) then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (First + 1) & "'");
               return;
            end if;
            First := First + 2;
         elsif Context.Argument (First)'Length > 2
           and then Context.Argument (First) (Context.Argument (First)'First .. Context.Argument (First)'First + 1)
             = "-t"
         then
            if not Append_Dump_Formats
              (Context.Argument (First) (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last))
            then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '"
                  & Context.Argument (First) (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last)
                  & "'");
               return;
            end if;
            First := First + 1;
         elsif Context.Argument (First)'Length > 2
           and then Append_Shorthand_Formats (Context.Argument (First))
         then
            First := First + 1;
         else
            exit;
         end if;
      end loop;
      if Formats.Is_Empty then
         Formats.Append
           (Posix_Tools.Commands.Od_Rendering.Dump_Spec'
              (Kind => Posix_Tools.Commands.Od_Rendering.Octal_Integer,
               Size => 2));
      end if;
      if Context.Argument_Count < First then
         Posix_Tools.Commands.File_Helpers.Read_All (Context, "-", Data, Ok);
      else
         for I in First .. Context.Argument_Count loop
            declare
               Chunk : Unbounded_String;
            begin
               Posix_Tools.Commands.File_Helpers.Read_All (Context, Context.Argument (I), Chunk, Ok);
               exit when not Ok;
               Append (Data, To_String (Chunk));
            end;
         end loop;
      end if;
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      declare
         Source : constant String := To_String (Data);
         Actual_Skip : constant Natural := Natural'Min (Skip, Source'Length);
         Available : constant Natural := Source'Length - Actual_Skip;
         Selected_Length : constant Natural := (if Has_Limit then Natural'Min (Limit, Available) else Available);
         Text   : constant String :=
           (if Selected_Length = 0 then ""
            else Source (Source'First + Actual_Skip .. Source'First + Actual_Skip + Selected_Length - 1));
      begin
         if Skip > Source'Length then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.resource.count_too_large", "count too large");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         Posix_Tools.Commands.Od_Rendering.Render
           (Context     => Context,
            Text        => Text,
            Actual_Skip => Actual_Skip,
            Address     => Address,
            Formats     => Formats,
            Verbose     => Verbose);
      end;
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;

end Posix_Tools.Commands.Od;
