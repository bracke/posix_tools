package body Metadata_Checks.Ada_Lexing is
   function Code_View
     (Content                : String;
      Keep_String_Delimiters : Boolean := True) return String
   is
      LF         : constant Character := Character'Val (10);
      Quote      : constant Character := Character'Val (39);
      Result     : String (Content'Range) := [others => ' '];
      Index      : Natural := Content'First;
      In_String  : Boolean := False;
      In_Comment : Boolean := False;
   begin
      while Index <= Content'Last loop
         if In_Comment then
            if Content (Index) = LF then
               Result (Index) := LF;
               In_Comment := False;
            end if;
            Index := Index + 1;
         elsif In_String then
            if Content (Index) = '"' then
               if Index < Content'Last and then Content (Index + 1) = '"' then
                  Index := Index + 2;
               else
                  if Keep_String_Delimiters then
                     Result (Index) := '"';
                  end if;
                  In_String := False;
                  Index := Index + 1;
               end if;
            elsif Content (Index) = LF then
               --  Preserve line positions even for malformed source so the
               --  validator can still produce useful locations.
               Result (Index) := LF;
               Index := Index + 1;
            else
               Index := Index + 1;
            end if;
         elsif Content (Index) = Quote
           and then Index + 3 <= Content'Last
           and then Content (Index .. Index + 3) = String'(1 .. 4 => Quote)
         then
            Result (Index .. Index + 3) := Content (Index .. Index + 3);
            Index := Index + 4;
         elsif Content (Index) = Quote
           and then Index + 2 <= Content'Last
           and then Content (Index + 2) = Quote
         then
            --  Keep a character literal as code, especially the valid Ada
            --  literal '"', whose middle quote is not a string delimiter.
            Result (Index .. Index + 2) := Content (Index .. Index + 2);
            Index := Index + 3;
         elsif Index < Content'Last
           and then Content (Index .. Index + 1) = "--"
         then
            In_Comment := True;
            Index := Index + 2;
         elsif Content (Index) = '"' then
            if Keep_String_Delimiters then
               Result (Index) := '"';
            end if;
            In_String := True;
            Index := Index + 1;
         else
            Result (Index) := Content (Index);
            Index := Index + 1;
         end if;
      end loop;
      return Result;
   end Code_View;
end Metadata_Checks.Ada_Lexing;
