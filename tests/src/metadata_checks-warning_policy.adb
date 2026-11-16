with Ada.Characters.Handling;
with Ada.Strings.Unbounded;
with Package_Entries;
with Project_Tools.Files;
with Tooling_Checks;
with Tooling_Support;

package body Metadata_Checks.Warning_Policy is
   use Ada.Strings.Unbounded;

   function Rejects_Warnings (Raw_Content : String) return Boolean is
      Cursor       : Natural := Raw_Content'First;
      Found_Clause : Boolean := False;

      function Is_Identifier_Character (Ch : Character) return Boolean is
        (Ch in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_');

      procedure Skip_Trivia (Position : in out Natural) is
      begin
         loop
            while Position <= Raw_Content'Last
              and then Raw_Content (Position) in ' ' | Character'Val (9)
                | Character'Val (10) | Character'Val (13)
            loop
               Position := Position + 1;
            end loop;
            exit when Position >= Raw_Content'Last
              or else Raw_Content (Position .. Position + 1) /= "--";
            while Position <= Raw_Content'Last
              and then Raw_Content (Position) /= Character'Val (10)
            loop
               Position := Position + 1;
            end loop;
         end loop;
      end Skip_Trivia;

      procedure Read_Identifier
        (Position : in out Natural;
         Value : out Unbounded_String;
         Found : out Boolean)
      is
         First : constant Natural := Position;
      begin
         Value := Null_Unbounded_String;
         Found := Position <= Raw_Content'Last
           and then Raw_Content (Position) in 'a' .. 'z' | 'A' .. 'Z' | '_';
         if not Found then
            return;
         end if;
         while Position <= Raw_Content'Last
           and then Is_Identifier_Character (Raw_Content (Position))
         loop
            Position := Position + 1;
         end loop;
         Value := To_Unbounded_String
           (Ada.Characters.Handling.To_Lower
              (Raw_Content (First .. Position - 1)));
      end Read_Identifier;

      procedure Read_String
        (Position : in out Natural;
         Value : out Unbounded_String;
         Found : out Boolean) is
      begin
         Value := Null_Unbounded_String;
         Found := Position <= Raw_Content'Last
           and then Raw_Content (Position) = '"';
         if not Found then
            return;
         end if;
         Position := Position + 1;
         while Position <= Raw_Content'Last loop
            if Raw_Content (Position) = '"' then
               if Position < Raw_Content'Last
                 and then Raw_Content (Position + 1) = '"'
               then
                  Append (Value, '"');
                  Position := Position + 2;
               else
                  Position := Position + 1;
                  return;
               end if;
            else
               Append (Value, Raw_Content (Position));
               Position := Position + 1;
            end if;
         end loop;
         Found := False;
      end Read_String;

      procedure Check_Clause
        (Position  : in out Natural;
         Is_Clause : out Boolean;
         Valid     : out Boolean)
      is
         Token        : Unbounded_String;
         Present      : Boolean;
         Has_Error    : Boolean := False;
         Reject_Error : Boolean := False;
      begin
         Is_Clause := False;
         Valid := True;
         Skip_Trivia (Position);
         Read_Identifier (Position, Token, Present);
         if not Present or else To_String (Token) /= "default_switches" then
            return;
         end if;

         Is_Clause := True;
         Skip_Trivia (Position);
         if Position > Raw_Content'Last
           or else Raw_Content (Position) /= '('
         then
            Valid := False;
            return;
         end if;
         Position := Position + 1;
         Skip_Trivia (Position);
         Read_String (Position, Token, Present);
         if not Present
           or else Ada.Characters.Handling.To_Lower (To_String (Token)) /= "ada"
         then
            --  A Default_Switches clause for another language is irrelevant.
            Is_Clause := False;
            return;
         end if;
         Skip_Trivia (Position);
         if Position > Raw_Content'Last
           or else Raw_Content (Position) /= ')'
         then
            Valid := False;
            return;
         end if;
         Position := Position + 1;
         Skip_Trivia (Position);
         Read_Identifier (Position, Token, Present);
         if not Present or else To_String (Token) /= "use" then
            Valid := False;
            return;
         end if;

         Skip_Trivia (Position);
         if Position > Raw_Content'Last
           or else Raw_Content (Position) /= '('
         then
            Valid := False;
            return;
         end if;
         Position := Position + 1;

         loop
            Skip_Trivia (Position);
            if Position > Raw_Content'Last then
               Valid := False;
               return;
            elsif Raw_Content (Position) = ')' then
               Position := Position + 1;
            elsif Raw_Content (Position) = '"' then
               Read_String (Position, Token, Present);
               if not Present then
                  Valid := False;
                  return;
               end if;
               declare
                  Switch : constant String :=
                    Ada.Characters.Handling.To_Lower (To_String (Token));
               begin
                  Has_Error := Has_Error or else Switch = "-gnatwe";
                  Reject_Error := Reject_Error
                    or else Switch in "-gnatws" | "-gnatw-";
               end;
            else
               Valid := False;
               return;
            end if;

            Skip_Trivia (Position);
            if Position > Raw_Content'Last then
               Valid := False;
               return;
            elsif Raw_Content (Position) = ',' then
               Position := Position + 1;
            elsif Raw_Content (Position) = ')' then
               Position := Position + 1;
               Skip_Trivia (Position);
               if Position > Raw_Content'Last
                 or else Raw_Content (Position) /= ';'
               then
                  Valid := False;
                  return;
               end if;
               Position := Position + 1;
               Valid := Has_Error and then not Reject_Error;
               return;
            else
               --  Concatenation, conditionals, variables, and other complex
               --  expressions cannot prove that -gnatwe is a list element.
               Valid := False;
               return;
            end if;
         end loop;
      end Check_Clause;
   begin
      while Cursor <= Raw_Content'Last loop
         Skip_Trivia (Cursor);
         exit when Cursor > Raw_Content'Last;
         if Raw_Content (Cursor) = '"' then
            declare
               Ignored : Unbounded_String;
               Present : Boolean;
            begin
               Read_String (Cursor, Ignored, Present);
               if not Present then
                  return False;
               end if;
            end;
         elsif Raw_Content (Cursor) in 'a' .. 'z' | 'A' .. 'Z' | '_' then
            declare
               Token   : Unbounded_String;
               Present : Boolean;
            begin
               Read_Identifier (Cursor, Token, Present);
               if Present and then To_String (Token) = "for" then
                  declare
                     Is_Clause : Boolean;
                     Valid     : Boolean;
                  begin
                     Check_Clause (Cursor, Is_Clause, Valid);
                     if Is_Clause then
                        Found_Clause := True;
                        if not Valid then
                           return False;
                        end if;
                     end if;
                  end;
               end if;
            end;
         else
            Cursor := Cursor + 1;
         end if;
      end loop;
      return Found_Clause;
   end Rejects_Warnings;

   procedure Check_Project (Relative_Path : String) is
   begin
      if Relative_Path'Length >= 4
        and then Relative_Path (Relative_Path'Last - 3 .. Relative_Path'Last) =
          ".gpr"
      then
         declare
            Path : constant String :=
              Project_Tools.Files.Join (Tooling_Support.Root, Relative_Path);
         begin
            if not Rejects_Warnings
              (Project_Tools.Files.Read_Raw_File (Path))
            then
               Tooling_Checks.Fail
                 (Relative_Path
                  & " must reject compiler warnings in its Ada Default_Switches");
            end if;
         end;
      end if;
   end Check_Project;

   procedure Check_Packaged_Projects is new Package_Entries (Check_Project);

   procedure Self_Test is separate;

   procedure Run is
   begin
      Check_Packaged_Projects;
   end Run;
end Metadata_Checks.Warning_Policy;
