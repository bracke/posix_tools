with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;
with Ada.Directories;
with AUnit.Assertions;
with Command_Tests.Surface_Smoke.Fixtures;
with Command_Tests.Surface_Smoke.Helpers;
with GNAT.OS_Lib;
with Hostkit.Fs;
with Hostkit.Metadata;
with Posix_Tools.Commands.Cat;
with Posix_Tools.Commands.Find;
with Posix_Tools.Commands.Ls;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Test_Command;
with Posix_Tools.Commands.Touch;
with Posix_Tools.Exit_Status;
with Test_Contexts;

package body Command_Tests.Surface_Smoke.Metadata is
   use type Hostkit.Fs.Special_File_Kind;
   use type Ada.Calendar.Time;
   use type Posix_Tools.Exit_Status.Code;
   use Command_Tests.Surface_Smoke.Fixtures;
   use Command_Tests.Surface_Smoke.Helpers;

   procedure Test_Find (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Prepare_Search_Fixtures;
      Context.Initialize ("find", One_Arg (Source));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Source & EOL, "find file output");

      Context.Initialize ("find", One_Arg (Source));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "find reports standard-output failure");

      Context.Initialize ("find", Two_Args (Source, "-print"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Source & EOL, "find explicit -print output");

      --  Neither names a file here, so each is diagnosed as a missing
      --  path operand rather than taken as an option or primary.
      Context.Initialize ("find", One_Arg ("-"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "find: '-': no such file or directory" & EOL,
         "find treats - as path operand");

      Context.Initialize ("find", Two_Args ("--", "-name"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Error_Output (Context) = "find: '-name': no such file or directory" & EOL,
         "find treats option-like operand after -- as path operand");

      Context.Initialize ("find", Three_Args (Made, "-name", "command-source.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -name output");

      Context.Initialize ("find", Three_Args (Made, "-name", "command-source.t?t"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -name question wildcard output");

      Context.Initialize ("find", Three_Args (Made, "-name", "command-source.[tx][xq]t"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -name bracket list output");

      Context.Initialize ("find", Three_Args (Made, "-name", "command-source.[a-z][a-z]t"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -name bracket range output");

      Context.Initialize ("find", Three_Args (Made, "-name", "command-source.[!0-9][!0-9]t"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -name negated bracket range output");

      Context.Initialize ("find", Three_Args (Tree, "-path", "*/sub/file.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "command-tree" & EOL),
         "find -path output");

      Context.Initialize ("find", Three_Args (Tree, "-type", "d"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-tree" & EOL)
         and then Contains (Test_Contexts.Output (Context), "sub" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
         "find -type d output");

      Context.Initialize ("find", Three_Args (Tree, "-type", "p"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "find exact FIFO type excludes ordinary tree entries");

      if Hostkit.Fs.Special_File_Info_Of (Cp_FIFO_Source).Kind = Hostkit.Fs.FIFO then
         Context.Initialize ("find", Three_Args (Cp_FIFO_Source, "-type", "p"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = Cp_FIFO_Source & EOL,
            "find -type p matches FIFO exactly");
      end if;

      if Hostkit.Fs.Special_File_Info_Of (Cp_Socket_Source).Kind = Hostkit.Fs.Socket then
         Context.Initialize ("find", Three_Args (Cp_Socket_Source, "-type", "s"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = Cp_Socket_Source & EOL,
            "find -type s matches socket exactly");
      end if;

      if Ada.Directories.Exists ("/dev/null")
        and then Hostkit.Fs.Special_File_Info_Of ("/dev/null").Kind = Hostkit.Fs.Character_Device
      then
         Context.Initialize ("find", Three_Args ("/dev/null", "-type", "c"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = "/dev/null" & EOL,
            "find -type c matches character device exactly");

         Context.Initialize ("find", Three_Args ("/dev/null", "-type", "b"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = "",
            "find -type b excludes character device");
      end if;

      Context.Initialize ("find", Three_Args (Made, "-size", "9c"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -size exact bytes output");

      Context.Initialize ("find", Three_Args (Made, "-size", "+8c"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -size greater bytes output");

      Context.Initialize ("find", Three_Args (Made, "-size", "-2"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -size less default blocks output");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-size", "bad"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects invalid -size count");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-size", "++1c"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects double-signed -size count");

      Write_File (Source, "copy-data");
      Write_File (Other, "old-data");
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (Other,
         GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));

      Context.Initialize ("find", Three_Args (Source, "-mtime", "-1"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -mtime less than one day output");

      Context.Initialize ("find", Three_Args (Source, "-mtime", "+99999"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (not Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -mtime greater than large age excludes current file");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-mtime", "bad"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects invalid -mtime count");

      Context.Initialize ("find", Three_Args (Source, "-newer", Other));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -newer reference output");

      Context.Initialize ("find", Six_Args (Source, "-exec", "echo", "seen", "{}", ";"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "seen " & Source & EOL,
         "find -exec replacement output");

      Context.Initialize ("find", Four_Args (Source, "-exec", "false", ";"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "find -exec false suppresses default output");

      Context.Initialize ("find", Six_Args (Source, "-exec", "echo", "plus", "{}", "+"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "plus " & Source & EOL,
         "find -exec plus replacement output");

      Context.Initialize ("find", Six_Args (Tree, "-exec", "echo", "batch", "{}", "+"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "batch " & Tree & " " & Tree & "/sub "
           & Tree & "/sub/file.txt" & EOL,
         "find -exec plus batches matches");

      Context.Initialize ("find", Six_Args (Source, "-exec", "echo", "{}", "after", "+"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects plus without preceding replacement");

      Context.Initialize ("find", Three_Args (Source, "-exec", "+"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects missing utility before -exec plus");

      Context.Initialize ("find", Four_Args (Source, "-exec", "echo", "{}"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects unterminated -exec");

      Context.Initialize ("find", Six_Args (Source, "-ok", "echo", "ok", "{}", ";"));
      Test_Contexts.Set_Standard_Input (Context, "y" & EOL);
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ok " & Source & EOL
         and then Contains (Test_Contexts.Error_Output (Context), "< echo ... " & Source & " > ?"),
         "find -ok executes after affirmative response");

      Context.Initialize ("find", Six_Args (Source, "-ok", "echo", "ok", "{}", ";"));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Contains (Test_Contexts.Error_Output (Context), "< echo ... " & Source & " > ?"),
         "find -ok skips after negative response");

      Context.Initialize ("find", Four_Args (Source, "-ok", "echo", "{}"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects unterminated -ok");

      Context.Initialize ("find", Two_Args (Tree, "-depth"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Tree & "/sub/file.txt" & EOL
           & Tree & "/sub" & EOL
           & Tree & EOL,
         "find -depth post-order output");

      Context.Initialize ("find", Four_Args (Tree, "-name", "sub", "-prune"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "sub" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
         "find -prune skips subtree");

      Context.Initialize ("find", Two_Args (Tree, "-xdev"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), Tree & EOL)
         and then Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
         "find -xdev keeps traversal on the starting device");

      if Hostkit.Metadata.Permissions_Supported then
         AUnit.Assertions.Assert
           (Hostkit.Metadata.Set_Permissions (Tree & "/sub/file.txt", 8#640#),
            "find -perm file mode setup");
         Context.Initialize ("find", Three_Args (Tree, "-perm", "640"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
            "find -perm exact output");

         Context.Initialize ("find", Three_Args (Tree, "-perm", "-600"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
            "find -perm all-bits output");

         Context.Initialize ("find", Three_Args (Tree, "-perm", "u=rw,g=r,o="));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
            "find -perm symbolic exact output");

         Context.Initialize ("find", Three_Args (Tree, "-perm", "-u=rw"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
            "find -perm symbolic all-bits output");

         Context.Initialize ("find", Three_Args (Tree, "-perm", "bad"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
            "find rejects invalid -perm mode");
      end if;

      if Hostkit.Metadata.Ownership_Supported then
         declare
            User_Id : Natural;
            Group_Id : Natural;
            Available : Boolean;
         begin
            Hostkit.Metadata.File_Ownership (Source, User_Id, Group_Id, Available);
            if Available then
               declare
                  User_Raw : constant String := Natural'Image (User_Id);
                  Group_Raw : constant String := Natural'Image (Group_Id);
                  User_Text : constant String := User_Raw (User_Raw'First + 1 .. User_Raw'Last);
                  Group_Text : constant String := Group_Raw (Group_Raw'First + 1 .. Group_Raw'Last);
                  User_Name : constant String := Hostkit.Metadata.User_Name_For_Id (User_Id);
                  Group_Name : constant String := Hostkit.Metadata.Group_Name_For_Id (Group_Id);
               begin
                  Context.Initialize ("find", Three_Args (Source, "-user", User_Text));
                  Posix_Tools.Commands.Find.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
                     "find -user numeric output");

                  Context.Initialize ("find", Three_Args (Source, "-group", Group_Text));
                  Posix_Tools.Commands.Find.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
                     "find -group numeric output");

                  Context.Initialize
                    ("find", Three_Args (Source, "-user", "999999999999999999999999999999"));
                  Posix_Tools.Commands.Find.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Result.Status = Posix_Tools.Exit_Status.Success
                     and then not Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
                     "find overflowing numeric user does not match");

                  if User_Name /= "" then
                     Context.Initialize ("find", Three_Args (Source, "-user", User_Name));
                     Posix_Tools.Commands.Find.Run (Context, Result);
                     AUnit.Assertions.Assert
                       (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
                        "find -user named output");
                  end if;

                  if Group_Name /= "" then
                     Context.Initialize ("find", Three_Args (Source, "-group", Group_Name));
                     Posix_Tools.Commands.Find.Run (Context, Result);
                     AUnit.Assertions.Assert
                       (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
                        "find -group named output");
                  end if;

                  Context.Initialize ("find", Two_Args (Source, "-nouser"));
                  Posix_Tools.Commands.Find.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Result.Status = Posix_Tools.Exit_Status.Success
                     and then (User_Name = ""
                               or else not Contains
                                 (Test_Contexts.Output (Context), "command-source.txt" & EOL)),
                     "find -nouser output");

                  Context.Initialize ("find", Two_Args (Source, "-nogroup"));
                  Posix_Tools.Commands.Find.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Result.Status = Posix_Tools.Exit_Status.Success
                     and then (Group_Name = ""
                               or else not Contains
                                 (Test_Contexts.Output (Context), "command-source.txt" & EOL)),
                     "find -nogroup output");
               end;
            end if;
         end;
      end if;

      Context.Initialize ("find", Five_Args (Tree, "-type", "f", "-name", "file.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
         "find -type f -name output");

      Context.Initialize ("find", Six_Args (Tree, "-type", "f", "-a", "-name", "file.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "sub" & EOL),
         "find explicit and expression output");

      Context.Initialize
        ("find",
         Six_Args (Made, "-name", "command-source.txt", "-o", "-name", "command-other.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL)
         and then Contains (Test_Contexts.Output (Context), "command-other.txt" & EOL),
         "find or expression output");

      Context.Initialize ("find", Four_Args (Tree, "!", "-type", "d"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "command-tree" & EOL),
         "find negated expression output");

      Context.Initialize ("find", Six_Args (Tree, "(", "-name", "file.txt", ")", "-print"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "command-tree" & EOL),
         "find parenthesized print expression output");

      if Hostkit.Fs.Is_Link (Symlinked) then
         Context.Initialize ("find", Three_Args (Symlinked, "-type", "l"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Test_Contexts.Output (Context) = Symlinked & EOL,
            "find -type l output");
      end if;
   end Test_Find;

   procedure Test_Ls (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Od_File, "A");
      Context.Initialize ("ls", One_Arg (Od_File));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Od_File & EOL,
         "ls prints file operands");

      Ada.Directories.Create_Directory (Ls_Dir);
      Write_File (Hostkit.Fs.Join (Ls_Dir, "visible"), "visible" & EOL);
      Write_File (Hostkit.Fs.Join (Ls_Dir, ".hidden"), "hidden" & EOL);
      Context.Initialize ("ls", One_Arg (Ls_Dir));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "visible" & EOL,
         "ls hides dot-prefixed entries by default");

      Context.Initialize ("ls", Two_Args ("-A", Ls_Dir));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ".hidden" & EOL & "visible" & EOL,
         "ls -A includes hidden entries other than dot and dot-dot");

      Context.Initialize ("ls", Two_Args ("-a", Ls_Dir));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "." & EOL & ".." & EOL & ".hidden" & EOL & "visible" & EOL,
         "ls -a includes dot and dot-dot");

      if Hostkit.Fs.Create_Link ("nowhere", Hostkit.Fs.Join (Ls_Dir, "broken")) then
         Context.Initialize ("ls", One_Arg (Ls_Dir));
         Posix_Tools.Commands.Ls.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = "broken" & EOL & "visible" & EOL,
            "ls lists a symbolic link whose target is missing");
         Ada.Directories.Delete_File (Hostkit.Fs.Join (Ls_Dir, "broken"));
      end if;

      Ada.Directories.Create_Directory (Ls_Other_Dir);
      Write_File (Hostkit.Fs.Join (Ls_Other_Dir, "zeta"), "zeta" & EOL);
      Context.Initialize ("ls", Two_Args (Ls_Dir, Ls_Other_Dir));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Ls_Dir & ":" & EOL
           & "visible" & EOL & EOL
           & Ls_Other_Dir & ":" & EOL
           & "zeta" & EOL,
         "ls labels multiple directory operands");
   end Test_Ls;

   procedure Test_Test (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Prepare_Search_Fixtures;
      Context.Initialize ("test", One_Arg ("value"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test true status");

      Context.Initialize ("test", Two_Args ("-n", "value"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -n status");

      Context.Initialize ("test", Two_Args ("-z", ""));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -z status");

      Context.Initialize ("test", Two_Args ("-e", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -e file status");

      Context.Initialize ("test", Two_Args ("-d", Tree));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -d directory status");

      Context.Initialize ("test", Two_Args ("-f", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -f file status");

      Context.Initialize ("test", Two_Args ("-r", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -r readable file status");

      if Hostkit.Metadata.Permissions_Supported then
         AUnit.Assertions.Assert
           (Hostkit.Metadata.Set_Permissions (Source, 8#600#),
            "test writable source mode setup");
         Context.Initialize ("test", Two_Args ("-w", Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -w status");

         Context.Initialize ("test", Two_Args ("-x", Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "test -x false status");

         AUnit.Assertions.Assert
           (Hostkit.Metadata.Set_Permissions (Source, 8#700#),
            "test executable source mode setup");
         Context.Initialize ("test", Two_Args ("-x", Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         --  Where programs carry a suffix (Windows), a .txt does not run
         --  whatever its mode.
         AUnit.Assertions.Assert
           (Result.Status
            = (if Hostkit.Fs.Executable_Suffix = "" then Posix_Tools.Exit_Status.Success
               else Posix_Tools.Exit_Status.Operational_Failure),
            "test -x status");

         if Hostkit.Metadata.Set_Permissions (Source, 8#4700#) then
            declare
               Available : Boolean;
               Mode      : constant Natural := Hostkit.Metadata.File_Permission_Bits (Source, Available);
            begin
               if Available and then (Mode / 8#4000#) mod 2 = 1 then
                  Context.Initialize ("test", Two_Args ("-u", Source));
                  Posix_Tools.Commands.Test_Command.Run (Context, Result);
                  AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -u status");
               end if;
            end;
         end if;

         if Hostkit.Metadata.Set_Permissions (Source, 8#2700#) then
            declare
               Available : Boolean;
               Mode      : constant Natural := Hostkit.Metadata.File_Permission_Bits (Source, Available);
            begin
               if Available and then (Mode / 8#2000#) mod 2 = 1 then
                  Context.Initialize ("test", Two_Args ("-g", Source));
                  Posix_Tools.Commands.Test_Command.Run (Context, Result);
                  AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -g status");
               end if;
            end;
         end if;

         if Hostkit.Metadata.Set_Permissions (Made, 8#1700#) then
            declare
               Available : Boolean;
               Mode      : constant Natural := Hostkit.Metadata.File_Permission_Bits (Made, Available);
            begin
               if Available and then (Mode / 8#1000#) mod 2 = 1 then
                  Context.Initialize ("test", Two_Args ("-k", Made));
                  Posix_Tools.Commands.Test_Command.Run (Context, Result);
                  AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -k status");
               end if;
            end;
         end if;

         AUnit.Assertions.Assert
           (Hostkit.Metadata.Set_Permissions (Source, 8#700#),
            "test source mode restore");
      end if;

      if Hostkit.Fs.Is_Link (Symlinked) then
         Context.Initialize ("test", Two_Args ("-h", Symlinked));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -h symlink status");

         Context.Initialize ("test", Two_Args ("-L", Symlinked));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -L symlink status");
      end if;

      Context.Initialize ("test", Three_Args (Source, "-ef", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -ef same file status");

      Context.Initialize ("test", Three_Args (Source, "-ef", Other));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -ef different file status");

      Context.Initialize ("test", Three_Args ("alpha", "<", "beta"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test string less-than status");

      Context.Initialize ("test", Three_Args ("z", "<", Character'Val (16#C3#) & Character'Val (16#A6#)));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "test string less-than uses locale collation");

      Context.Initialize ("test", Three_Args ("z", "<", Character'Val (16#C3#) & Character'Val (16#A6#)));
      Test_Contexts.Set_Locale (Context, "en");
      Test_Contexts.Set_Environment_Value (Context, "LC_COLLATE", "da");
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "test LC_COLLATE overrides context locale");

      Context.Initialize ("test", Three_Args ("beta", ">", "alpha"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test string greater-than status");

      Context.Initialize ("test", Three_Args ("alpha", ">", "beta"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test string greater-than false status");

      Context.Initialize ("test", Two_Args ("-r", No_Create));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -r missing file status");

      Context.Initialize ("test", Two_Args ("-s", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -s nonempty file status");

      Context.Initialize ("test", Two_Args ("-s", Empty));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -s empty file status");

      Context.Initialize ("test", Two_Args ("-s", No_Create));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -s missing file status");

      Context.Initialize ("test", Two_Args ("-b", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -b regular file status");

      Context.Initialize ("test", Two_Args ("-c", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -c regular file status");

      Context.Initialize ("test", Two_Args ("-p", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -p regular file status");

      Context.Initialize ("test", Two_Args ("-S", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -S regular file status");

      if Hostkit.Fs.Special_File_Info_Of (Cp_FIFO_Source).Kind = Hostkit.Fs.FIFO then
         Context.Initialize ("test", Two_Args ("-p", Cp_FIFO_Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "test -p FIFO status");

         Context.Initialize ("test", Two_Args ("-S", Cp_FIFO_Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "test -S excludes FIFO status");
      end if;

      if Hostkit.Fs.Special_File_Info_Of (Cp_Socket_Source).Kind = Hostkit.Fs.Socket then
         Context.Initialize ("test", Two_Args ("-S", Cp_Socket_Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "test -S socket status");

         Context.Initialize ("test", Two_Args ("-p", Cp_Socket_Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "test -p excludes socket status");
      end if;

      if Ada.Directories.Exists ("/dev/null")
        and then Hostkit.Fs.Special_File_Info_Of ("/dev/null").Kind = Hostkit.Fs.Character_Device
      then
         Context.Initialize ("test", Two_Args ("-c", "/dev/null"));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "test -c character device status");

         Context.Initialize ("test", Two_Args ("-b", "/dev/null"));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "test -b excludes character device status");
      end if;

      Context.Initialize ("test", Two_Args ("-t", "0"));
      Test_Contexts.Set_Standard_Input_Is_Terminal (Context, True);
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -t stdin status");

      Context.Initialize ("test", Two_Args ("-t", "1"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -t stdout status");

      Context.Initialize ("test", Two_Args ("-t", "2"));
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, True);
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -t stderr status");

      Context.Initialize ("test", Two_Args ("-t", "9"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -t unsupported fd status");

      Context.Initialize ("test", Three_Args ("42", "-eq", "42"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -eq status");

      Context.Initialize ("test", Three_Args ("-2", "-lt", "+3"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test signed -lt status");

      Context.Initialize ("test", Three_Args ("!", "-n", ""));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test negated unary status");

      Context.Initialize ("test", Four_Args ("!", "1", "=", "2"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test negated equality status");

      Context.Initialize ("test", Four_Args ("!", "2", "-gt", "1"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test negated numeric status");

      Context.Initialize ("test", Five_Args ("-n", "x", "-a", "-z", ""));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test and status");

      Context.Initialize ("test", Three_Args ("", "-o", "fallback"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test or status");

      Context.Initialize ("test", Five_Args ("", "-o", "", "-a", "x"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test and precedence status");

      Context.Initialize ("test", Six_Args ("!", "x", "-o", "", "-a", "y"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test negated compound status");

      Context.Initialize ("test", Three_Args ("(", "value", ")"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test parenthesized status");

      Context.Initialize ("test", Three_Args ("abc", "-eq", "0"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Error_Output (Context) = "test: 'abc': integer expression expected" & EOL,
         "test diagnoses a non-integer operand of a numeric comparison");

      Context.Initialize ("test", Two_Args ("(", "value"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "test rejects unbalanced opening parenthesis");

      Context.Initialize ("test", Two_Args ("value", ")"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "test rejects unbalanced closing parenthesis");

      Context.Initialize ("test", Two_Args ("value", "-a"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "test rejects dangling and operator");

      Context.Initialize ("test", Three_Args ("a", "-bad", "b"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "test rejects unknown binary operator");
   end Test_Test;

   procedure Test_Touch (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Source, "copy-data");
      Context.Initialize ("touch", One_Arg (Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert (Ada.Directories.Exists (Touched), "touch created file");

      Write_File (Touched, "touch-data");
      Context.Initialize ("touch", One_Arg (Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "touch existing status");
      Context.Initialize ("cat", One_Arg (Touched));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "touch-data", "touch preserves existing data");

      Context.Initialize ("touch", Two_Args ("-c", No_Create));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (No_Create),
         "touch -c leaves missing file absent");

      Context.Initialize ("touch", Two_Args ("-am", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "touch -am status");

      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (Touched,
         GNAT.OS_Lib.GM_Time_Of
           (2026,
            8,
            12,
            10,
            0,
            0));
      Context.Initialize ("touch", Three_Args ("-a", "-t202608121540.11", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (10 * 3_600))),
         "touch -a leaves modification timestamp unchanged");
      declare
         --  touch -t names a local time: 15:40:11 at this host's offset.
         Expected_Access : constant Ada.Calendar.Time :=
           Ada.Calendar.Formatting.Time_Of
             (2026, 8, 12, 15, 40, 11,
              Time_Zone => Ada.Calendar.Time_Zones.UTC_Time_Offset (Ada.Calendar.Time_Of (2026, 8, 12)));
         Available : Boolean;
         Accessed  : constant Ada.Calendar.Time := Hostkit.Metadata.File_Access_Time (Touched, Available);
      begin
         if Available then
            AUnit.Assertions.Assert
              (Time_Near (Accessed, Expected_Access),
               "touch -a applies explicit access timestamp: got "
               & Ada.Calendar.Formatting.Image (Accessed) & " expected "
               & Ada.Calendar.Formatting.Image (Expected_Access) & " offset"
               & Ada.Calendar.Time_Zones.UTC_Time_Offset (Ada.Calendar.Time_Of (2026, 8, 12))'Image);
         end if;
      end;

      Context.Initialize ("touch", Three_Args ("-m", "-t202608121540.11", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 40 * 60 + 11))),
         "touch -m applies explicit modification timestamp");

      Context.Initialize ("touch", Three_Args ("-r", Source, Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near (Ada.Directories.Modification_Time (Touched), Ada.Directories.Modification_Time (Source)),
         "touch -r status and timestamp");

      Context.Initialize ("touch", Two_Args ("-r" & Source, Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near (Ada.Directories.Modification_Time (Touched), Ada.Directories.Modification_Time (Source)),
         "touch compact -r status and timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202608121530.45", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 30 * 60 + 45))),
         "touch -t status and timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202608121531", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 31 * 60))),
         "touch -t explicit century minute timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202608121531.46", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 31 * 60 + 46))),
         "touch -t explicit century seconds timestamp");

      Context.Initialize ("touch", Two_Args ("-t08121530", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of
              (Ada.Calendar.Year (Ada.Calendar.Clock), 8, 12, Duration (15 * 3_600 + 30 * 60))),
         "touch compact -t status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "202608121631.05", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 31 * 60 + 5))),
         "touch -d status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d202608121632.06", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 32 * 60 + 6))),
         "touch compact -d status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12T16:33:07", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 33 * 60 + 7))),
         "touch -d ISO date-time status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d2026-08-12 16:34:08", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 34 * 60 + 8))),
         "touch compact -d spaced date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12T16:35:09Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 35 * 60 + 9))),
         "touch -d UTC date-time status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d2026-08-12 16:36:10Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 36 * 60 + 10))),
         "touch compact -d UTC spaced date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12T16:35:09+02:30", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (14 * 3_600 + 5 * 60 + 9))),
         "touch -d positive numeric offset status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12 16:36:10-0330", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (20 * 3_600 + 6 * 60 + 10))),
         "touch -d negative numeric offset status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, 0.0)),
         "touch -d date-only status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d2026-08-13T17:45", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 45 * 60))),
         "touch compact -d minute-precision status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13T17:46Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 46 * 60))),
         "touch -d UTC minute-precision status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13T17:47+02:30", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (15 * 3_600 + 17 * 60))),
         "touch -d positive offset minute-precision status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026/08/13 17:48:11", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 48 * 60 + 11))),
         "touch -d slash date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13t17:49:12Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 49 * 60 + 12))),
         "touch -d lowercase-t UTC date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13T17:50:13.987+02:30", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (15 * 3_600 + 20 * 60 + 13))),
         "touch -d fractional offset date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "Aug 13 2026 17:51:14", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 51 * 60 + 14))),
         "touch -d abbreviated month-name date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "August 13, 2026 17:52", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 52 * 60))),
         "touch -d full month-name minute timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "Sep 14 2026", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 9, 14, 0.0)),
         "touch -d month-name date-only timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "13 Aug 2026 17:53:16", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 53 * 60 + 16))),
         "touch -d day-first abbreviated month-name timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "14 September 2026", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 9, 14, 0.0)),
         "touch -d day-first full month-name date-only timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "noon", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      declare
         Year : Ada.Calendar.Year_Number;
         Month : Ada.Calendar.Month_Number;
         Day : Ada.Calendar.Day_Number;
         Seconds : Duration;
      begin
         Ada.Calendar.Split (Ada.Calendar.Clock, Year, Month, Day, Seconds);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Time_Near
              (Ada.Directories.Modification_Time (Touched),
               Ada.Calendar.Time_Of (Year, Month, Day, Duration (12 * 3_600))),
            "touch -d noon timestamp");
      end;

      Context.Initialize ("touch", Three_Args ("-d", "2 hours ago", Touched));
      declare
         Expected : constant Ada.Calendar.Time := Ada.Calendar.Clock - Duration (2 * 3_600);
      begin
         Posix_Tools.Commands.Touch.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Time_Near (Ada.Directories.Modification_Time (Touched), Expected),
            "touch -d relative hours ago timestamp");
      end;

      Context.Initialize ("touch", Three_Args ("-d", "+1 day", Touched));
      declare
         Expected : constant Ada.Calendar.Time := Ada.Calendar.Clock + 86_400.0;
      begin
         Posix_Tools.Commands.Touch.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Time_Near (Ada.Directories.Modification_Time (Touched), Expected),
            "touch -d relative plus day timestamp");
      end;

      Context.Initialize ("touch", Three_Args ("-d", "bad", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid -d timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "Nope 13 2026 17:51:14", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid month-name -d timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "32 Aug 2026 17:51:14", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid day-first month-name -d timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202613121530", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid timestamp");

      Context.Initialize ("touch", Three_Args ("-r", No_Create, Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "touch missing reference status");

      Context.Initialize ("touch", Two_Args ("-ac", No_Create));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (No_Create),
         "touch grouped -ac leaves missing file absent");
   end Test_Touch;

end Command_Tests.Surface_Smoke.Metadata;
