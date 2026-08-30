with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Streams.Lines;

package body Posix_Tools.Commands.Comm is
   use Ada.Strings.Unbounded;

   package String_Vectors renames Posix_Tools.Streams.Lines.Segment_Vectors;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Suppress_1 : Boolean := False;
      Suppress_2 : Boolean := False;
      Suppress_3 : Boolean := False;
      First      : Positive := 1;
      Left_Data  : Unbounded_String;
      Right_Data : Unbounded_String;
      Left_Lines : String_Vectors.Vector;
      Right_Lines : String_Vectors.Vector;
      Ok         : Boolean;
      L          : Positive := 1;
      R          : Positive := 1;

      procedure Emit (Column : Positive; Text : String);

      procedure Emit (Column : Positive; Text : String) is
         Prefix : Unbounded_String;
      begin
         if Column = 2 then
            if not Suppress_1 then
               Append (Prefix, Character'Val (9));
            end if;
         elsif Column = 3 then
            if not Suppress_1 then
               Append (Prefix, Character'Val (9));
            end if;
            if not Suppress_2 then
               Append (Prefix, Character'Val (9));
            end if;
         end if;
         Context.Put_Line (To_String (Prefix) & Text);
      end Emit;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count
        and then Context.Argument (First)'Length > 1
        and then Context.Argument (First) (Context.Argument (First)'First) = '-'
      loop
         exit when Context.Argument (First) = "--";
         for Ch of Context.Argument (First) (Context.Argument (First)'First + 1 .. Context.Argument (First)'Last) loop
            case Ch is
               when '1' => Suppress_1 := True;
               when '2' => Suppress_2 := True;
               when '3' => Suppress_3 := True;
               when others =>
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                  return;
            end case;
         end loop;
         First := First + 1;
      end loop;
      if First <= Context.Argument_Count and then Context.Argument (First) = "--" then
         First := First + 1;
      end if;
      if Context.Argument_Count /= First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      Posix_Tools.Commands.File_Helpers.Read_All (Context, Context.Argument (First), Left_Data, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;
      Posix_Tools.Commands.File_Helpers.Read_All (Context, Context.Argument (First + 1), Right_Data, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;
      Left_Lines := Posix_Tools.Streams.Lines.Split_LF_Records (To_String (Left_Data));
      Right_Lines := Posix_Tools.Streams.Lines.Split_LF_Records (To_String (Right_Data));

      while L <= Natural (Left_Lines.Length) or else R <= Natural (Right_Lines.Length) loop
         if L > Natural (Left_Lines.Length) then
            if not Suppress_2 then
               Emit (2, Right_Lines.Element (R));
            end if;
            R := R + 1;
         elsif R > Natural (Right_Lines.Length) then
            if not Suppress_1 then
               Emit (1, Left_Lines.Element (L));
            end if;
            L := L + 1;
         elsif Left_Lines.Element (L) = Right_Lines.Element (R) then
            if not Suppress_3 then
               Emit (3, Left_Lines.Element (L));
            end if;
            L := L + 1;
            R := R + 1;
         elsif Left_Lines.Element (L) < Right_Lines.Element (R) then
            if not Suppress_1 then
               Emit (1, Left_Lines.Element (L));
            end if;
            L := L + 1;
         else
            if not Suppress_2 then
               Emit (2, Right_Lines.Element (R));
            end if;
            R := R + 1;
         end if;
      end loop;
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Comm;
