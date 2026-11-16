with Ada.Characters.Handling;
with Project_Tools.Ada_Source;
with Tooling_Checks;

package body Metadata_Checks.Silent_Handlers is
   function Line_Start
     (Content     : String;
      Line_Number : Positive) return Natural
   is
      Current : Positive := 1;
   begin
      if Line_Number = 1 then
         return Content'First;
      end if;

      for Index in Content'Range loop
         if Content (Index) = Character'Val (10) then
            Current := Current + 1;
            if Current = Line_Number then
               return Index + 1;
            end if;
         end if;
      end loop;
      return 0;
   end Line_Start;

   Barrier_Directive : constant String :=
     "--  intentional terminal exception barrier";

   function Inspect
     (Content     : String;
      Line_Number : Positive) return Handler_Info
   is
      Cursor      : Natural := Line_Start (Content, Line_Number);
      Result      : Handler_Info;
      In_String   : Boolean := False;
      Begin_Depth : Natural := 0;

      procedure Skip_Trivia is
      begin
         loop
            while Cursor <= Content'Last
              and then Content (Cursor) in ' ' | Character'Val (9)
                | Character'Val (10) | Character'Val (13)
            loop
               Cursor := Cursor + 1;
            end loop;

            exit when Cursor >= Content'Last
              or else Content (Cursor .. Cursor + 1) /= "--";

            declare
               First : constant Natural := Cursor;
            begin
               while Cursor <= Content'Last
                 and then Content (Cursor) /= Character'Val (10)
               loop
                  Cursor := Cursor + 1;
               end loop;
               if Ada.Characters.Handling.To_Lower
                 (Content (First .. Cursor - 1)) = Barrier_Directive
               then
                  Result.Intentional := True;
               end if;
            end;
         end loop;
      end Skip_Trivia;

      function At_Keyword (Keyword : String) return Boolean is
         After : constant Natural := Cursor + Keyword'Length;
      begin
         return Cursor <= Content'Last
           and then Keyword'Length <= Content'Last - Cursor + 1
           and then Ada.Characters.Handling.To_Lower
             (Content (Cursor .. After - 1)) = Keyword
           and then
             (After > Content'Last
              or else not Project_Tools.Ada_Source.Is_Identifier_Character
                (Content (After)));
      end At_Keyword;

      function At_Ignorable_Pragma return Boolean is
         Scan : Natural := Cursor + 6;

         function Name_Is (Name : String) return Boolean is
            After : constant Natural := Scan + Name'Length;
         begin
            return Scan <= Content'Last
              and then Name'Length <= Content'Last - Scan + 1
              and then Ada.Characters.Handling.To_Lower
                (Content (Scan .. After - 1)) = Name
              and then
                (After > Content'Last
                 or else not Project_Tools.Ada_Source.Is_Identifier_Character
                   (Content (After)));
         end Name_Is;
      begin
         while Scan <= Content'Last
           and then Content (Scan) in ' ' | Character'Val (9)
             | Character'Val (10) | Character'Val (13)
         loop
            Scan := Scan + 1;
         end loop;
         return Name_Is ("warnings") or else Name_Is ("unreferenced");
      end At_Ignorable_Pragma;

      procedure Skip_Pragma is
         In_Pragma_String : Boolean := False;
      begin
         while Cursor <= Content'Last loop
            if Content (Cursor) = '"' then
               if In_Pragma_String
                 and then Cursor < Content'Last
                 and then Content (Cursor + 1) = '"'
               then
                  Cursor := Cursor + 2;
               else
                  In_Pragma_String := not In_Pragma_String;
                  Cursor := Cursor + 1;
               end if;
            elsif not In_Pragma_String and then Content (Cursor) = ';' then
               Cursor := Cursor + 1;
               return;
            else
               Cursor := Cursor + 1;
            end if;
         end loop;
      end Skip_Pragma;

      procedure Skip_Label is
      begin
         Cursor := Cursor + 2;
         while Cursor < Content'Last
           and then Content (Cursor .. Cursor + 1) /= ">>"
         loop
            Cursor := Cursor + 1;
         end loop;
         if Cursor < Content'Last then
            Cursor := Cursor + 2;
         end if;
      end Skip_Label;

      --  A block statement may have a statement identifier (Name : declare
      --  ... end Name;). Leave Cursor at the block keyword when one is
      --  present; an ordinary identifier-led statement is not a wrapper.
      function Skip_Block_Statement_Identifier return Boolean is
         Saved : constant Natural := Cursor;
         Scan  : Natural := Cursor;
      begin
         if Scan > Content'Last
           or else Content (Scan) not in 'a' .. 'z' | 'A' .. 'Z'
         then
            return False;
         end if;
         while Scan <= Content'Last
           and then Project_Tools.Ada_Source.Is_Identifier_Character
             (Content (Scan))
         loop
            Scan := Scan + 1;
         end loop;
         Cursor := Scan;
         Skip_Trivia;
         Scan := Cursor;
         if Scan > Content'Last
           or else Content (Scan) /= ':'
           or else
             (Scan < Content'Last and then Content (Scan + 1) = '=')
         then
            Cursor := Saved;
            return False;
         end if;

         Cursor := Scan + 1;
         Skip_Trivia;
         if At_Keyword ("begin") or else At_Keyword ("declare") then
            return True;
         end if;
         Cursor := Saved;
         return False;
      end Skip_Block_Statement_Identifier;

      function Skip_Declare_Part return Boolean is
         In_Declaration_String : Boolean := False;
         Saw_Declaration       : Boolean := False;
         Saw_Assignment        : Boolean := False;
         Saw_Safe_Literal      : Boolean := False;
         Effectful_Initializer : Boolean := False;

         procedure Note_Static_Literal is
         begin
            if not Saw_Assignment or else Saw_Safe_Literal then
               Effectful_Initializer := True;
            else
               Saw_Safe_Literal := True;
            end if;
         end Note_Static_Literal;

         procedure Skip_Numeral is
            procedure Skip_Decimal_Digits is
            begin
               while Cursor <= Content'Last
                 and then Content (Cursor) in '0' .. '9' | '_'
               loop
                  Cursor := Cursor + 1;
               end loop;
            end Skip_Decimal_Digits;

            procedure Skip_Exponent is
            begin
               if Cursor <= Content'Last
                 and then Content (Cursor) in 'e' | 'E'
               then
                  Cursor := Cursor + 1;
                  if Cursor <= Content'Last
                    and then Content (Cursor) in '+' | '-'
                  then
                     Cursor := Cursor + 1;
                  end if;
                  Skip_Decimal_Digits;
               end if;
            end Skip_Exponent;
         begin
            Skip_Decimal_Digits;
            if Cursor <= Content'Last and then Content (Cursor) = '#' then
               Cursor := Cursor + 1;
               while Cursor <= Content'Last
                 and then Content (Cursor) /= '#'
                 and then
                   (Project_Tools.Ada_Source.Is_Identifier_Character
                      (Content (Cursor))
                    or else Content (Cursor) = '.')
               loop
                  Cursor := Cursor + 1;
               end loop;
               if Cursor <= Content'Last and then Content (Cursor) = '#' then
                  Cursor := Cursor + 1;
               end if;
               Skip_Exponent;
            else
               if Cursor < Content'Last
                 and then Content (Cursor) = '.'
                 and then Content (Cursor + 1) in '0' .. '9'
               then
                  Cursor := Cursor + 1;
                  Skip_Decimal_Digits;
               end if;
               Skip_Exponent;
            end if;
         end Skip_Numeral;

         procedure Note_Identifier (Identifier : String) is
            Lower : constant String :=
              Ada.Characters.Handling.To_Lower (Identifier);
         begin
            Saw_Declaration := True;
            if not Saw_Assignment
              and then Lower in "range" | "digits" | "delta"
            then
               --  Constraint expressions are elaborated before the
               --  initializer and may call parameterless functions.
               Effectful_Initializer := True;
            elsif Saw_Assignment then
               if Lower in "true" | "false" | "null"
                 and then not Saw_Safe_Literal
               then
                  Saw_Safe_Literal := True;
               else
                  --  Any other identifier may denote a function,
                  --  object, overloaded operator operand, or literal
                  --  with user-defined initialization semantics.
                  Effectful_Initializer := True;
               end if;
            end if;
         end Note_Identifier;
      begin
         Cursor := Cursor + 7;
         loop
            Skip_Trivia;
            if Cursor > Content'Last then
               return False;
            elsif At_Keyword ("begin") then
               if Saw_Declaration then
                  return False;
               end if;
               Cursor := Cursor + 5;
               Begin_Depth := Begin_Depth + 1;
               return True;
            elsif At_Keyword ("procedure")
              or else At_Keyword ("function")
              or else At_Keyword ("package")
              or else At_Keyword ("task")
              or else At_Keyword ("protected")
              or else At_Keyword ("generic")
            then
               --  A nested program unit can contain its own begin;
               --  leave complex declarative parts to a real parser.
               return False;
            elsif At_Keyword ("pragma") and then At_Ignorable_Pragma then
               Skip_Pragma;
            elsif At_Keyword ("pragma") then
               return False;
            elsif Content (Cursor) = '"' then
               if Saw_Assignment then
                  Note_Static_Literal;
               end if;
               In_Declaration_String := True;
               Cursor := Cursor + 1;
               while Cursor <= Content'Last and then In_Declaration_String loop
                  if Content (Cursor) = '"' then
                     if Cursor < Content'Last
                       and then Content (Cursor + 1) = '"'
                     then
                        Cursor := Cursor + 2;
                     else
                        In_Declaration_String := False;
                        Cursor := Cursor + 1;
                     end if;
                  else
                     Cursor := Cursor + 1;
                  end if;
               end loop;
            elsif Content (Cursor) = Character'Val (39)
              and then Cursor + 3 <= Content'Last
              and then Content (Cursor + 1) = Character'Val (39)
              and then Content (Cursor + 2) = Character'Val (39)
              and then Content (Cursor + 3) = Character'Val (39)
            then
               Note_Static_Literal;
               Cursor := Cursor + 4;
            elsif Content (Cursor) = Character'Val (39)
              and then Cursor + 2 <= Content'Last
              and then Content (Cursor + 2) = Character'Val (39)
            then
               Note_Static_Literal;
               Cursor := Cursor + 3;
            elsif Content (Cursor) in '0' .. '9' then
               Note_Static_Literal;
               Skip_Numeral;
            elsif Project_Tools.Ada_Source.Is_Identifier_Character
              (Content (Cursor))
            then
               declare
                  First : constant Positive := Cursor;
               begin
                  while Cursor <= Content'Last
                    and then Project_Tools.Ada_Source.Is_Identifier_Character
                      (Content (Cursor))
                  loop
                     Cursor := Cursor + 1;
                  end loop;
                  Note_Identifier (Content (First .. Cursor - 1));
               end;
            elsif Cursor < Content'Last
              and then Content (Cursor .. Cursor + 1) = ":="
            then
               Saw_Assignment := True;
               Cursor := Cursor + 2;
            elsif Content (Cursor) = ';' then
               if not Effectful_Initializer
                 and then (not Saw_Declaration
                 or else
                   (Saw_Assignment and then not Saw_Safe_Literal))
               then
                  return False;
               end if;
               Saw_Declaration := False;
               Saw_Assignment := False;
               Saw_Safe_Literal := False;
               Effectful_Initializer := False;
               Cursor := Cursor + 1;
            else
               declare
                  Lookahead : Natural := Cursor + 1;
               begin
                  while Lookahead <= Content'Last
                    and then Content (Lookahead) in ' ' | Character'Val (9)
                  loop
                     Lookahead := Lookahead + 1;
                  end loop;
                  if Saw_Assignment
                    and then not Saw_Safe_Literal
                    and then Content (Cursor) in '+' | '-'
                    and then Lookahead <= Content'Last
                    and then Content (Lookahead) in '0' .. '9'
                  then
                     null;
                  elsif Saw_Assignment
                 or else Content (Cursor) in '(' | ')'
                  then
                     Effectful_Initializer := True;
                  end if;
               end;
               Cursor := Cursor + 1;
            end if;
         end loop;
      end Skip_Declare_Part;

   begin
      if Cursor = 0 then
         return Result;
      end if;

      --  Find the handler arrow as Ada code, ignoring arrows in
      --  comments and string literals on a continued choice line.
      while Cursor < Content'Last loop
         if not In_String
           and then Content (Cursor .. Cursor + 1) = "--"
         then
            while Cursor <= Content'Last
              and then Content (Cursor) /= Character'Val (10)
            loop
               Cursor := Cursor + 1;
            end loop;
         elsif Content (Cursor) = '"' then
            if In_String
              and then Cursor < Content'Last
              and then Content (Cursor + 1) = '"'
            then
               Cursor := Cursor + 2;
            else
               In_String := not In_String;
               Cursor := Cursor + 1;
            end if;
         elsif not In_String
           and then Content (Cursor .. Cursor + 1) = "=>"
         then
            exit;
         else
            Cursor := Cursor + 1;
         end if;
      end loop;
      if Cursor >= Content'Last then
         return Result;
      end if;
      Cursor := Cursor + 2;
      Skip_Trivia;

      --  Ignore structural wrappers around the handler's first
      --  effective statement. Labels and declarative pragmas must not
      --  turn a swallowed exception into an apparent action.
      loop
         if Skip_Block_Statement_Identifier then
            null;
         elsif At_Keyword ("begin") then
            Begin_Depth := Begin_Depth + 1;
            Cursor := Cursor + 5;
            Skip_Trivia;
         elsif At_Keyword ("declare") then
            if not Skip_Declare_Part then
               --  Declarative elaboration is not evidence that the caught
               --  exception was handled.  In particular, a bare identifier
               --  may be either an enum literal or a parameterless call, so
               --  the lexical checker must fail closed.
               Result.Is_Indeterminate := True;
               return Result;
            end if;
            Skip_Trivia;
         elsif Cursor < Content'Last
           and then Content (Cursor .. Cursor + 1) = "<<"
         then
            Skip_Label;
            Skip_Trivia;
         elsif At_Keyword ("pragma") and then At_Ignorable_Pragma then
            Skip_Pragma;
            Skip_Trivia;
         else
            exit;
         end if;
      end loop;

      --  Control transfers whose destination is outside the handler cannot
      --  establish recovery lexically.  Return is classified with null below;
      --  loop transfers and goto require the explicit barrier directive.
      if At_Keyword ("exit")
        or else At_Keyword ("continue")
        or else At_Keyword ("goto")
      then
         Result.Is_Indeterminate := True;
         return Result;
      end if;

      --  A compound or tasking statement can contain an action on only some
      --  paths, or no effective action at all.  Deciding that requires an Ada
      --  statement parser and control-flow analysis; this lexical gate must
      --  therefore fail closed instead of treating an unrecognised reserved
      --  word as evidence that the exception was handled.
      if Cursor <= Content'Last
        and then Content (Cursor) in 'a' .. 'z' | 'A' .. 'Z'
      then
         declare
            Stop : Natural := Cursor;
         begin
            while Stop <= Content'Last
              and then Project_Tools.Ada_Source.Is_Identifier_Character
                (Content (Stop))
            loop
               Stop := Stop + 1;
            end loop;
            if Project_Tools.Ada_Source.Is_Ada_Reserved_Word
              (Content (Cursor .. Stop - 1))
              and then not At_Keyword ("null")
              and then not At_Keyword ("return")
              and then not At_Keyword ("raise")
            then
               Result.Is_Indeterminate := True;
               return Result;
            end if;
         end;
      end if;

      --  An assignment can merely hide the exception in local state (for
      --  example, Ignored := True).  Without a re-raise, diagnostic, recovery
      --  call, or the explicit barrier directive its intent cannot be
      --  established lexically, so classify it as indeterminate instead of
      --  accepting every identifier-led statement.
      declare
         Scan           : Natural := Cursor;
         Saw_Assignment : Boolean := False;
         In_Literal     : Boolean := False;
         May_Be_Assignment : Boolean := False;

      begin
         if Scan <= Content'Last
           and then Content (Scan) in 'a' .. 'z' | 'A' .. 'Z'
         then
            declare
               First : constant Natural := Scan;
            begin
               while Scan <= Content'Last
                 and then Project_Tools.Ada_Source.Is_Identifier_Character
                   (Content (Scan))
               loop
                  Scan := Scan + 1;
               end loop;
               May_Be_Assignment :=
                 Ada.Characters.Handling.To_Lower
                   (Content (First .. Scan - 1))
                 not in "for" | "if" | "case" | "loop" | "while"
                   | "begin" | "declare";
               Scan := Cursor;
            end;
         end if;
         while May_Be_Assignment and then Scan <= Content'Last loop
            if not In_Literal
              and then Scan < Content'Last
              and then Content (Scan .. Scan + 1) = "--"
            then
               while Scan <= Content'Last
                 and then Content (Scan) /= Character'Val (10)
               loop
                  Scan := Scan + 1;
               end loop;
            elsif Content (Scan) = '"' then
               if In_Literal and then Scan < Content'Last
                 and then Content (Scan + 1) = '"'
               then
                  Scan := Scan + 2;
               else
                  In_Literal := not In_Literal;
                  Scan := Scan + 1;
               end if;
            elsif not In_Literal and then Scan < Content'Last
              and then Content (Scan .. Scan + 1) = ":="
            then
               Saw_Assignment := True;
               Scan := Scan + 2;
            elsif not In_Literal and then Content (Scan) = ';' then
               Scan := Scan + 1;
               exit;
            else
               Scan := Scan + 1;
            end if;
         end loop;
         if Saw_Assignment then
            --  An assignment may communicate recovery through an out
            --  parameter, or may only hide the failure in local state.  A
            --  lexical checker cannot distinguish the two reliably, and a
            --  following inert statement must not turn the assignment into
            --  evidence of handling.  Require the explicit barrier marker.
            Result.Is_Indeterminate := True;
            return Result;
         end if;
      end;

      declare
         Keyword_Length : Natural := 0;
      begin
         if Cursor + 3 <= Content'Last
           and then Ada.Characters.Handling.To_Lower
             (Content (Cursor .. Cursor + 3)) = "null"
           and then
             (Cursor + 4 > Content'Last
              or else not Project_Tools.Ada_Source.Is_Identifier_Character
                (Content (Cursor + 4)))
         then
            Keyword_Length := 4;
         elsif Cursor + 5 <= Content'Last
           and then Ada.Characters.Handling.To_Lower
             (Content (Cursor .. Cursor + 5)) = "return"
           and then
             (Cursor + 6 > Content'Last
              or else not Project_Tools.Ada_Source.Is_Identifier_Character
                (Content (Cursor + 6)))
         then
            Keyword_Length := 6;
         else
            return Result;
         end if;
         Cursor := Cursor + Keyword_Length;
      end;
      Skip_Trivia;
      if Cursor > Content'Last or else Content (Cursor) /= ';' then
         return Result;
      end if;
      Cursor := Cursor + 1;
      Skip_Trivia;

      while Begin_Depth > 0 loop
         if not At_Keyword ("end") then
            Result.Is_Indeterminate := True;
            return Result;
         end if;
         Cursor := Cursor + 3;
         Skip_Trivia;
         if Cursor <= Content'Last
           and then Content (Cursor) in 'a' .. 'z' | 'A' .. 'Z'
         then
            while Cursor <= Content'Last
              and then Project_Tools.Ada_Source.Is_Identifier_Character
                (Content (Cursor))
            loop
               Cursor := Cursor + 1;
            end loop;
            Skip_Trivia;
         end if;
         if Cursor > Content'Last or else Content (Cursor) /= ';' then
            Result.Is_Indeterminate := True;
            return Result;
         end if;
         Cursor := Cursor + 1;
         Begin_Depth := Begin_Depth - 1;
         Skip_Trivia;
      end loop;

      --  A null before another handler statement is not a silent
      --  handler. At EOF, "when", or the handled sequence's "end",
      --  the swallowed exception has no remaining action.
      Result.Is_Silent :=
        Cursor > Content'Last
        or else At_Keyword ("when")
        or else At_Keyword ("end");
      return Result;
   end Inspect;

   procedure Self_Test is separate;
end Metadata_Checks.Silent_Handlers;
