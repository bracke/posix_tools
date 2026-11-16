--  Validation of compiler-warning policy in packaged GPR projects.
package Metadata_Checks.Warning_Policy is
   procedure Run;
private
   function Rejects_Warnings (Raw_Content : String) return Boolean;
   procedure Self_Test;
end Metadata_Checks.Warning_Policy;
