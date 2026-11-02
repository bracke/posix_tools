--  The scratch paths the surface tests share, under the tests' work
--  directory; nothing here is tracked.
package Command_Tests.Surface_Smoke.Fixtures is
   --  Test_Support.Work_Path, here as an expression so the constants below
   --  need no package body elaborated before them.
   function Work_File (Name : String) return String is
     ("generated/test-work/" & Name);

   Source  : constant String := Work_File ("command-source.txt");
   Target  : constant String := Work_File ("command-target.txt");
   Large_Source : constant String := Work_File ("command-large-source.bin");
   Large_Target : constant String := Work_File ("command-large-target.bin");
   Dash_Target : constant String := Work_File ("command-dash-target.txt");
   Linked  : constant String := Work_File ("command-linked.txt");
   Link_Command_Target : constant String := Work_File ("command-link-command.txt");
   Symlinked : constant String := Work_File ("command-symlinked.txt");
   Cp_Symlinked : constant String := Work_File ("command-cp-symlinked.txt");
   Link_Dir : constant String := Work_File ("command-ln-dir");
   Moved   : constant String := Work_File ("command-moved.txt");
   Made    : constant String := Work_File ("command-dir");
   Mkfifo_Target : constant String := Work_File ("command-fifo");
   Symbolic_Mode_Dir : constant String := Work_File ("command-symbolic-mode-dir");
   Relative_Mode_Dir : constant String := Work_File ("command-relative-mode-dir");
   Remove_Dir : constant String := Work_File ("command-rm-dir");
   Rm_Interactive : constant String := Work_File ("command-rm-interactive.txt");
   Multi   : constant String := Work_File ("command-multi");
   Other   : constant String := Work_File ("command-other.txt");
   Tree    : constant String := Work_File ("command-tree");
   Tree_Copy : constant String := Work_File ("command-tree-copy");
   Sort_Out : constant String := Work_File ("command-sort-output.txt");
   Empty   : constant String := Work_File ("command-empty");
   Cp_Directory_Source : constant String := Work_File ("command-cp-directory-source");
   Cp_Directory_Target : constant String := Work_File ("command-cp-directory-target");
   Cp_FIFO_Source : constant String := Work_File ("command-cp-fifo-source");
   Cp_FIFO_Target : constant String := Work_File ("command-cp-fifo-target");
   Cp_Socket_Source : constant String := Work_File ("command-cp-socket-source");
   Cp_Socket_Target : constant String := Work_File ("command-cp-socket-target");
   Parent_Block : constant String := Work_File ("command-parent-block");
   Option_Dir : constant String := Work_File ("command-option-operands");
   Touched : constant String := Work_File ("command-touch.txt");
   No_Create : constant String := Work_File ("command-no-create.txt");
   Tee_Out : constant String := Work_File ("command-tee.txt");
   Chmod_Target : constant String := Work_File ("command-chmod.txt");
   Cksum_File : constant String := Work_File ("command-cksum.txt");
   Cmp_First : constant String := Work_File ("command-cmp-first.txt");
   Cmp_Second : constant String := Work_File ("command-cmp-second.txt");
   Paste_First : constant String := Work_File ("command-paste-first.txt");
   Paste_Second : constant String := Work_File ("command-paste-second.txt");
   Cut_File : constant String := Work_File ("command-cut.txt");
   Comm_First : constant String := Work_File ("command-comm-first.txt");
   Comm_Second : constant String := Work_File ("command-comm-second.txt");
   Od_File : constant String := Work_File ("command-od.bin");
   Ls_Dir : constant String := Work_File ("command-ls-dir");
   Ls_Other_Dir : constant String := Work_File ("command-ls-other-dir");
   Split_Input : constant String := Work_File ("command-split.txt");
   Split_Prefix : constant String := Work_File ("command-split-out-");
   Split_Long_Prefix : constant String := Work_File ("command-split-long-");
   Large_Hash_Input : constant String (1 .. 20_000) := [others => 'x'];
   EOL     : constant Character := Character'Val (10);
end Command_Tests.Surface_Smoke.Fixtures;
