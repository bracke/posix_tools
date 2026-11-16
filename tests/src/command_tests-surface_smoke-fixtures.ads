with Test_Support;

--  The scratch paths the surface tests share, under the tests' work
--  directory; nothing here is tracked.
package Command_Tests.Surface_Smoke.Fixtures is
   function Work_File (Name : String) return String is
     (Test_Support.Work_Path (Name));

   function Source return String is (Work_File ("command-source.txt"));
   function Target return String is (Work_File ("command-target.txt"));
   function Large_Source return String is (Work_File ("command-large-source.bin"));
   function Large_Target return String is (Work_File ("command-large-target.bin"));
   function Dash_Target return String is (Work_File ("command-dash-target.txt"));
   function Linked return String is (Work_File ("command-linked.txt"));
   function Link_Command_Target return String is (Work_File ("command-link-command.txt"));
   function Symlinked return String is (Work_File ("command-symlinked.txt"));
   function Cp_Symlinked return String is (Work_File ("command-cp-symlinked.txt"));
   function Link_Dir return String is (Work_File ("command-ln-dir"));
   function Moved return String is (Work_File ("command-moved.txt"));
   function Made return String is (Work_File ("command-dir"));
   function Mkfifo_Target return String is (Work_File ("command-fifo"));
   function Symbolic_Mode_Dir return String is (Work_File ("command-symbolic-mode-dir"));
   function Relative_Mode_Dir return String is (Work_File ("command-relative-mode-dir"));
   function Remove_Dir return String is (Work_File ("command-rm-dir"));
   function Rm_Interactive return String is (Work_File ("command-rm-interactive.txt"));
   function Multi return String is (Work_File ("command-multi"));
   function Other return String is (Work_File ("command-other.txt"));
   function Tree return String is (Work_File ("command-tree"));
   function Tree_Copy return String is (Work_File ("command-tree-copy"));
   function Sort_Out return String is (Work_File ("command-sort-output.txt"));
   function Empty return String is (Work_File ("command-empty"));
   function Cp_Directory_Source return String is (Work_File ("command-cp-directory-source"));
   function Cp_Directory_Target return String is (Work_File ("command-cp-directory-target"));
   function Cp_FIFO_Source return String is (Work_File ("command-cp-fifo-source"));
   function Cp_FIFO_Target return String is (Work_File ("command-cp-fifo-target"));
   function Cp_Socket_Source return String is (Work_File ("command-cp-socket-source"));
   function Cp_Socket_Target return String is (Work_File ("command-cp-socket-target"));
   function Parent_Block return String is (Work_File ("command-parent-block"));
   function Option_Dir return String is (Work_File ("command-option-operands"));
   function Touched return String is (Work_File ("command-touch.txt"));
   function No_Create return String is (Work_File ("command-no-create.txt"));
   function Tee_Out return String is (Work_File ("command-tee.txt"));
   function Chmod_Target return String is (Work_File ("command-chmod.txt"));
   function Cksum_File return String is (Work_File ("command-cksum.txt"));
   function Cmp_First return String is (Work_File ("command-cmp-first.txt"));
   function Cmp_Second return String is (Work_File ("command-cmp-second.txt"));
   function Paste_First return String is (Work_File ("command-paste-first.txt"));
   function Paste_Second return String is (Work_File ("command-paste-second.txt"));
   function Cut_File return String is (Work_File ("command-cut.txt"));
   function Comm_First return String is (Work_File ("command-comm-first.txt"));
   function Comm_Second return String is (Work_File ("command-comm-second.txt"));
   function Od_File return String is (Work_File ("command-od.bin"));
   function Ls_Dir return String is (Work_File ("command-ls-dir"));
   function Ls_Other_Dir return String is (Work_File ("command-ls-other-dir"));
   function Split_Input return String is (Work_File ("command-split.txt"));
   function Split_Prefix return String is (Work_File ("command-split-out-"));
   function Split_Long_Prefix return String is (Work_File ("command-split-long-"));
   Large_Hash_Input : constant String (1 .. 20_000) := [others => 'x'];
   EOL     : constant Character := Character'Val (10);
end Command_Tests.Surface_Smoke.Fixtures;
