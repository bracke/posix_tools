with Posix_Tools.Text.Decimal_Parsing;

package body Posix_Tools.Text.Find_Expressions
  with SPARK_Mode => On
is
   function Age_Matches
     (Age : Duration;
      Low : Duration;
      High : Duration;
      Relation : Count_Relation) return Boolean is
   begin
      case Relation is
         when Exact_Count =>
            return Age >= Low and then Age < High;
         when Greater_Than_Count =>
            return Age >= Low;
         when Less_Than_Count =>
            return Age < High;
      end case;
   end Age_Matches;

   function Count_Matches
     (Actual : Long_Long_Integer;
      Expected : Long_Long_Integer;
      Relation : Count_Relation) return Boolean is
   begin
      case Relation is
         when Exact_Count =>
            return Actual = Expected;
         when Greater_Than_Count =>
            return Actual > Expected;
         when Less_Than_Count =>
            return Actual < Expected;
      end case;
   end Count_Matches;

   function Is_Expression_Start (Arg : String) return Boolean is
   begin
      return Arg = "!"
        or else Arg = "("
        or else Arg = ")"
        or else Arg = "-a"
        or else Arg = "-o"
        or else Arg = "-depth"
        or else Arg = "-exec"
        or else Arg = "-name"
        or else Arg = "-ok"
        or else Arg = "-mtime"
        or else Arg = "-newer"
        or else Arg = "-path"
        or else Arg = "-perm"
        or else Arg = "-prune"
        or else Arg = "-size"
        or else Arg = "-type"
        or else Arg = "-user"
        or else Arg = "-group"
        or else Arg = "-nouser"
        or else Arg = "-nogroup"
        or else Arg = "-xdev"
        or else Arg = "-print"
        or else (Arg'Length > 1 and then Arg (Arg'First) = '-');
   end Is_Expression_Start;

   function Missing_Owner_Name_Matches
     (Available : Boolean;
      Name : String) return Boolean is
   begin
      return Available and then Name = "";
   end Missing_Owner_Name_Matches;

   function Ownership_Matches
     (Available : Boolean;
      Select_User : Boolean;
      Actual_User : Natural;
      Actual_Group : Natural;
      Expected : Natural) return Boolean is
   begin
      return Available
        and then
          (if Select_User then Actual_User = Expected
           else Actual_Group = Expected);
   end Ownership_Matches;

   function Parse_Find_Count (Text : String) return Parsed_Find_Count is
   begin
      if Text = "" then
         return
           (Valid => False,
            Count => 0,
            Relation => Exact_Count,
            Bytes => False);
      end if;

      declare
         First    : Positive := Text'First;
         Last     : Natural := Text'Last;
         Relation : Count_Relation := Exact_Count;
         Bytes    : Boolean := False;
      begin
         if Text (First) = '+' then
            Relation := Greater_Than_Count;
            if First = Last then
               return
                  (Valid => False,
                   Count => 0,
                   Relation => Relation,
                   Bytes => False);
            end if;
            First := First + 1;
         elsif Text (First) = '-' then
            Relation := Less_Than_Count;
            if First = Last then
               return
                  (Valid => False,
                   Count => 0,
                   Relation => Relation,
                   Bytes => False);
            end if;
            First := First + 1;
         end if;

         if Last >= First and then Text (Last) = 'c' then
            Bytes := True;
            Last := Last - 1;
         end if;

         if First > Last then
            return
              (Valid => False,
               Count => 0,
               Relation => Relation,
               Bytes => Bytes);
         end if;

         declare
            Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Long_Long :=
              Posix_Tools.Text.Decimal_Parsing.Long_Long_Value
                (Text (First .. Last));
         begin
            if Text (First) = '+'
              or else Text (First) = '-'
              or else not Parsed.Valid
              or else Parsed.Value < 0
            then
               return
                 (Valid => False,
                  Count => 0,
                  Relation => Relation,
                  Bytes => Bytes);
            else
               return
                 (Valid => True,
                  Count => Parsed.Value,
                  Relation => Relation,
                  Bytes => Bytes);
            end if;
         end;
      end;
   end Parse_Find_Count;

   function Parse_Type_Filter (Text : String) return Parsed_Type_Filter is
   begin
      if Text = "d" then
         return (Valid => True, Filter => Directory_Type);
      elsif Text = "f" then
         return (Valid => True, Filter => Regular_File_Type);
      elsif Text = "l" then
         return (Valid => True, Filter => Symbolic_Link_Type);
      elsif Text = "b" then
         return (Valid => True, Filter => Block_Device_Type);
      elsif Text = "c" then
         return (Valid => True, Filter => Character_Device_Type);
      elsif Text = "p" then
         return (Valid => True, Filter => FIFO_Type);
      elsif Text = "s" then
         return (Valid => True, Filter => Socket_Type);
      else
         return (Valid => False, Filter => Any_Type);
      end if;
   end Parse_Type_Filter;

   function Type_Matches
     (Filter : Find_Type_Filter;
      Exists : Boolean;
      Is_Directory : Boolean;
      Is_Regular : Boolean;
      Is_Link : Boolean;
      Special_Available : Boolean;
      Special_Class : Find_Special_File_Class) return Boolean is
   begin
      case Filter is
         when Any_Type =>
            return True;
         when Directory_Type =>
            return Exists and then Is_Directory;
         when Regular_File_Type =>
            return Exists and then Is_Regular;
         when Symbolic_Link_Type =>
            return Is_Link;
         when Block_Device_Type =>
            return Exists
              and then Special_Available
              and then Special_Class = Block_Device_File;
         when Character_Device_Type =>
            return Exists
              and then Special_Available
              and then Special_Class = Character_Device_File;
         when FIFO_Type =>
            return Exists
              and then Special_Available
              and then Special_Class = FIFO_File;
         when Socket_Type =>
            return Exists
              and then Special_Available
              and then Special_Class = Socket_File;
      end case;
   end Type_Matches;
end Posix_Tools.Text.Find_Expressions;
