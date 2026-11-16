--  Bounded subprocess execution for E2E bootstrap and destructive checks.
package E2E_Processes is
   type Group_Policy is
     (New_Process_Group, Inherit_Process_Group);

   --  Run Program with one Argument.  Raise Program_Error when it cannot be
   --  started, does not finish by Timeout_Ms, or is ended abnormally.
   function Run
     (Program    : String;
      Argument   : String;
      Timeout_Ms : Positive;
      Group      : Group_Policy := New_Process_Group) return Integer;
end E2E_Processes;
