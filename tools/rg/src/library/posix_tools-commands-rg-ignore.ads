with Version.Ignore;
private with Ada.Strings.Unbounded;

--  Ripgrep ignore-source precedence over Version.Ignore's reusable parser.
package Posix_Tools.Commands.Rg.Ignore is
   type Load_Outcome is record
      Sources_Loaded : Natural := 0;
      Rules_Added    : Natural := 0;
      Had_Error      : Boolean := False;
   end record;

   type Decision is record
      Is_Ignored : Boolean := False;
      Match      : Version.Ignore.Match_Result;
   end record;

   type Policy is limited private;

   procedure Initialize
     (Self             : in out Policy;
      Root             : String;
      Case_Insensitive : Boolean := False;
      Use_Gitignore    : Boolean := True;
      Use_Ignore       : Boolean := True;
      Use_Rgignore     : Boolean := True;
      Use_Parent       : Boolean := True);

   --  Add ignore files from Directory before evaluating its children.
   procedure Enter_Directory
     (Self               : in out Policy;
      Directory          : String;
      Relative_Directory : String;
      Outcome            : out Load_Outcome);

   function Evaluate
     (Self          : Policy;
      Relative_Path : String;
      Is_Directory  : Boolean) return Decision;

private
   type Policy is limited record
      Builder        : Version.Ignore.Rule_Set_Builder;
      Rules          : Version.Ignore.Ignore_Rules;
      Gitignore      : Boolean := True;
      Ignore_File    : Boolean := True;
      Rgignore       : Boolean := True;
      Query_Prefix   : Ada.Strings.Unbounded.Unbounded_String;
      Initial_Load   : Load_Outcome;
      Is_Initialized : Boolean := False;
   end record;
end Posix_Tools.Commands.Rg.Ignore;
