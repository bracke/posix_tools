with Ada.Containers.Vectors;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers.Tr_Sets;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Text_Helpers.Collation;
with Posix_Tools.Streams.Bytes;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Cut_Fields;
with Posix_Tools.Text.UTF_8;

package body Posix_Tools.Commands.Cut is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Text.Cut_Fields.Range_Item;
   use type Posix_Tools.Text.UTF_8.Decode_Status;

   package Range_Vectors is new Ada.Containers.Vectors
     (Positive, Posix_Tools.Text.Cut_Fields.Range_Item);

   --  The number of bytes of the UTF-8 character starting at Index; an
   --  invalid or truncated sequence counts as a one-byte character.
   function Character_Width (Text : String; Index : Positive) return Positive;

   function Parse_List (Text : String; Ranges : in out Range_Vectors.Vector) return Boolean;
   procedure Normalize (Ranges : in out Range_Vectors.Vector);

   function Character_Width (Text : String; Index : Positive) return Positive is
      Decoder    : Posix_Tools.Text.UTF_8.Decoder;
      Status     : Posix_Tools.Text.UTF_8.Decode_Status;
      Code_Point : Long_Long_Integer;
   begin
      for I in Index .. Text'Last loop
         Posix_Tools.Text.UTF_8.Decode (Decoder, Character'Pos (Text (I)), Status, Code_Point);
         if Status = Posix_Tools.Text.UTF_8.Complete then
            return I - Index + 1;
         elsif Status = Posix_Tools.Text.UTF_8.Invalid then
            return 1;
         end if;
      end loop;
      return 1;
   end Character_Width;

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
      Normalize (Ranges);
      return True;
   end Parse_List;

   procedure Normalize (Ranges : in out Range_Vectors.Vector) is
      Merged : Range_Vectors.Vector;

      function Before
        (Left, Right : Posix_Tools.Text.Cut_Fields.Range_Item) return Boolean is
        (Left.First < Right.First
         or else (Left.First = Right.First
           and then Right.Last /= 0
           and then (Left.Last = 0 or else Left.Last < Right.Last)));

      package Sorting is new Range_Vectors.Generic_Sorting (Before);
   begin
      Sorting.Sort (Ranges);

      for Item of Ranges loop
         if Merged.Is_Empty then
            Merged.Append (Item);
         else
            declare
               Previous : Posix_Tools.Text.Cut_Fields.Range_Item := Merged.Last_Element;
               Touches  : constant Boolean :=
                 Previous.Last = 0
                 or else Item.First <= Previous.Last
                 or else (Previous.Last < Natural'Last
                   and then Item.First = Previous.Last + 1);
            begin
               if Touches then
                  if Previous.Last /= 0 then
                     Previous.Last :=
                       (if Item.Last = 0 then 0 else Natural'Max (Previous.Last, Item.Last));
                     Merged.Replace_Element (Merged.Last_Index, Previous);
                  end if;
               else
                  Merged.Append (Item);
               end if;
            end;
         end if;
      end loop;
      Ranges.Move (Merged);
   end Normalize;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result) is separate;

end Posix_Tools.Commands.Cut;
