with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Rg.Diagnostics;
with Posix_Tools.Commands.Rg.Globs;
with Posix_Tools.Commands.Rg.Patterns;
with Posix_Tools.Commands.Rg.Rendering;
with Posix_Tools.Commands.Rg.Search;
with Posix_Tools.Commands.Rg.Types;
private with Ada.Calendar;
private with Ada.Containers.Vectors;
private with Ada.Strings.Unbounded;

--  Sequential recursive discovery with lazy, directory-scoped ignore rules.
package Posix_Tools.Commands.Rg.Traversal is
   type Sort_Order is
     (Unsorted,
      Path_Ascending,
      Path_Descending,
      Modified_Ascending,
      Modified_Descending,
      Accessed_Ascending,
      Accessed_Descending,
      Created_Ascending,
      Created_Descending);

   function Is_Metadata_Sort (Order : Sort_Order) return Boolean;

   function Effective_Worker_Count
     (Threads : Natural;
      Sort    : Sort_Order) return Positive;

   type Discovery_Options is record
      Include_Hidden : Boolean := False;
      Use_Ignore     : Boolean := True;
      Use_Vcs_Ignore : Boolean := True;
      Use_Parent_Ignore : Boolean := True;
      Follow_Links   : Boolean := False;
      One_File_System : Boolean := False;
      Max_Depth      : Natural := Natural'Last;
      Max_File_Size  : Long_Long_Integer := Long_Long_Integer'Last;
      Prefix_Dot     : Boolean := False;
      Null_Pathnames : Boolean := False;
      Sort           : Sort_Order := Unsorted;
      Glob_Policy    : Posix_Tools.Commands.Rg.Globs.Policy;
      Type_Policy    : Posix_Tools.Commands.Rg.Types.Policy;
      Style          : Posix_Tools.Commands.Rg.Rendering.Format;
      Diagnostics    : Posix_Tools.Commands.Rg.Diagnostics.Log_Level :=
        Posix_Tools.Commands.Rg.Diagnostics.Logging_Off;
   end record;

   type Traversal_Options is record
      Include_Hidden : Boolean := False;
      Use_Ignore     : Boolean := True;
      Use_Vcs_Ignore : Boolean := True;
      Use_Parent_Ignore : Boolean := True;
      Follow_Links   : Boolean := False;
      One_File_System : Boolean := False;
      Max_Depth      : Natural := Natural'Last;
      Max_File_Size  : Long_Long_Integer := Long_Long_Integer'Last;
      Prefix_Dot     : Boolean := False;
      Null_Pathnames : Boolean := False;
      Sort           : Sort_Order := Unsorted;
      Threads        : Natural := 0;
      Glob_Policy    : Posix_Tools.Commands.Rg.Globs.Policy;
      Type_Policy    : Posix_Tools.Commands.Rg.Types.Policy;
      Search         : Posix_Tools.Commands.Rg.Search.Execution_Options;
      Diagnostics    : Posix_Tools.Commands.Rg.Diagnostics.Log_Level :=
        Posix_Tools.Commands.Rg.Diagnostics.Logging_Off;
   end record;

   type Traversal_Outcome is record
      Had_Match    : Boolean := False;
      Had_Result   : Boolean := False;
      Stop_All     : Boolean := False;
      Input_Error  : Boolean := False;
      Match_Error  : Boolean := False;
      Output_Error : Boolean := False;
      Match_Count   : Natural := 0;
      Matched_Lines : Natural := 0;
      Files_With_Matches : Natural := 0;
      Files_Searched : Natural := 0;
      Bytes_Searched : Natural := 0;
      Bytes_Printed  : Natural := 0;
      Search_Time    : Duration := 0.0;
   end record;

   type File_Set is private;

   procedure Add_File
     (Context        : in out Posix_Tools.Commands.Contexts.Context'Class;
      Files          : in out File_Set;
      Name           : String;
      Label          : String;
      Standard_Input : Boolean;
      Outcome        : in out Traversal_Outcome;
      Recursive      : Boolean := False);

   procedure Collect_Tree
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Root    : String;
      Options : Discovery_Options;
      Files   : in out File_Set;
      Outcome : out Traversal_Outcome);

   procedure Sort_Files
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Files   : in out File_Set;
      Order   : Sort_Order;
      Outcome : in out Traversal_Outcome);

   function File_Count (Files : File_Set) return Natural;
   function Files_Ready (Files : File_Set) return Boolean;
   function File_Name (Files : File_Set; Index : Positive) return String
     with Pre => Index <= File_Count (Files);
   function File_Label (Files : File_Set; Index : Positive) return String
     with Pre => Index <= File_Count (Files);

   procedure Search_Tree
     (Context  : in out Posix_Tools.Commands.Contexts.Context'Class;
      Root     : String;
      Patterns : Posix_Tools.Commands.Rg.Patterns.Compiled_Pattern_Array;
      Options  : Traversal_Options;
      Outcome  : out Traversal_Outcome);

   procedure Search_Files
     (Context  : in out Posix_Tools.Commands.Contexts.Context'Class;
      Files    : File_Set;
      Patterns : Posix_Tools.Commands.Rg.Patterns.Compiled_Pattern_Array;
      Options  : Traversal_Options;
      Outcome  : out Traversal_Outcome);

   procedure List_Tree
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Root    : String;
      Options : Discovery_Options;
      Outcome : out Traversal_Outcome);
private
   type File_Record is record
      Name           : Ada.Strings.Unbounded.Unbounded_String;
      Label          : Ada.Strings.Unbounded.Unbounded_String;
      Standard_Input : Boolean := False;
      Recursive      : Boolean := False;
      Key             : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Key_Available   : Boolean := False;
      Sequence        : Natural := 0;
   end record;

   package File_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => File_Record);

   type File_Set is record
      Items  : File_Vectors.Vector;
      Bytes  : Natural := 0;
      Failed : Boolean := False;
   end record;
end Posix_Tools.Commands.Rg.Traversal;
