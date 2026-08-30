with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Streams.Lines;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Cut_Fields;

package body Posix_Tools.Commands.Cut is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Text.Cut_Fields.Range_Item;

   LF : constant Character := Character'Val (10);

   package String_Vectors renames Posix_Tools.Streams.Lines.Segment_Vectors;
   package Range_Vectors is new Ada.Containers.Vectors
     (Positive, Posix_Tools.Text.Cut_Fields.Range_Item);

   function Parse_List (Text : String; Ranges : in out Range_Vectors.Vector) return Boolean;
   function Selected (Ranges : Range_Vectors.Vector; Position : Positive) return Boolean;

   function Parse_List (Text : String; Ranges : in out Range_Vectors.Vector) return Boolean is
      Index : Positive := Text'First;

      function Is_List_Separator (Ch : Character) return Boolean;

      function Is_List_Separator (Ch : Character) return Boolean is
      begin
         return Posix_Tools.Text.Byte_Classes.Is_Cut_List_Separator (Ch);
      end Is_List_Separator;

   begin
      Ranges.Clear;
      if not Posix_Tools.Text.Cut_Fields.Parse_List (Text) then
         return False;
      end if;

      while Index <= Text'Last loop
         declare
            Parsed : constant Posix_Tools.Text.Cut_Fields.Parsed_Range :=
              Posix_Tools.Text.Cut_Fields.Parse_Range_Item (Text, Index);
         begin
            if not Parsed.Valid then
               return False;
            end if;
            Ranges.Append (Parsed.Item);
            exit when Parsed.Next = 0;
            Index := Parsed.Next;
            if not Is_List_Separator (Text (Index)) then
               return False;
            end if;
            while Index <= Text'Last and then Is_List_Separator (Text (Index)) loop
               Index := Index + 1;
            end loop;
            if Index > Text'Last then
               return False;
            end if;
         end;
      end loop;
      return True;
   end Parse_List;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Mode       : Character := Character'Val (0);
      Ranges     : Range_Vectors.Vector;
      Delimiter  : Character := Character'Val (9);
      Has_Delimiter : Boolean := False;
      Suppress   : Boolean := False;
      No_Split   : Boolean := False;
      First_File : Positive := 1;
      All_Ok     : Boolean := True;

      procedure Cut_File (Name : String; Ok : out Boolean);
      procedure Emit_Line (Line : String);

      procedure Cut_File (Name : String; Ok : out Boolean) is
         Data  : Unbounded_String;
         Lines : String_Vectors.Vector;
      begin
         Posix_Tools.Commands.File_Helpers.Read_All (Context, Name, Data, Ok);
         if not Ok then
            return;
         end if;
         Lines := Posix_Tools.Streams.Lines.Split_LF_Records (To_String (Data));
         for Line of Lines loop
            Emit_Line (Line);
            if Context.Output_Failed then
               Ok := False;
               return;
            end if;
         end loop;
      end Cut_File;

      procedure Emit_Line (Line : String) is
         Clean  : constant String :=
           (if Line'Length > 0 and then Line (Line'Last) = LF
            then Line (Line'First .. Line'Last - 1)
            else Line);
         Output : Unbounded_String;
         Field  : Positive := 1;
         Start  : Positive := Clean'First;
         Seen_Delimiter : Boolean := False;
      begin
         if Mode = 'b' or else Mode = 'c' then
            for I in Clean'Range loop
               if Selected (Ranges, I - Clean'First + 1) then
                  Append (Output, Clean (I));
               end if;
            end loop;
            Context.Put_Line (To_String (Output));
         else
            for I in Clean'Range loop
               if Clean (I) = Delimiter then
                  Seen_Delimiter := True;
                  if Selected (Ranges, Field) then
                     if Length (Output) > 0 then
                        Append (Output, Delimiter);
                     end if;
                     Append (Output, Clean (Start .. I - 1));
                  end if;
                  Field := Field + 1;
                  Start := I + 1;
               end if;
            end loop;
            if Selected (Ranges, Field) then
               if Length (Output) > 0 then
                  Append (Output, Delimiter);
               end if;
               if Start <= Clean'Last then
                  Append (Output, Clean (Start .. Clean'Last));
               end if;
            end if;
            if Seen_Delimiter or else not Suppress then
               Context.Put_Line ((if Seen_Delimiter then To_String (Output) else Clean));
            end if;
         end if;
      end Emit_Line;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First_File <= Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (First_File);
         begin
            if Arg = "-s" then
               Suppress := True;
               First_File := First_File + 1;
            elsif Arg = "-n" then
               No_Split := True;
               First_File := First_File + 1;
            elsif Arg = "-d" then
               if First_File >= Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "missing option argument '-d'");
                  return;
               elsif Context.Argument (First_File + 1)'Length /= 1 then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Context.Argument (First_File + 1) & "'");
                  return;
               end if;
               Delimiter := Context.Argument (First_File + 1) (Context.Argument (First_File + 1)'First);
               Has_Delimiter := True;
               First_File := First_File + 2;
            elsif Arg'Length > 2
              and then Arg (Arg'First) = '-'
              and then Arg (Arg'First + 1) = 'd'
            then
               if Arg'Length /= 3 then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Arg (Arg'First + 2 .. Arg'Last) & "'");
                  return;
               end if;
               Delimiter := Arg (Arg'First + 2);
               Has_Delimiter := True;
               First_File := First_File + 1;
            elsif Arg'Length >= 2
              and then Arg (Arg'First) = '-'
              and then Arg (Arg'First + 1) in 'b' | 'c' | 'f'
            then
               if Mode /= Character'Val (0) then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "multiple list options");
                  return;
               end if;
               Mode := Arg (Arg'First + 1);
               declare
                  Spec : constant String :=
                    (if Arg'Length > 2 then Arg (Arg'First + 2 .. Arg'Last)
                     elsif First_File < Context.Argument_Count then Context.Argument (First_File + 1)
                     else "");
               begin
                  if Spec = "" then
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "missing option argument '-" & Mode & "'");
                     return;
                  end if;
                  if not Parse_List (Spec, Ranges) then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand '" & Spec & "'");
                     return;
                  end if;
                  First_File := First_File + (if Arg'Length > 2 then 1 else 2);
               end;
            elsif Arg = "--" then
               First_File := First_File + 1;
               exit;
            else
               exit;
            end if;
         end;
      end loop;

      if Mode = Character'Val (0) then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;
      if No_Split and then Mode /= 'b' then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand '-n'");
         return;
      end if;
      if (Has_Delimiter or else Suppress) and then Mode /= 'f' then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid field option");
         return;
      end if;
      if Context.Argument_Count < First_File then
         Cut_File ("-", All_Ok);
      else
         for I in First_File .. Context.Argument_Count loop
            declare
               Ok : Boolean;
            begin
               Cut_File (Context.Argument (I), Ok);
               All_Ok := All_Ok and Ok;
            end;
         end loop;
      end if;
      Result.Status :=
        (if All_Ok and then not Context.Output_Failed then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;

   function Selected (Ranges : Range_Vectors.Vector; Position : Positive) return Boolean is
   begin
      for Item of Ranges loop
         if Posix_Tools.Text.Cut_Fields.Contains_Position (Item, Position) then
            return True;
         end if;
      end loop;
      return False;
   end Selected;
end Posix_Tools.Commands.Cut;
