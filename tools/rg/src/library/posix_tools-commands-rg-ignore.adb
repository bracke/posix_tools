with Posix_Tools.Arguments;
with Posix_Tools.Host_Adapters.File_System;
with Version.Repository;

package body Posix_Tools.Commands.Rg.Ignore is
   use Ada.Strings.Unbounded;
   use type Version.Ignore.Source_Load_Status;

   package File_System renames Posix_Tools.Host_Adapters.File_System;

   function Relative_To (Ancestor, Path : String) return String;
   function Rule_Root (Root : String; Use_Parent : Boolean) return String;

   procedure Add_Directory
     (Self               : in out Policy;
      Directory          : String;
      Relative_Directory : String;
      Outcome            : in out Load_Outcome);

   function Relative_To (Ancestor, Path : String) return String is
      First : Positive := Ancestor'Length + 1;
   begin
      if Path = Ancestor then
         return "";
      end if;
      if First <= Path'Last
        and then (Path (First) = '/' or else Path (First) = '\')
      then
         First := First + 1;
      end if;
      declare
         Result : String := Path (First .. Path'Last);
      begin
         for Item of Result loop
            if Item = '\' then
               Item := '/';
            end if;
         end loop;
         return Result;
      end;
   end Relative_To;

   function Rule_Root (Root : String; Use_Parent : Boolean) return String is
      Full : constant String := File_System.Full_Name (Root);
   begin
      declare
         Git : constant String := Version.Repository.Resolve_Git_Dir (Full);
      begin
         if Git'Length > 0 then
            return File_System.Full_Name
              (Version.Repository.Root_Path (Version.Repository.Open_Git_Dir (Git)));
         end if;
      end;

      if not Use_Parent then
         return Full;
      end if;

      declare
         Current : Unbounded_String := To_Unbounded_String (Full);
      begin
         loop
            declare
               Parent : constant String :=
                 File_System.Containing_Directory (To_String (Current));
            begin
               exit when Parent'Length = 0 or else Parent = To_String (Current);
               Current := To_Unbounded_String (Parent);
            end;
         end loop;
         return To_String (Current);
      end;
   end Rule_Root;

   procedure Add_Directory
     (Self               : in out Policy;
      Directory          : String;
      Relative_Directory : String;
      Outcome            : in out Load_Outcome)
   is
      procedure Add
        (Name       : String;
         Kind       : Version.Ignore.Rule_Source_Kind;
         Precedence : Integer;
         Enabled    : Boolean);

      procedure Add
        (Name       : String;
         Kind       : Version.Ignore.Rule_Source_Kind;
         Precedence : Integer;
         Enabled    : Boolean)
      is
         Result : Version.Ignore.Source_Load_Result;
      begin
         if not Enabled then
            return;
         end if;

         Version.Ignore.Add_File
           (Builder    => Self.Builder,
            Path       => File_System.Child_Path (Directory, Name),
            Base_Dir   => Relative_Directory,
            Kind       => Kind,
            Precedence => Precedence,
            Result     => Result);

         if Result.Status = Version.Ignore.Source_Loaded then
            Outcome.Sources_Loaded := Outcome.Sources_Loaded + 1;
            Outcome.Rules_Added := Outcome.Rules_Added + Result.Rules_Added;
         elsif Result.Status not in
           Version.Ignore.Source_Not_Found
           | Version.Ignore.Source_Skipped_Symbolic_Link
         then
            Outcome.Had_Error := True;
         end if;
      end Add;
   begin
      Add (".gitignore", Version.Ignore.Gitignore_Source, 10, Self.Gitignore);
      Add (".ignore", Version.Ignore.Ignore_Source, 20, Self.Ignore_File);
      Add (".rgignore", Version.Ignore.Rgignore_Source, 30, Self.Rgignore);
   end Add_Directory;

   procedure Initialize
     (Self             : in out Policy;
      Root             : String;
      Case_Insensitive : Boolean := False;
      Use_Gitignore    : Boolean := True;
      Use_Ignore       : Boolean := True;
      Use_Rgignore     : Boolean := True;
      Use_Parent       : Boolean := True)
   is
      Full_Root   : constant String := File_System.Full_Name (Root);
      Rules_Root  : constant String := Rule_Root (Root, Use_Parent);
      Directories : Posix_Tools.Arguments.Vector;
   begin
      Version.Ignore.Initialize (Self.Builder, Rules_Root, Case_Insensitive);
      if Use_Gitignore then
         Version.Ignore.Add_Repository_Excludes (Self.Builder, Full_Root);
      end if;
      Self.Gitignore := Use_Gitignore;
      Self.Ignore_File := Use_Ignore;
      Self.Rgignore := Use_Rgignore;
      Self.Query_Prefix := To_Unbounded_String (Relative_To (Rules_Root, Full_Root));
      Self.Initial_Load := (others => <>);

      if Use_Parent and then Full_Root /= Rules_Root then
         declare
            Current : Unbounded_String := To_Unbounded_String (Full_Root);
         begin
            loop
               declare
                  Parent : constant String :=
                    File_System.Containing_Directory (To_String (Current));
               begin
                  exit when Parent'Length = 0 or else Parent = To_String (Current);
                  Directories.Prepend (Parent);
                  exit when Parent = Rules_Root;
                  Current := To_Unbounded_String (Parent);
               end;
            end loop;
         end;

         for Directory of Directories loop
            Add_Directory
              (Self,
               Directory,
               Relative_To (Rules_Root, Directory),
               Self.Initial_Load);
         end loop;
      end if;

      Self.Rules := Version.Ignore.Snapshot (Self.Builder);
      Self.Is_Initialized := True;
   end Initialize;

   procedure Enter_Directory
     (Self               : in out Policy;
      Directory          : String;
      Relative_Directory : String;
      Outcome            : out Load_Outcome)
   is
   begin
      Outcome := Self.Initial_Load;
      Self.Initial_Load := (others => <>);
      if not Self.Is_Initialized then
         Outcome.Had_Error := True;
         return;
      end if;

      declare
         Base : constant String :=
           (if Length (Self.Query_Prefix) = 0
            then Relative_Directory
            elsif Relative_Directory'Length = 0
            then To_String (Self.Query_Prefix)
            else To_String (Self.Query_Prefix) & "/" & Relative_Directory);
      begin
         Add_Directory (Self, Directory, Base, Outcome);
      end;
      Self.Rules := Version.Ignore.Snapshot (Self.Builder);
   end Enter_Directory;

   function Evaluate
     (Self          : Policy;
      Relative_Path : String;
      Is_Directory  : Boolean) return Decision
   is
      Query : constant String :=
        (if Length (Self.Query_Prefix) = 0
         then Relative_Path
         else To_String (Self.Query_Prefix) & "/" & Relative_Path);
      Match : constant Version.Ignore.Match_Result :=
        Version.Ignore.Match_Within
          (Self.Rules, Query, Is_Directory, To_String (Self.Query_Prefix));
   begin
      return (Is_Ignored => Match.Is_Ignored, Match => Match);
   end Evaluate;
end Posix_Tools.Commands.Rg.Ignore;
