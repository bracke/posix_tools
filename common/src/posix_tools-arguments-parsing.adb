package body Posix_Tools.Arguments.Parsing is
   function Contains (Text : String; Ch : Character) return Boolean is
   begin
      for Item of Text loop
         if Item = Ch then
            return True;
         end if;
      end loop;

      return False;
   end Contains;

   function Advance_To_Next (Position : Cursor) return Cursor is
   begin
      return (Index => Position.Index + 1, Offset => 2);
   end Advance_To_Next;

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
         Current : constant String := Arguments.Element (Position.Index);
      begin
         if Current = "--" and then Position.Offset = 2 then
            return
              (Status => End_Of_Options,
               Next   => Advance_To_Next (Position),
               Name   => Character'Val (0),
               Text   => Null_Unbounded_String);
         elsif Current'Length < 2 or else Current (Current'First) /= '-' or else Current = "-" then
            return
              (Status => Operand,
               Next   => Advance_To_Next (Position),
               Name   => Character'Val (0),
               Text   => To_Unbounded_String (Current));
         elsif Position.Offset > Current'Length then
            return Parse_Short (Arguments, Advance_To_Next (Position), Accepted, Requires_Argument);
         end if;

         declare
            Ch : constant Character := Current (Position.Offset);
         begin
            if not Contains (Accepted, Ch) then
               return
                 (Status => Unknown_Option,
                  Next   => Advance_To_Next (Position),
                  Name   => Ch,
                  Text   => Null_Unbounded_String);
            elsif Contains (Requires_Argument, Ch) then
               if Position.Offset < Current'Length then
                  return
                    (Status => Option,
                     Next   => Advance_To_Next (Position),
                     Name   => Ch,
                     Text   => To_Unbounded_String (Current (Position.Offset + 1 .. Current'Last)));
               elsif Position.Index < Count then
                  return
                    (Status => Option,
                     Next   => (Index => Position.Index + 2, Offset => 2),
                     Name   => Ch,
                     Text   => To_Unbounded_String (Arguments.Element (Position.Index + 1)));
               else
                  return
                    (Status => Missing_Argument,
                     Next   => Advance_To_Next (Position),
                     Name   => Ch,
                     Text   => Null_Unbounded_String);
               end if;
            else
               return
                 (Status => Option,
                  Next   =>
                    (if Position.Offset < Current'Length then
                        (Index => Position.Index, Offset => Position.Offset + 1)
                     else
                        Advance_To_Next (Position)),
                  Name   => Ch,
                  Text   => Null_Unbounded_String);
            end if;
         end;
      end;
   end Parse_Short;
end Posix_Tools.Arguments.Parsing;
