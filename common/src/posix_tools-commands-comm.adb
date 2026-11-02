with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers.Collation;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Streams.Lines;

package body Posix_Tools.Commands.Comm is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;

   package String_Vectors renames Posix_Tools.Streams.Lines.Segment_Vectors;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Suppress_1 : Boolean := False;
      Suppress_2 : Boolean := False;
      Suppress_3 : Boolean := False;
      First      : Positive;
      Valid      : Boolean;
      Locale     : constant String :=
        Context.Category_Locale (Posix_Tools.Commands.Contexts.Collation);
      Left_Data  : Unbounded_String;
      Right_Data : Unbounded_String;
      Left_Lines : String_Vectors.Vector;
      Right_Lines : String_Vectors.Vector;
      Ok         : Boolean;
      L          : Positive := 1;
      R          : Positive := 1;

      procedure Emit (Column : Positive; Text : String);

      --  How Left collates against Right; lines the locale ranks equal
      --  but that differ are ordered by their bytes.
      function Compare (Left, Right : String) return Integer is
        (declare
            Collated : constant Integer :=
              Posix_Tools.Commands.Text_Helpers.Collation.Compare (Locale, Left, Right);
         begin
           (if Collated /= 0 then Collated
            elsif Left < Right then -1
            elsif Left > Right then 1
            else 0));

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean);

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean)
      is
         pragma Unreferenced (Value, Result);
      begin
         case Name is
            when '1' => Suppress_1 := True;
            when '2' => Suppress_2 := True;
            when others => Suppress_3 := True;
         end case;
         Valid := True;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);

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

      Parse (Context, Result, "123", "", First, Valid);
      if not Valid then
         return;
      elsif Context.Argument_Count > First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Extra_Operand, Context.Argument (First + 2));
         return;
      elsif Context.Argument_Count < First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;

      Posix_Tools.Commands.File_Helpers.Streaming.Read_All (Context, Context.Argument (First), Left_Data, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;
      Posix_Tools.Commands.File_Helpers.Streaming.Read_All (Context, Context.Argument (First + 1), Right_Data, Ok);
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
         elsif Compare (Left_Lines.Element (L), Right_Lines.Element (R)) = 0 then
            if not Suppress_3 then
               Emit (3, Left_Lines.Element (L));
            end if;
            L := L + 1;
            R := R + 1;
         elsif Compare (Left_Lines.Element (L), Right_Lines.Element (R)) < 0 then
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
      Posix_Tools.Commands.Helpers.Finish (Context, Result);
   end Run;
end Posix_Tools.Commands.Comm;
