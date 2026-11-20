private with Ada.Containers.Vectors;
private with Ada.Strings.Unbounded;

--  Ordered ripgrep glob overrides using Version.Ignore's raw wildcard matcher.
package Posix_Tools.Commands.Rg.Globs is
   type Decision is record
      Has_Match   : Boolean := False;
      Is_Included : Boolean := True;
   end record;

   type Policy is private;

   procedure Add (Self : in out Policy; Source : String);

   function Is_Empty (Self : Policy) return Boolean;

   function Evaluate
     (Self          : Policy;
      Relative_Path : String;
      Is_Directory  : Boolean) return Decision;

   --  Files with no matching rule are selected only when the policy has no
   --  positive rule. Directories remain candidates so descendants can match.
   function Selects_Unmatched_File (Self : Policy) return Boolean;

private
   type Rule is record
      Pattern        : Ada.Strings.Unbounded.Unbounded_String;
      Include        : Boolean := True;
      Directory_Only : Boolean := False;
      Has_Slash      : Boolean := False;
   end record;

   package Rule_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Rule);

   type Policy is record
      Rules        : Rule_Vectors.Vector;
      Has_Includes : Boolean := False;
   end record;
end Posix_Tools.Commands.Rg.Globs;
