with Posix_Tools.Commands.Contexts;

package Posix_Tools.Commands.Find_Evaluation.Actions is
   function Execute_Exec
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Path    : String;
      Index   : in out Positive;
      Active  : Boolean;
      Valid   : in out Boolean) return Boolean;

   function Execute_Ok
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Path    : String;
      Index   : in out Positive;
      Active  : Boolean;
      Valid   : in out Boolean) return Boolean;

   procedure Flush_Exec_Batches
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Ok      : in out Boolean);
end Posix_Tools.Commands.Find_Evaluation.Actions;
