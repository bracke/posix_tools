with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Host_Adapters.File_System;

package Posix_Tools.Commands.Find_Evaluation is
   type Evaluation_State is private;

   --  The file a primary examines for one pathname: the symbolic link itself
   --  where the link is not followed (Kind is then Missing_File), otherwise
   --  the file the pathname resolves to.
   type Entry_View is record
      Is_Link : Boolean := False;
      Kind    : Posix_Tools.Host_Adapters.File_System.File_Kind :=
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

   type Evaluation_State is record
      Expression   : Posix_Tools.Arguments.Vector;
      Exec_Batches : Find_Exec_Batch_Vectors.Vector;
      --  The bytes one batched invocation may pass in arguments.
      Batch_Limit  : Natural := 0;
      --  A batch sent during the walk, to stay within the limit, failed.
      Batch_Failed : Boolean := False;
      Depth        : Boolean := False;
      Xdev         : Boolean := False;
   end record;
end Posix_Tools.Commands.Find_Evaluation;
