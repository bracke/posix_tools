package Posix_Tools.Text.Find_Expressions
  with SPARK_Mode => On
is
   type Count_Relation is (Exact_Count, Greater_Than_Count, Less_Than_Count);
   type Find_Type_Filter is
     (Any_Type,
      Directory_Type,
      Regular_File_Type,
      Symbolic_Link_Type,
      Block_Device_Type,
      Character_Device_Type,
      FIFO_Type,
      Socket_Type);

   type Parsed_Type_Filter is record
      Valid  : Boolean := False;
      Filter : Find_Type_Filter := Any_Type;
   end record;

   type Parsed_Find_Count is record
      Valid    : Boolean := False;
      Count    : Long_Long_Integer := 0;
      Relation : Count_Relation := Exact_Count;
      Bytes    : Boolean := False;
   end record;

   type Find_Special_File_Class is
     (No_Special_File,
      Block_Device_File,
      Character_Device_File,
      FIFO_File,
      Socket_File);

   function Is_Expression_Start (Arg : String) return Boolean
     with Post =>
       Is_Expression_Start'Result =
         (Arg = "!" or else Arg = "(" or else Arg = ")"
          or else Arg = "-a" or else Arg = "-o"
          or else Arg = "-depth" or else Arg = "-exec"
          or else Arg = "-name" or else Arg = "-ok"
          or else Arg = "-mtime" or else Arg = "-newer"
          or else Arg = "-path" or else Arg = "-perm"
          or else Arg = "-prune" or else Arg = "-size"
          or else Arg = "-type" or else Arg = "-user"
          or else Arg = "-group" or else Arg = "-nouser"
          or else Arg = "-nogroup" or else Arg = "-xdev"
          or else Arg = "-print"
          or else (Arg'Length > 1 and then Arg (Arg'First) = '-'));

   function Count_Matches
     (Actual : Long_Long_Integer;
      Expected : Long_Long_Integer;
      Relation : Count_Relation) return Boolean
     with Post =>
       Count_Matches'Result =
         (case Relation is
            when Exact_Count => Actual = Expected,
            when Greater_Than_Count => Actual > Expected,
            when Less_Than_Count => Actual < Expected);

   function Age_Matches
     (Age : Duration;
      Low : Duration;
      High : Duration;
      Relation : Count_Relation) return Boolean
     with Post =>
       Age_Matches'Result =
         (case Relation is
            when Exact_Count => Age >= Low and then Age < High,
            when Greater_Than_Count => Age >= Low,
            when Less_Than_Count => Age < High);

   function Ownership_Matches
     (Available : Boolean;
      Select_User : Boolean;
      Actual_User : Natural;
      Actual_Group : Natural;
      Expected : Natural) return Boolean
     with Post =>
       Ownership_Matches'Result =
         (Available
          and then
            (if Select_User then Actual_User = Expected
             else Actual_Group = Expected));

   function Missing_Owner_Name_Matches
     (Available : Boolean;
      Name : String) return Boolean
     with Post =>
       Missing_Owner_Name_Matches'Result = (Available and then Name = "");

   function Parse_Type_Filter (Text : String) return Parsed_Type_Filter
     with Post =>
       (if Parse_Type_Filter'Result.Valid then
          Parse_Type_Filter'Result.Filter /= Any_Type
        else
          Parse_Type_Filter'Result.Filter = Any_Type);

   function Parse_Find_Count (Text : String) return Parsed_Find_Count
     with Post =>
       (if Parse_Find_Count'Result.Valid then
          Parse_Find_Count'Result.Count >= 0
        else
          Parse_Find_Count'Result.Count = 0);

   function Type_Matches
     (Filter : Find_Type_Filter;
      Exists : Boolean;
      Is_Directory : Boolean;
      Is_Regular : Boolean;
      Is_Link : Boolean;
      Special_Available : Boolean;
      Special_Class : Find_Special_File_Class) return Boolean
     with Post =>
       Type_Matches'Result =
         (case Filter is
            when Any_Type => True,
            when Directory_Type => Exists and then Is_Directory,
            when Regular_File_Type => Exists and then Is_Regular,
            when Symbolic_Link_Type => Is_Link,
            when Block_Device_Type =>
              Exists
              and then Special_Available
              and then Special_Class = Block_Device_File,
            when Character_Device_Type =>
              Exists
              and then Special_Available
              and then Special_Class = Character_Device_File,
            when FIFO_Type =>
              Exists
              and then Special_Available
              and then Special_Class = FIFO_File,
            when Socket_Type =>
              Exists
              and then Special_Available
              and then Special_Class = Socket_File);
end Posix_Tools.Text.Find_Expressions;
