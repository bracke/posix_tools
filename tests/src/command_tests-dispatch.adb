with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Commands.Arch;
with Posix_Tools.Commands.Basename;
with Posix_Tools.Commands.Cat;
with Posix_Tools.Commands.Chgrp;
with Posix_Tools.Commands.Chmod;
with Posix_Tools.Commands.Chown;
with Posix_Tools.Commands.Cksum;
with Posix_Tools.Commands.Cmp;
with Posix_Tools.Commands.Comm;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Cp;
with Posix_Tools.Commands.Cut;
with Posix_Tools.Commands.Date;
with Posix_Tools.Commands.Dd;
with Posix_Tools.Commands.Df;
with Posix_Tools.Commands.Dirname;
with Posix_Tools.Commands.Du;
with Posix_Tools.Commands.Echo;
with Posix_Tools.Commands.Env;
with Posix_Tools.Commands.Expand;
with Posix_Tools.Commands.Expr;
with Posix_Tools.Commands.False_Command;
with Posix_Tools.Commands.File;
with Posix_Tools.Commands.Find;
with Posix_Tools.Commands.Fold;
with Posix_Tools.Commands.Getconf;
with Posix_Tools.Commands.Groups;
with Posix_Tools.Commands.Head;
with Posix_Tools.Commands.Hostname;
with Posix_Tools.Commands.Id;
with Posix_Tools.Commands.Kill;
with Posix_Tools.Commands.Link;
with Posix_Tools.Commands.Ln;
with Posix_Tools.Commands.Locale;
with Posix_Tools.Commands.Logname;
with Posix_Tools.Commands.Ls;
with Posix_Tools.Commands.Mkdir;
with Posix_Tools.Commands.Mkfifo;
with Posix_Tools.Commands.Mv;
with Posix_Tools.Commands.Nice;
with Posix_Tools.Commands.Nl;
with Posix_Tools.Commands.Nohup;
with Posix_Tools.Commands.Od;
with Posix_Tools.Commands.Paste;
with Posix_Tools.Commands.Pathchk;
with Posix_Tools.Commands.Printenv;
with Posix_Tools.Commands.Printf;
with Posix_Tools.Commands.Pwd;
with Posix_Tools.Commands.Readlink;
with Posix_Tools.Commands.Realpath;
with Posix_Tools.Commands.Rm;
with Posix_Tools.Commands.Rmdir;
with Posix_Tools.Commands.Run_Entry;
with Posix_Tools.Commands.Seq;
with Posix_Tools.Commands.Sha256sum;
with Posix_Tools.Commands.Sleep;
with Posix_Tools.Commands.Sort;
with Posix_Tools.Commands.Split;
with Posix_Tools.Commands.Stat;
with Posix_Tools.Commands.Tail;
with Posix_Tools.Commands.Tee;
with Posix_Tools.Commands.Test_Command;
with Posix_Tools.Commands.Timeout;
with Posix_Tools.Commands.Touch;
with Posix_Tools.Commands.Tr;
with Posix_Tools.Commands.True_Command;
with Posix_Tools.Commands.Tty;
with Posix_Tools.Commands.Uname;
with Posix_Tools.Commands.Unexpand;
with Posix_Tools.Commands.Uniq;
with Posix_Tools.Commands.Unlink;
with Posix_Tools.Commands.Wc;
with Posix_Tools.Commands.Which;
with Posix_Tools.Commands.Whoami;
with Posix_Tools.Commands.Xargs;
with Posix_Tools.Commands.Yes;
with Posix_Tools.Exit_Status;
with Posix_Tools.Help;

package body Command_Tests.Dispatch is
   use Ada.Strings.Unbounded;

   type Entry_Access is access procedure
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result);

   type Binding is record
      Name         : Unbounded_String;
      Package_Name : Unbounded_String;
      Run          : Entry_Access;
   end record;

   procedure Run_Arch is new Posix_Tools.Commands.Run_Entry ("arch", Posix_Tools.Commands.Arch.Run);
   procedure Run_Basename is new Posix_Tools.Commands.Run_Entry ("basename", Posix_Tools.Commands.Basename.Run);
   procedure Run_Cat is new Posix_Tools.Commands.Run_Entry ("cat", Posix_Tools.Commands.Cat.Run);
   procedure Run_Chgrp is new Posix_Tools.Commands.Run_Entry ("chgrp", Posix_Tools.Commands.Chgrp.Run);
   procedure Run_Chmod is new Posix_Tools.Commands.Run_Entry ("chmod", Posix_Tools.Commands.Chmod.Run);
   procedure Run_Chown is new Posix_Tools.Commands.Run_Entry ("chown", Posix_Tools.Commands.Chown.Run);
   procedure Run_Cksum is new Posix_Tools.Commands.Run_Entry ("cksum", Posix_Tools.Commands.Cksum.Run);
   procedure Run_Cmp is new Posix_Tools.Commands.Run_Entry ("cmp", Posix_Tools.Commands.Cmp.Run);
   procedure Run_Comm is new Posix_Tools.Commands.Run_Entry ("comm", Posix_Tools.Commands.Comm.Run);
   procedure Run_Cp is new Posix_Tools.Commands.Run_Entry ("cp", Posix_Tools.Commands.Cp.Run);
   procedure Run_Cut is new Posix_Tools.Commands.Run_Entry ("cut", Posix_Tools.Commands.Cut.Run);
   procedure Run_Date is new Posix_Tools.Commands.Run_Entry ("date", Posix_Tools.Commands.Date.Run);
   procedure Run_Dd is new Posix_Tools.Commands.Run_Entry ("dd", Posix_Tools.Commands.Dd.Run);
   procedure Run_Df is new Posix_Tools.Commands.Run_Entry ("df", Posix_Tools.Commands.Df.Run);
   procedure Run_Dirname is new Posix_Tools.Commands.Run_Entry ("dirname", Posix_Tools.Commands.Dirname.Run);
   procedure Run_Du is new Posix_Tools.Commands.Run_Entry ("du", Posix_Tools.Commands.Du.Run);
   procedure Run_Echo is new Posix_Tools.Commands.Run_Entry ("echo", Posix_Tools.Commands.Echo.Run);
   procedure Run_Env is new Posix_Tools.Commands.Run_Entry ("env", Posix_Tools.Commands.Env.Run);
   procedure Run_Expand is new Posix_Tools.Commands.Run_Entry ("expand", Posix_Tools.Commands.Expand.Run);
   procedure Run_Expr is new Posix_Tools.Commands.Run_Entry ("expr", Posix_Tools.Commands.Expr.Run);
   procedure Run_False is new Posix_Tools.Commands.Run_Entry ("false", Posix_Tools.Commands.False_Command.Run);
   procedure Run_File is new Posix_Tools.Commands.Run_Entry ("file", Posix_Tools.Commands.File.Run);
   procedure Run_Find is new Posix_Tools.Commands.Run_Entry ("find", Posix_Tools.Commands.Find.Run);
   procedure Run_Fold is new Posix_Tools.Commands.Run_Entry ("fold", Posix_Tools.Commands.Fold.Run);
   procedure Run_Getconf is new Posix_Tools.Commands.Run_Entry ("getconf", Posix_Tools.Commands.Getconf.Run);
   procedure Run_Groups is new Posix_Tools.Commands.Run_Entry ("groups", Posix_Tools.Commands.Groups.Run);
   procedure Run_Head is new Posix_Tools.Commands.Run_Entry ("head", Posix_Tools.Commands.Head.Run);
   procedure Run_Hostname is new Posix_Tools.Commands.Run_Entry ("hostname", Posix_Tools.Commands.Hostname.Run);
   procedure Run_Id is new Posix_Tools.Commands.Run_Entry ("id", Posix_Tools.Commands.Id.Run);
   procedure Run_Kill is new Posix_Tools.Commands.Run_Entry ("kill", Posix_Tools.Commands.Kill.Run);
   procedure Run_Link is new Posix_Tools.Commands.Run_Entry ("link", Posix_Tools.Commands.Link.Run);
   procedure Run_Ln is new Posix_Tools.Commands.Run_Entry ("ln", Posix_Tools.Commands.Ln.Run);
   procedure Run_Locale is new Posix_Tools.Commands.Run_Entry ("locale", Posix_Tools.Commands.Locale.Run);
   procedure Run_Logname is new Posix_Tools.Commands.Run_Entry ("logname", Posix_Tools.Commands.Logname.Run);
   procedure Run_Ls is new Posix_Tools.Commands.Run_Entry ("ls", Posix_Tools.Commands.Ls.Run);
   procedure Run_Mkdir is new Posix_Tools.Commands.Run_Entry ("mkdir", Posix_Tools.Commands.Mkdir.Run);
   procedure Run_Mkfifo is new Posix_Tools.Commands.Run_Entry ("mkfifo", Posix_Tools.Commands.Mkfifo.Run);
   procedure Run_Mv is new Posix_Tools.Commands.Run_Entry ("mv", Posix_Tools.Commands.Mv.Run);
   procedure Run_Nice is new Posix_Tools.Commands.Run_Entry ("nice", Posix_Tools.Commands.Nice.Run);
   procedure Run_Nl is new Posix_Tools.Commands.Run_Entry ("nl", Posix_Tools.Commands.Nl.Run);
   procedure Run_Nohup is new Posix_Tools.Commands.Run_Entry ("nohup", Posix_Tools.Commands.Nohup.Run);
   procedure Run_Od is new Posix_Tools.Commands.Run_Entry ("od", Posix_Tools.Commands.Od.Run);
   procedure Run_Paste is new Posix_Tools.Commands.Run_Entry ("paste", Posix_Tools.Commands.Paste.Run);
   procedure Run_Pathchk is new Posix_Tools.Commands.Run_Entry ("pathchk", Posix_Tools.Commands.Pathchk.Run);
   procedure Run_Printenv is new Posix_Tools.Commands.Run_Entry ("printenv", Posix_Tools.Commands.Printenv.Run);
   procedure Run_Printf is new Posix_Tools.Commands.Run_Entry ("printf", Posix_Tools.Commands.Printf.Run);
   procedure Run_Pwd is new Posix_Tools.Commands.Run_Entry ("pwd", Posix_Tools.Commands.Pwd.Run);
   procedure Run_Readlink is new Posix_Tools.Commands.Run_Entry ("readlink", Posix_Tools.Commands.Readlink.Run);
   procedure Run_Realpath is new Posix_Tools.Commands.Run_Entry ("realpath", Posix_Tools.Commands.Realpath.Run);
   procedure Run_Rm is new Posix_Tools.Commands.Run_Entry ("rm", Posix_Tools.Commands.Rm.Run);
   procedure Run_Rmdir is new Posix_Tools.Commands.Run_Entry ("rmdir", Posix_Tools.Commands.Rmdir.Run);
   procedure Run_Seq is new Posix_Tools.Commands.Run_Entry ("seq", Posix_Tools.Commands.Seq.Run);
   procedure Run_Sha256sum is new Posix_Tools.Commands.Run_Entry ("sha256sum", Posix_Tools.Commands.Sha256sum.Run);
   procedure Run_Sleep is new Posix_Tools.Commands.Run_Entry ("sleep", Posix_Tools.Commands.Sleep.Run);
   procedure Run_Sort is new Posix_Tools.Commands.Run_Entry ("sort", Posix_Tools.Commands.Sort.Run);
   procedure Run_Split is new Posix_Tools.Commands.Run_Entry ("split", Posix_Tools.Commands.Split.Run);
   procedure Run_Stat is new Posix_Tools.Commands.Run_Entry ("stat", Posix_Tools.Commands.Stat.Run);
   procedure Run_Tail is new Posix_Tools.Commands.Run_Entry ("tail", Posix_Tools.Commands.Tail.Run);
   procedure Run_Tee is new Posix_Tools.Commands.Run_Entry ("tee", Posix_Tools.Commands.Tee.Run);
   procedure Run_Test is new Posix_Tools.Commands.Run_Entry ("test", Posix_Tools.Commands.Test_Command.Run);
   procedure Run_Timeout is new Posix_Tools.Commands.Run_Entry ("timeout", Posix_Tools.Commands.Timeout.Run);
   procedure Run_Touch is new Posix_Tools.Commands.Run_Entry ("touch", Posix_Tools.Commands.Touch.Run);
   procedure Run_Tr is new Posix_Tools.Commands.Run_Entry ("tr", Posix_Tools.Commands.Tr.Run);
   procedure Run_True is new Posix_Tools.Commands.Run_Entry ("true", Posix_Tools.Commands.True_Command.Run);
   procedure Run_Tty is new Posix_Tools.Commands.Run_Entry ("tty", Posix_Tools.Commands.Tty.Run);
   procedure Run_Uname is new Posix_Tools.Commands.Run_Entry ("uname", Posix_Tools.Commands.Uname.Run);
   procedure Run_Unexpand is new Posix_Tools.Commands.Run_Entry ("unexpand", Posix_Tools.Commands.Unexpand.Run);
   procedure Run_Uniq is new Posix_Tools.Commands.Run_Entry ("uniq", Posix_Tools.Commands.Uniq.Run);
   procedure Run_Unlink is new Posix_Tools.Commands.Run_Entry ("unlink", Posix_Tools.Commands.Unlink.Run);
   procedure Run_Wc is new Posix_Tools.Commands.Run_Entry ("wc", Posix_Tools.Commands.Wc.Run);
   procedure Run_Which is new Posix_Tools.Commands.Run_Entry ("which", Posix_Tools.Commands.Which.Run);
   procedure Run_Whoami is new Posix_Tools.Commands.Run_Entry ("whoami", Posix_Tools.Commands.Whoami.Run);
   procedure Run_Xargs is new Posix_Tools.Commands.Run_Entry ("xargs", Posix_Tools.Commands.Xargs.Run);
   procedure Run_Yes is new Posix_Tools.Commands.Run_Entry ("yes", Posix_Tools.Commands.Yes.Run);

   function "+" (Text : String) return Unbounded_String renames To_Unbounded_String;

   --  One row per wrapper that instantiates Host_Adapters.Run_Command, with
   --  the executable name and command package that wrapper passes it.
   Bindings : constant array (Positive range <>) of Binding :=
     [(+"arch", +"Posix_Tools.Commands.Arch", Run_Arch'Access),
      (+"basename", +"Posix_Tools.Commands.Basename", Run_Basename'Access),
      (+"cat", +"Posix_Tools.Commands.Cat", Run_Cat'Access),
      (+"chgrp", +"Posix_Tools.Commands.Chgrp", Run_Chgrp'Access),
      (+"chmod", +"Posix_Tools.Commands.Chmod", Run_Chmod'Access),
      (+"chown", +"Posix_Tools.Commands.Chown", Run_Chown'Access),
      (+"cksum", +"Posix_Tools.Commands.Cksum", Run_Cksum'Access),
      (+"cmp", +"Posix_Tools.Commands.Cmp", Run_Cmp'Access),
      (+"comm", +"Posix_Tools.Commands.Comm", Run_Comm'Access),
      (+"cp", +"Posix_Tools.Commands.Cp", Run_Cp'Access),
      (+"cut", +"Posix_Tools.Commands.Cut", Run_Cut'Access),
      (+"date", +"Posix_Tools.Commands.Date", Run_Date'Access),
      (+"dd", +"Posix_Tools.Commands.Dd", Run_Dd'Access),
      (+"df", +"Posix_Tools.Commands.Df", Run_Df'Access),
      (+"dirname", +"Posix_Tools.Commands.Dirname", Run_Dirname'Access),
      (+"du", +"Posix_Tools.Commands.Du", Run_Du'Access),
      (+"echo", +"Posix_Tools.Commands.Echo", Run_Echo'Access),
      (+"env", +"Posix_Tools.Commands.Env", Run_Env'Access),
      (+"expand", +"Posix_Tools.Commands.Expand", Run_Expand'Access),
      (+"expr", +"Posix_Tools.Commands.Expr", Run_Expr'Access),
      (+"false", +"Posix_Tools.Commands.False_Command", Run_False'Access),
      (+"file", +"Posix_Tools.Commands.File", Run_File'Access),
      (+"find", +"Posix_Tools.Commands.Find", Run_Find'Access),
      (+"fold", +"Posix_Tools.Commands.Fold", Run_Fold'Access),
      (+"getconf", +"Posix_Tools.Commands.Getconf", Run_Getconf'Access),
      (+"groups", +"Posix_Tools.Commands.Groups", Run_Groups'Access),
      (+"head", +"Posix_Tools.Commands.Head", Run_Head'Access),
      (+"hostname", +"Posix_Tools.Commands.Hostname", Run_Hostname'Access),
      (+"id", +"Posix_Tools.Commands.Id", Run_Id'Access),
      (+"kill", +"Posix_Tools.Commands.Kill", Run_Kill'Access),
      (+"link", +"Posix_Tools.Commands.Link", Run_Link'Access),
      (+"ln", +"Posix_Tools.Commands.Ln", Run_Ln'Access),
      (+"locale", +"Posix_Tools.Commands.Locale", Run_Locale'Access),
      (+"logname", +"Posix_Tools.Commands.Logname", Run_Logname'Access),
      (+"ls", +"Posix_Tools.Commands.Ls", Run_Ls'Access),
      (+"mkdir", +"Posix_Tools.Commands.Mkdir", Run_Mkdir'Access),
      (+"mkfifo", +"Posix_Tools.Commands.Mkfifo", Run_Mkfifo'Access),
      (+"mv", +"Posix_Tools.Commands.Mv", Run_Mv'Access),
      (+"nice", +"Posix_Tools.Commands.Nice", Run_Nice'Access),
      (+"nl", +"Posix_Tools.Commands.Nl", Run_Nl'Access),
      (+"nohup", +"Posix_Tools.Commands.Nohup", Run_Nohup'Access),
      (+"od", +"Posix_Tools.Commands.Od", Run_Od'Access),
      (+"paste", +"Posix_Tools.Commands.Paste", Run_Paste'Access),
      (+"pathchk", +"Posix_Tools.Commands.Pathchk", Run_Pathchk'Access),
      (+"printenv", +"Posix_Tools.Commands.Printenv", Run_Printenv'Access),
      (+"printf", +"Posix_Tools.Commands.Printf", Run_Printf'Access),
      (+"pwd", +"Posix_Tools.Commands.Pwd", Run_Pwd'Access),
      (+"readlink", +"Posix_Tools.Commands.Readlink", Run_Readlink'Access),
      (+"realpath", +"Posix_Tools.Commands.Realpath", Run_Realpath'Access),
      (+"rm", +"Posix_Tools.Commands.Rm", Run_Rm'Access),
      (+"rmdir", +"Posix_Tools.Commands.Rmdir", Run_Rmdir'Access),
      (+"seq", +"Posix_Tools.Commands.Seq", Run_Seq'Access),
      (+"sha256sum", +"Posix_Tools.Commands.Sha256sum", Run_Sha256sum'Access),
      (+"sleep", +"Posix_Tools.Commands.Sleep", Run_Sleep'Access),
      (+"sort", +"Posix_Tools.Commands.Sort", Run_Sort'Access),
      (+"split", +"Posix_Tools.Commands.Split", Run_Split'Access),
      (+"stat", +"Posix_Tools.Commands.Stat", Run_Stat'Access),
      (+"tail", +"Posix_Tools.Commands.Tail", Run_Tail'Access),
      (+"tee", +"Posix_Tools.Commands.Tee", Run_Tee'Access),
      (+"test", +"Posix_Tools.Commands.Test_Command", Run_Test'Access),
      (+"timeout", +"Posix_Tools.Commands.Timeout", Run_Timeout'Access),
      (+"touch", +"Posix_Tools.Commands.Touch", Run_Touch'Access),
      (+"tr", +"Posix_Tools.Commands.Tr", Run_Tr'Access),
      (+"true", +"Posix_Tools.Commands.True_Command", Run_True'Access),
      (+"tty", +"Posix_Tools.Commands.Tty", Run_Tty'Access),
      (+"uname", +"Posix_Tools.Commands.Uname", Run_Uname'Access),
      (+"unexpand", +"Posix_Tools.Commands.Unexpand", Run_Unexpand'Access),
      (+"uniq", +"Posix_Tools.Commands.Uniq", Run_Uniq'Access),
      (+"unlink", +"Posix_Tools.Commands.Unlink", Run_Unlink'Access),
      (+"wc", +"Posix_Tools.Commands.Wc", Run_Wc'Access),
      (+"which", +"Posix_Tools.Commands.Which", Run_Which'Access),
      (+"whoami", +"Posix_Tools.Commands.Whoami", Run_Whoami'Access),
      (+"xargs", +"Posix_Tools.Commands.Xargs", Run_Xargs'Access),
      (+"yes", +"Posix_Tools.Commands.Yes", Run_Yes'Access)];

   function Bound_Package (Name : String) return String is
   begin
      for Item of Bindings loop
         if To_String (Item.Name) = Name then
            return To_String (Item.Package_Name);
         end if;
      end loop;

      return "";
   end Bound_Package;

   function Is_Rendering_Only (Name : String) return Boolean is
   begin
      return Name = "awk" or else Name = "explore" or else Name = "grep" or else Name = "sed";
   end Is_Rendering_Only;

   procedure Run
     (Name    : String;
      Context : in out Test_Contexts.Capturing_Context;
      Result  : out Posix_Tools.Commands.Results.Result) is
   begin
      for Item of Bindings loop
         if To_String (Item.Name) = Name then
            Item.Run (Context, Result);
            return;
         end if;
      end loop;

      AUnit.Assertions.Assert (Is_Rendering_Only (Name), "unknown command inventory entry " & Name);
      if Context.Argument_Count = 1 and then Context.Argument (1) = "--help" then
         Posix_Tools.Help.Render_Command_Help (Context, Name);
         Result.Status := Posix_Tools.Exit_Status.Success;
      elsif Context.Argument_Count = 1 and then Context.Argument (1) = "--version" then
         Posix_Tools.Help.Render_Version (Context, Name);
         Result.Status := Posix_Tools.Exit_Status.Success;
      elsif Context.Argument_Count = 1 and then Context.Argument (1) = "--posix-tools-identify" then
         Posix_Tools.Help.Render_Identity (Context, Name);
         Result.Status := Posix_Tools.Exit_Status.Success;
      else
         AUnit.Assertions.Assert (False, Name & " is not context-dispatched in the test suite");
      end if;
   end Run;
end Command_Tests.Dispatch;
