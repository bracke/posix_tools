with Ada.Directories;

--  The fixture paths the surface tests share, under the fixtures directory.
package Command_Tests.Surface_Smoke.Fixtures is
   --  Helpers.Fixture_Path, here as an expression so the constants below
   --  need no package body elaborated before them.
   function Fixture_File (Name : String) return String is
     ((if Ada.Directories.Exists ("fixtures") then "fixtures/" else "../fixtures/") & Name);

   Source  : constant String := Fixture_File ("command-source.txt");
   Target  : constant String := Fixture_File ("command-target.txt");
   Large_Source : constant String := Fixture_File ("command-large-source.bin");
   Large_Target : constant String := Fixture_File ("command-large-target.bin");
   Dash_Target : constant String := Fixture_File ("command-dash-target.txt");
   Linked  : constant String := Fixture_File ("command-linked.txt");
   Link_Command_Target : constant String := Fixture_File ("command-link-command.txt");
   Symlinked : constant String := Fixture_File ("command-symlinked.txt");
   Cp_Symlinked : constant String := Fixture_File ("command-cp-symlinked.txt");
   Link_Dir : constant String := Fixture_File ("command-ln-dir");
   Moved   : constant String := Fixture_File ("command-moved.txt");
   Made    : constant String := Fixture_File ("command-dir");
   Mkfifo_Target : constant String := Fixture_File ("command-fifo");
   Symbolic_Mode_Dir : constant String := Fixture_File ("command-symbolic-mode-dir");
   Relative_Mode_Dir : constant String := Fixture_File ("command-relative-mode-dir");
   Remove_Dir : constant String := Fixture_File ("command-rm-dir");
   Rm_Interactive : constant String := Fixture_File ("command-rm-interactive.txt");
   Multi   : constant String := Fixture_File ("command-multi");
   Other   : constant String := Fixture_File ("command-other.txt");
   Tree    : constant String := Fixture_File ("command-tree");
   Tree_Copy : constant String := Fixture_File ("command-tree-copy");
   Sort_Out : constant String := Fixture_File ("command-sort-output.txt");
   Empty   : constant String := Fixture_File ("command-empty");
   Cp_Directory_Source : constant String := Fixture_File ("command-cp-directory-source");
   Cp_Directory_Target : constant String := Fixture_File ("command-cp-directory-target");
   Cp_FIFO_Source : constant String := Fixture_File ("command-cp-fifo-source");
   Cp_FIFO_Target : constant String := Fixture_File ("command-cp-fifo-target");
   Cp_Socket_Source : constant String := Fixture_File ("command-cp-socket-source");
   Cp_Socket_Target : constant String := Fixture_File ("command-cp-socket-target");
   Parent_Block : constant String := Fixture_File ("command-parent-block");
   Option_Dir : constant String := Fixture_File ("command-option-operands");
   Touched : constant String := Fixture_File ("command-touch.txt");
   No_Create : constant String := Fixture_File ("command-no-create.txt");
   Tee_Out : constant String := Fixture_File ("command-tee.txt");
   Chmod_Target : constant String := Fixture_File ("command-chmod.txt");
   Cksum_File : constant String := Fixture_File ("command-cksum.txt");
   Cmp_First : constant String := Fixture_File ("command-cmp-first.txt");
   Cmp_Second : constant String := Fixture_File ("command-cmp-second.txt");
   Paste_First : constant String := Fixture_File ("command-paste-first.txt");
   Paste_Second : constant String := Fixture_File ("command-paste-second.txt");
   Cut_File : constant String := Fixture_File ("command-cut.txt");
   Comm_First : constant String := Fixture_File ("command-comm-first.txt");
   Comm_Second : constant String := Fixture_File ("command-comm-second.txt");
   Od_File : constant String := Fixture_File ("command-od.bin");
   Ls_Dir : constant String := Fixture_File ("command-ls-dir");
   Ls_Other_Dir : constant String := Fixture_File ("command-ls-other-dir");
   Split_Input : constant String := Fixture_File ("command-split.txt");
   Split_Prefix : constant String := Fixture_File ("command-split-out-");
   Split_Long_Prefix : constant String := Fixture_File ("command-split-long-");
   Large_Hash_Input : constant String (1 .. 20_000) := [others => 'x'];
   EOL     : constant Character := Character'Val (10);
end Command_Tests.Surface_Smoke.Fixtures;
