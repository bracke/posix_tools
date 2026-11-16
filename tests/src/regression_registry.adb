with Ada.Containers.Vectors;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Posix_Tools.Text.Line_Breaks;
with Project_Tools.Files;
with Test_Taxonomy;
with Tooling_Checks;
with Tooling_Support;

package body Regression_Registry is
   use Ada.Strings.Unbounded;

   type Row is record
      Line_Number : Positive;
      Id           : Unbounded_String;
      Command      : Unbounded_String;
      Summary      : Unbounded_String;
      Tests        : Unbounded_String;
   end record;

   package Row_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Row);

   function Trimmed (Text : String) return String is
     (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));

   function Is_Valid_Id (Text : String) return Boolean is
      Prefix      : constant String := "REG-";
      Last_Hyphen : Natural := 0;
      Previous_Was_Hyphen : Boolean := False;
   begin
      if Text'Length < Prefix'Length + 6
        or else Text (Text'First .. Text'First + Prefix'Length - 1) /= Prefix
      then
         return False;
      end if;
      for Index in Text'First + Prefix'Length .. Text'Last loop
         if Text (Index) = '-' then
            if Index = Text'First + Prefix'Length
              or else Previous_Was_Hyphen
            then
               return False;
            end if;
            Last_Hyphen := Index;
            Previous_Was_Hyphen := True;
         elsif Text (Index) not in 'A' .. 'Z' | '0' .. '9' then
            return False;
         else
            Previous_Was_Hyphen := False;
         end if;
      end loop;
      return Last_Hyphen > 0
        and then Text'Last - Last_Hyphen = 4
        and then
          (for all Index in Last_Hyphen + 1 .. Text'Last =>
             Text (Index) in '0' .. '9');
   end Is_Valid_Id;

   function Field (Line : String; Number : Positive) return String is
      First   : Positive := Line'First;
      Current : Positive := 1;
   begin
      for Index in Line'Range loop
         if Line (Index) = ',' then
            if Current = Number then
               return Line (First .. Index - 1);
            end if;
            Current := Current + 1;
            First := Index + 1;
         end if;
      end loop;
      return
        (if Current = Number then Line (First .. Line'Last) else "");
   end Field;

   function Count_Fields (Line : String) return Natural is
      Result : Natural := (if Line = "" then 0 else 1);
   begin
      for Character_Of_Line of Line loop
         if Character_Of_Line = ',' then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Count_Fields;

   procedure Parse_Content
     (Content : String;
      Parsed  : in out Row_Vectors.Vector;
      Error   : out Unbounded_String)
   is
      First       : Positive := Content'First;
      Line_Number : Positive := 1;
      Saw_Header  : Boolean := False;

      procedure Reject (Message : String) is
      begin
         if Length (Error) = 0 then
            Error := To_Unbounded_String (Message);
         end if;
      end Reject;

      procedure Add_Line (Raw_Line : String) is
         Line : constant String :=
           (if Raw_Line = ""
            then ""
            else
              Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                (Raw_Line));
      begin
         if Line_Number = 1 then
            Saw_Header := True;
            if Line /= "id,command,summary,test" then
               Reject ("regression registry header is invalid");
            end if;
         elsif Line /= "" and then Length (Error) = 0 then
            if Count_Fields (Line) /= 4 then
               Reject
                 ("regression row has wrong field count at line"
                  & Positive'Image (Line_Number));
            else
               declare
                  Id             : constant String := Field (Line, 1);
                  Command        : constant String := Field (Line, 2);
                  Summary        : constant String := Field (Line, 3);
                  Tests          : constant String := Field (Line, 4);
                  Test_Count     : Natural;
                  Has_Empty_Test : Boolean;

                  procedure Ignore (Reference : String) is
                     pragma Unreferenced (Reference);
                  begin
                     null;
                  end Ignore;
               begin
                  For_Each_Test_Reference
                    (Tests, Ignore'Access, Test_Count, Has_Empty_Test);
                  if not Is_Valid_Id (Id) then
                     Reject
                       ("invalid regression identifier " & Id & " at line"
                        & Positive'Image (Line_Number));
                  elsif Trimmed (Command) = "" then
                     Reject (Id & " has empty command field");
                  elsif Trimmed (Summary) = "" then
                     Reject (Id & " has empty summary field");
                  elsif Test_Count = 0 or else Has_Empty_Test then
                     Reject (Id & " has invalid or empty test references");
                  elsif
                    (for some Item of Parsed => To_String (Item.Id) = Id)
                  then
                     Reject ("duplicate regression identifier " & Id);
                  elsif Natural (Parsed.Length) = 256 then
                     Reject
                       ("regression registry exceeds tooling row capacity");
                  else
                     Parsed.Append
                       (Row'
                          (Line_Number => Line_Number,
                           Id           => To_Unbounded_String (Id),
                           Command      => To_Unbounded_String (Command),
                           Summary      => To_Unbounded_String (Summary),
                           Tests        => To_Unbounded_String (Tests)));
                  end if;
               end;
            end if;
         end if;
      end Add_Line;
   begin
      Parsed.Clear;
      Error := Null_Unbounded_String;
      for Index in Content'Range loop
         exit when Length (Error) > 0;
         if Content (Index) = Character'Val (10) then
            Add_Line
              ((if Index = First
                then ""
                else Content (First .. Index - 1)));
            First := Index + 1;
            Line_Number := Line_Number + 1;
         end if;
      end loop;
      if Length (Error) = 0 and then First <= Content'Last then
         Add_Line (Content (First .. Content'Last));
      end if;
      if Length (Error) = 0 and then not Saw_Header then
         Reject ("regression registry header is invalid");
      elsif Length (Error) = 0 and then Parsed.Is_Empty then
         Reject ("regression registry is empty");
      end if;
   end Parse_Content;

   function Read_Validated return Row_Vectors.Vector is
      Content : constant String :=
        Project_Tools.Files.Read_Raw_File
          (Project_Tools.Files.Join
             (Tooling_Support.Root, "generated/regressions.csv"));
      Parsed : Row_Vectors.Vector;
      Error  : Unbounded_String;
   begin
      Parse_Content (Content, Parsed, Error);
      if Length (Error) > 0 then
         Tooling_Checks.Fail (To_String (Error));
      end if;
      return Parsed;
   end Read_Validated;

   procedure For_Each_Row
     (Visit : not null access procedure
        (Line_Number : Positive;
         Id           : String;
         Command      : String;
         Summary      : String;
         Tests        : String)) is
      Parsed : constant Row_Vectors.Vector := Read_Validated;
   begin
      for Item of Parsed loop
         Visit
           (Item.Line_Number,
            To_String (Item.Id),
            To_String (Item.Command),
            To_String (Item.Summary),
            To_String (Item.Tests));
      end loop;
   end For_Each_Row;

   procedure For_Each_Test_Reference
     (References : String;
      Visit      : not null access procedure (Reference : String);
      Count      : out Natural;
      Has_Empty  : out Boolean)
   is
      First : Positive := References'First;

      procedure Visit_Trimmed (Text : String) is
         Item : constant String :=
           Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
      begin
         if Item = "" then
            Has_Empty := True;
         else
            Count := Count + 1;
            Visit (Item);
         end if;
      end Visit_Trimmed;
   begin
      Count := 0;
      Has_Empty := False;
      for Index in References'Range loop
         if References (Index) = ';' then
            if First < Index then
               Visit_Trimmed (References (First .. Index - 1));
            else
               Visit_Trimmed ("");
            end if;
            First := Index + 1;
         end if;
      end loop;
      if First <= References'Last then
         Visit_Trimmed (References (First .. References'Last));
      else
         Visit_Trimmed ("");
      end if;
   end For_Each_Test_Reference;

   function Is_AUnit_Reference (Reference : String) return Boolean is
     (Test_Taxonomy.Is_AUnit_Name (Reference));

   function Is_Aliasable_AUnit_Reference
     (Reference : String) return Boolean is
     (Test_Taxonomy.Is_Aliasable_AUnit_Name (Reference));

   procedure Self_Test is separate;
end Regression_Registry;
