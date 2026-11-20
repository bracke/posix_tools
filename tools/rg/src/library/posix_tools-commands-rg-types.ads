with Posix_Tools.Commands.Contexts;
private with Posix_Tools.Arguments;

--  Pinned ripgrep 15.2.0 file-type catalog and selection policy.
package Posix_Tools.Commands.Rg.Types is
   type Policy is private;

   function Include_Type (Self : in out Policy; Name : String) return Boolean;
   function Exclude_Type (Self : in out Policy; Name : String) return Boolean;

   function Selects (Self : Policy; Path : String) return Boolean;

   procedure Put_List
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class);

private
   type Policy is record
      Included : Posix_Tools.Arguments.Vector;
      Excluded : Posix_Tools.Arguments.Vector;
   end record;
end Posix_Tools.Commands.Rg.Types;
