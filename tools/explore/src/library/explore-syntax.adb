with Ada.Characters.Handling;

package body Explore.Syntax is
   type Word is access constant String;

   type Word_List is array (Positive range <>) of Word;

   function W (Text : String) return Word is (new String'(Text));

   Ada_Words : constant Word_List :=
     [W ("abort"), W ("abs"), W ("abstract"), W ("accept"), W ("access"), W ("aliased"), W ("all"), W ("and"),
      W ("array"), W ("at"), W ("begin"), W ("body"), W ("case"), W ("constant"), W ("declare"), W ("delay"),
      W ("delta"), W ("digits"), W ("do"), W ("else"), W ("elsif"), W ("end"), W ("entry"), W ("exception"),
      W ("exit"), W ("for"), W ("function"), W ("generic"), W ("goto"), W ("if"), W ("in"), W ("interface"),
      W ("is"), W ("limited"), W ("loop"), W ("mod"), W ("new"), W ("not"), W ("null"), W ("of"), W ("or"),
      W ("others"), W ("out"), W ("overriding"), W ("package"), W ("pragma"), W ("private"), W ("procedure"),
      W ("protected"), W ("raise"), W ("range"), W ("record"), W ("rem"), W ("renames"), W ("requeue"),
      W ("return"), W ("reverse"), W ("select"), W ("separate"), W ("some"), W ("subtype"), W ("synchronized"),
      W ("tagged"), W ("task"), W ("terminate"), W ("then"), W ("type"), W ("until"), W ("use"), W ("when"),
      W ("while"), W ("with"), W ("xor")];

   C_Words : constant Word_List :=
     [W ("auto"), W ("break"), W ("case"), W ("catch"), W ("char"), W ("class"), W ("const"), W ("continue"),
      W ("default"), W ("do"), W ("double"), W ("else"), W ("enum"), W ("export"), W ("extends"), W ("extern"),
      W ("false"), W ("final"), W ("float"), W ("fn"), W ("for"), W ("func"), W ("function"), W ("go"),
      W ("goto"), W ("if"), W ("impl"), W ("import"), W ("int"), W ("interface"), W ("let"), W ("long"),
      W ("match"), W ("mut"), W ("namespace"), W ("new"), W ("null"), W ("package"), W ("private"),
      W ("protected"), W ("pub"), W ("public"), W ("return"), W ("short"), W ("signed"), W ("sizeof"),
      W ("static"), W ("struct"), W ("switch"), W ("template"), W ("this"), W ("throw"), W ("trait"),
      W ("true"), W ("try"), W ("type"), W ("typedef"), W ("union"), W ("unsigned"), W ("use"), W ("var"),
      W ("void"), W ("volatile"), W ("while")];

   Hash_Words : constant Word_List :=
     [W ("and"), W ("as"), W ("break"), W ("case"), W ("class"), W ("continue"), W ("def"), W ("do"),
      W ("done"), W ("elif"), W ("else"), W ("esac"), W ("except"), W ("export"), W ("false"), W ("fi"),
      W ("for"), W ("from"), W ("function"), W ("if"), W ("import"), W ("in"), W ("is"), W ("lambda"),
      W ("local"), W ("not"), W ("or"), W ("pass"), W ("raise"), W ("return"), W ("then"), W ("true"),
      W ("try"), W ("until"), W ("while"), W ("with"), W ("yield"), W ("None"), W ("True"), W ("False")];

   JSON_Words : constant Word_List := [W ("true"), W ("false"), W ("null")];

   No_Words : constant Word_List (1 .. 0) := [others => null];

   function Words_Of (Of_Language : Language) return Word_List is
     (case Of_Language is
        when Ada_Language => Ada_Words,
        when C_Family => C_Words,
        when Hash_Commented => Hash_Words,
        when JSON_Language => JSON_Words,
        when No_Language | Markdown_Language => No_Words);

   function Is_Word_Character (C : Character) return Boolean is
     (C in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_');

   function Language_Of (Name, First_Line : String) return Language is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Name);

      function Ends (Suffix : String) return Boolean is
        (Lower'Length > Suffix'Length and then Lower (Lower'Last - Suffix'Length + 1 .. Lower'Last) = Suffix);
   begin
      if Ends (".adb") or else Ends (".ads") or else Ends (".gpr") then
         return Ada_Language;
      elsif Ends (".c") or else Ends (".h") or else Ends (".cc") or else Ends (".cpp") or else Ends (".hpp")
        or else Ends (".java") or else Ends (".js") or else Ends (".ts") or else Ends (".rs") or else Ends (".go")
        or else Ends (".cs") or else Ends (".swift") or else Ends (".kt")
      then
         return C_Family;
      elsif Ends (".py") or else Ends (".sh") or else Ends (".bash") or else Ends (".toml") or else Ends (".yaml")
        or else Ends (".yml") or else Ends (".rb") or else Ends (".pl") or else Ends (".conf")
        or else Lower = "makefile" or else Lower = "dockerfile"
        or else (First_Line'Length > 2 and then First_Line (First_Line'First .. First_Line'First + 1) = "#!")
      then
         return Hash_Commented;
      elsif Ends (".json") then
         return JSON_Language;
      elsif Ends (".md") or else Ends (".markdown") then
         return Markdown_Language;
      else
         return No_Language;
      end if;
   end Language_Of;

   procedure Tokenize
     (Line        : String;
      Of_Language : Language;
      State       : in out Line_State;
      Spans       : out Span_Vectors.Vector)
   is
      I : Natural := Line'First;

      procedure Add (First, Last : Natural; Kind : Token_Kind);

      procedure Add (First, Last : Natural; Kind : Token_Kind) is
      begin
         if Last < First then
            return;
         end if;

         --  A comment's opening and its body join into one run.
         if not Spans.Is_Empty and then Spans.Last_Element.Kind = Kind and then Spans.Last_Element.Last + 1 = First then
            Spans (Spans.Last_Index).Last := Last;
         else
            Spans.Append (Span'(First, Last, Kind));
         end if;
      end Add;

      function Starts (At_Index : Natural; Text : String) return Boolean is
        (At_Index + Text'Length - 1 <= Line'Last
         and then Line (At_Index .. At_Index + Text'Length - 1) = Text);

      function Line_Comment return String is
        (case Of_Language is
           when Ada_Language => "--",
           when C_Family => "//",
           when Hash_Commented => "#",
           when others => "");
   begin
      Spans.Clear;

      if Of_Language = No_Language then
         return;
      end if;

      if Of_Language = Markdown_Language then
         if Line'Length > 0 and then Line (Line'First) = '#' then
            Add (Line'First, Line'Last, Heading);
         end if;

         return;
      end if;

      while I <= Line'Last loop
         if State.In_Block_Comment then
            declare
               Start : constant Natural := I;
            begin
               while I <= Line'Last and then not Starts (I, "*/") loop
                  I := I + 1;
               end loop;

               if I <= Line'Last then
                  I := I + 2;
                  State.In_Block_Comment := False;
               end if;

               Add (Start, Natural'Min (I - 1, Line'Last), Comment);
            end;
         elsif Line_Comment'Length > 0 and then Starts (I, Line_Comment) then
            Add (I, Line'Last, Comment);
            return;
         elsif Of_Language = C_Family and then Starts (I, "/*") then
            State.In_Block_Comment := True;
            I := I + 2;
            Add (I - 2, I - 1, Comment);
         elsif Line (I) = '"' or else (Line (I) = ''' and then Of_Language in C_Family | Hash_Commented) then
            declare
               Quote : constant Character := Line (I);
               Start : constant Natural := I;
            begin
               I := I + 1;

               while I <= Line'Last and then Line (I) /= Quote loop
                  --  A backslash takes the next character with it, except in Ada.
                  if Line (I) = '\' and then Of_Language /= Ada_Language then
                     I := I + 1;
                  end if;

                  I := I + 1;
               end loop;

               I := Natural'Min (I, Line'Last) + 1;
               Add (Start, I - 1, String_Literal);
            end;
         elsif Line (I) in '0' .. '9' and then (I = Line'First or else not Is_Word_Character (Line (I - 1))) then
            declare
               Start : constant Natural := I;
            begin
               while I <= Line'Last and then (Is_Word_Character (Line (I)) or else Line (I) in '.' | '#') loop
                  I := I + 1;
               end loop;

               Add (Start, I - 1, Number);
            end;
         elsif Is_Word_Character (Line (I)) then
            declare
               Start : constant Natural := I;
            begin
               while I <= Line'Last and then Is_Word_Character (Line (I)) loop
                  I := I + 1;
               end loop;

               declare
                  Word  : constant String := Line (Start .. I - 1);
                  Lower : constant String :=
                    (if Of_Language = Ada_Language then Ada.Characters.Handling.To_Lower (Word) else Word);
               begin
                  for Candidate of Words_Of (Of_Language) loop
                     if Candidate.all = Lower then
                        Add (Start, I - 1, Keyword);
                        exit;
                     end if;
                  end loop;
               end;
            end;
         else
            I := I + 1;
         end if;
      end loop;
   end Tokenize;
end Explore.Syntax;
