with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with E2E_Files;
with GNAT.OS_Lib;

package body E2E_Bootstrap is
   use type GNAT.OS_Lib.String_Access;

   LF : constant Character := Character'Val (10);
   Crate_Root_Environment : constant String :=
     "POSIX_TOOLS_E2E_CRATE_ROOT";
   Run_Root_Environment : constant String := "POSIX_TOOLS_E2E_RUN_ROOT";

   function Required_Environment
     (Name, Description : String) return String;

   function Crate_Root return String is
     (Required_Environment (Crate_Root_Environment, "crate root"));

   function Explore_Binary return String is
     (GNAT.OS_Lib.Normalize_Pathname
        (Crate_Root & "/../bin/explore", Resolve_Links => True));

   function Launcher_Path return String is (Run_Root & "/launcher.sh");

   procedure Prepare (Root : String) is
      Program : constant String := Program_Path;
      Crate   : constant String :=
        Ada.Directories.Containing_Directory
          (Ada.Directories.Containing_Directory (Program));
   begin
      if Root = "" then
         raise Program_Error with "could not create the E2E run directory";
      end if;

      Ada.Environment_Variables.Set (Crate_Root_Environment, Crate);
      Ada.Environment_Variables.Set (Run_Root_Environment, Root);
      Ada.Directories.Create_Path (Root);
      E2E_Files.Write
        (Launcher_Path,
         "#!/bin/sh" & LF
         & "request=" & Quoted (Request_Path) & LF
         & "claimed=""$request.$$""" & LF
         & "attempts=500" & LF
         & "while ! mv ""$request"" ""$claimed"" 2>/dev/null; do" & LF
         & "  attempts=$((attempts - 1))" & LF
         & "  [ ""$attempts"" -gt 0 ] || exit 125" & LF
         & "  sleep 0.01" & LF
         & "done" & LF
         & "exec /bin/sh ""$claimed""" & LF);
      GNAT.OS_Lib.Set_Executable (Launcher_Path);
   end Prepare;

   function Program_Path return String is
      Name  : constant String := Ada.Command_Line.Command_Name;
      Found : GNAT.OS_Lib.String_Access :=
        (if Ada.Strings.Fixed.Index (Name, "/") > 0
         then new String'(Name)
         else GNAT.OS_Lib.Locate_Exec_On_Path (Name));
   begin
      if Found = null then
         raise Program_Error with "cannot locate " & Name;
      end if;

      begin
         declare
            Path : constant String :=
              GNAT.OS_Lib.Normalize_Pathname
                (Found.all, Resolve_Links => True);
         begin
            GNAT.OS_Lib.Free (Found);
            return Path;
         end;
      exception
         when others =>
            --  intentional terminal exception barrier
            GNAT.OS_Lib.Free (Found);
            raise;
      end;
   end Program_Path;

   function Quoted (Text : String) return String is
      Quote  : constant Character := Character'Val (39);
      Result : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.To_Unbounded_String ([Quote]);
   begin
      for C of Text loop
         if C = Quote then
            Ada.Strings.Unbounded.Append
              (Result, Quote & "\" & Quote & Quote);
         else
            Ada.Strings.Unbounded.Append (Result, C);
         end if;
      end loop;

      Ada.Strings.Unbounded.Append (Result, Quote);
      return Ada.Strings.Unbounded.To_String (Result);
   end Quoted;

   function Request_Path return String is (Run_Root & "/next-session.sh");

   function Required_Environment
     (Name, Description : String) return String
   is
      Value : constant String :=
        Ada.Environment_Variables.Value (Name, "");
   begin
      if Value = "" then
         raise Program_Error with
           "E2E bootstrap " & Description
           & " is unavailable; call E2E_Bootstrap.Prepare first";
      end if;
      return Value;
   end Required_Environment;

   function Run_Root return String is
     (Required_Environment (Run_Root_Environment, "run root"));

end E2E_Bootstrap;
