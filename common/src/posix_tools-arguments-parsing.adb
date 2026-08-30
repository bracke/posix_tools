with Posix_Tools.Option_Parsing;

package body Posix_Tools.Arguments.Parsing
  with SPARK_Mode => Off
is
   function Parse_Short
     (Arguments         : Posix_Tools.Arguments.Vector;
      Position          : Cursor;
      Accepted          : String;
      Requires_Argument : String := "") return Result
   is
      use Ada.Strings.Unbounded;
      Count : constant Natural := Natural (Arguments.Length);
   begin
      if Position.Index > Count then
         return (Status => Done, Next => Position, Name => Character'Val (0), Text => Null_Unbounded_String);
      end if;

      declare
         Current  : constant String := Arguments.Element (Position.Index);
         Decision : constant Posix_Tools.Option_Parsing.Decision :=
           Posix_Tools.Option_Parsing.Decide_Short
             (Current,
              (Index => Position.Index, Offset => Position.Offset),
              Count,
              Accepted,
              Requires_Argument);
         Next     : constant Cursor :=
           (Index => Positive (Decision.Next.Index), Offset => Positive (Decision.Next.Offset));
      begin
         case Decision.Status is
            when Posix_Tools.Option_Parsing.Done =>
               return Parse_Short (Arguments, Next, Accepted, Requires_Argument);
            when Posix_Tools.Option_Parsing.Option =>
               return
                 (Status => Option,
                  Next   => Next,
                  Name   => Decision.Name,
                  Text   =>
                    (case Decision.Source is
                       when Posix_Tools.Option_Parsing.Inline_Remainder =>
                         To_Unbounded_String (Current (Decision.Inline_First .. Current'Last)),
                       when Posix_Tools.Option_Parsing.Following_Argument =>
                         To_Unbounded_String (Arguments.Element (Position.Index + 1)),
                       when others =>
                         Null_Unbounded_String));
            when Posix_Tools.Option_Parsing.Operand =>
               return
                 (Status => Operand,
                  Next   => Next,
                  Name   => Character'Val (0),
                  Text   => To_Unbounded_String (Current));
            when Posix_Tools.Option_Parsing.End_Of_Options =>
               return
                 (Status => End_Of_Options,
                  Next   => Next,
                  Name   => Character'Val (0),
                  Text   => Null_Unbounded_String);
            when Posix_Tools.Option_Parsing.Unknown_Option =>
               return
                 (Status => Unknown_Option,
                  Next   => Next,
                  Name   => Decision.Name,
                  Text   => Null_Unbounded_String);
            when Posix_Tools.Option_Parsing.Missing_Argument =>
               return
                 (Status => Missing_Argument,
                  Next   => Next,
                  Name   => Decision.Name,
                  Text   => Null_Unbounded_String);
         end case;
      end;
   end Parse_Short;
end Posix_Tools.Arguments.Parsing;
