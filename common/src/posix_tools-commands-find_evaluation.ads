with Ada.Calendar;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Posix_Tools.Accounts;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Find_Expressions;

package Posix_Tools.Commands.Find_Evaluation is
   type Evaluation_State is private;

   --  The file a primary examines for one pathname: the symbolic link itself
   --  where the link is not followed (Kind is then Missing_File), otherwise
   --  the file the pathname resolves to.
   type Entry_View is record
      Is_Link       : Boolean := False;
      --  The pathname is a link, but this view examines its resolved target.
      --  Status lookup must follow it in that case.
      Followed_Link : Boolean := False;
      Kind          : Posix_Tools.Host_Adapters.File_System.File_Kind :=
        Posix_Tools.Host_Adapters.File_System.Missing_File;
   end record;

   type Path_Result is record
      Matches : Boolean := False;
      Valid   : Boolean := True;
      Pruned  : Boolean := False;
   end record;

   --  Environment_Size is the bytes the environment takes in a new process;
   --  batched -exec invocations keep their arguments within what is left.
   procedure Initialize
     (State            : out Evaluation_State;
      Context          : Posix_Tools.Commands.Contexts.Host_Context'Class;
      Expression       : Posix_Tools.Arguments.Vector;
      Environment_Size : Natural);

   function Has_Depth (State : Evaluation_State) return Boolean;
   function Has_Xdev (State : Evaluation_State) return Boolean;

   procedure Evaluate_Path
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Path    : String;
      View    : Entry_View;
      Result  : out Path_Result);

   --  Queue one pathname for standard output. Output is emitted in bounded
   --  blocks; Flush_Output preserves ordering before external commands and
   --  at the end of the walk.
   procedure Print_Path
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Path    : String);

   procedure Flush_Output
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class);

   --  The index of the argument that ends the -exec or -ok whose utility name
   --  is at Utility_Index, or 0 when none does. A ';' always ends it; with
   --  Allow_Batch, so does a '+' that immediately follows an argument that is
   --  exactly "{}" (XCU find, -exec).
   function Exec_Terminator
     (Expression    : Posix_Tools.Arguments.Vector;
      Utility_Index : Positive;
      Allow_Batch   : Boolean) return Natural;

   procedure Flush_Exec_Batches
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Ok      : in out Boolean);

   --  The -mtime or -size operand Text, as Find_Expressions parses it;
   --  False when it is not one.
   function Parse_Find_Count
     (Text     : String;
      Count    : out Long_Long_Integer;
      Relation : out Posix_Tools.Text.Find_Expressions.Count_Relation;
      Bytes    : out Boolean) return Boolean;

   --  The -perm operand Text, as File_Modes parses it; False when it is
   --  not one.
   function Parse_Permission_Mode
     (Text      : String;
      Mode      : out Natural;
      Match_All : out Boolean) return Boolean;

private
   type Find_Exec_Batch is record
      Start_Index : Positive := 1;
      Utility     : Ada.Strings.Unbounded.Unbounded_String;
      Prefix      : Posix_Tools.Arguments.Vector;
      Paths       : Posix_Tools.Arguments.Vector;
      --  The argument bytes Utility, Prefix and Paths take together.
      Size        : Natural := 0;
   end record;

   package Find_Exec_Batch_Vectors is new Ada.Containers.Vectors (Positive, Find_Exec_Batch);

   type Compiled_Operand is record
      Count          : Long_Long_Integer := 0;
      Relation       : Posix_Tools.Text.Find_Expressions.Count_Relation :=
        Posix_Tools.Text.Find_Expressions.Exact_Count;
      Bytes          : Boolean := False;
      Count_Valid    : Boolean := False;
      Permission     : Natural := 0;
      Match_All      : Boolean := False;
      Permission_Valid : Boolean := False;
      Type_Filter    : Posix_Tools.Text.Find_Expressions.Find_Type_Filter :=
        Posix_Tools.Text.Find_Expressions.Any_Type;
      Type_Valid     : Boolean := False;
      Reference_Time : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Reference_Valid : Boolean := False;
      Identity       : Posix_Tools.Accounts.Id := 0;
      Identity_Found : Boolean := False;
   end record;

   package Compiled_Operand_Vectors is new Ada.Containers.Vectors
     (Positive, Compiled_Operand);

   type Evaluation_State is record
      Expression   : Posix_Tools.Arguments.Vector;
      Compiled     : Compiled_Operand_Vectors.Vector;
      Exec_Batches : Find_Exec_Batch_Vectors.Vector;
      --  The bytes one batched invocation may pass in arguments.
      Batch_Limit  : Natural := 0;
      --  A batch sent during the walk, to stay within the limit, failed.
      Batch_Failed : Boolean := False;
      Output_Buffer : Posix_Tools.Commands.Helpers.Output_Buffer;
      Depth        : Boolean := False;
      Xdev         : Boolean := False;
      --  When find began: -mtime ages are counted back from it.
      Started      : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
   end record;
end Posix_Tools.Commands.Find_Evaluation;
