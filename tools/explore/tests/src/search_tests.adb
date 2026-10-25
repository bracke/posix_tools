with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Explore.Model;
with Explore.Search;
with Posix_Tools.File_Operations.Listing;
with Posix_Tools.Host_Adapters.File_System;

package body Search_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Listing renames Posix_Tools.File_Operations.Listing;
   package Model renames Explore.Model;
   package Search renames Explore.Search;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Model.Pane_State;

   function Root return String is (Ada.Directories.Current_Directory & "/obj/search-fixture");

   --  Every result of searching Root for Pattern by Kind, as sorted names.
   function Run (Pattern : String; Kind : Search.Search_Kind; Hidden : Boolean := False) return String;

   procedure Write (Name, Text : String);

   function Run (Pattern : String; Kind : Search.Search_Kind; Hidden : Boolean := False) return String is
      Board   : aliased Search.Board;
      Worker  : Search.Worker (Board'Access);
      Outcome : Search.Progress;
      Found   : Boolean;
      Names   : Model.Name_Sets.Set;
      Result  : Unbounded.Unbounded_String;
   begin
      Board.Submit
        ((Unbounded.To_Unbounded_String (Root), Unbounded.To_Unbounded_String (Pattern), Kind, Hidden, 7));

      for Attempt in 1 .. 500 loop
         Board.Collect (Outcome, Found);

         if Found then
            for Item of Outcome.Found loop
               Names.Include (Unbounded.To_String (Item.Name));
            end loop;

            exit when Outcome.Finished;
         end if;

         delay 0.01;
      end loop;

      AUnit.Assertions.Assert (Outcome.Finished, "the search ends: " & Pattern);
      Board.Shut_Down;

      for Name of Names loop
         Unbounded.Append (Result, (if Unbounded.Length (Result) > 0 then " " else "") & Name);
      end loop;

      return Unbounded.To_String (Result);
   end Run;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("search:matching", Test_Matching'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("search:walk", Test_Walk'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("search:pane", Test_Search_Pane'Access));
      return Result;
   end Suite;

   procedure Test_Matching (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert (Search.Name_Matches ("read", "README.md"), "a substring, regardless of case");
      AUnit.Assertions.Assert (not Search.Name_Matches ("xyz", "README.md"), "no substring");
      AUnit.Assertions.Assert (Search.Name_Matches ("*.md", "README.md"), "a glob");
      AUnit.Assertions.Assert (not Search.Name_Matches ("*.md", "notes.txt"), "a glob that does not match");
      AUnit.Assertions.Assert (Search.Name_Matches ("file?.[ch]", "file1.c"), "? and a class");
      AUnit.Assertions.Assert (Search.Name_Matches ("*.JPG", "x.jpg"), "a glob, regardless of case too");
   end Test_Matching;

   procedure Test_Search_Pane (T : in out Fixture) is
      pragma Unreferenced (T);
      Browser    : Model.Browser;
      Generation : Natural;
      Found      : Listing.Entry_Vectors.Vector;
   begin
      Model.Open (Browser, "/home/user");
      Model.Deliver
        (Browser, Model.Current_Pane, Browser.Panes (Model.Current_Pane).Generation, Found, Readable => True);
      Model.Begin_Search (Browser, "/home/user", "*.md", Generation);
      AUnit.Assertions.Assert
        (Model.Is_Searching (Browser) and then Browser.Panes (Model.Current_Pane).State = Model.Loading
         and then not Browser.Panes (Model.Current_Pane).Pending,
         "the current pane waits for results, and is not read as a directory");

      Found.Append (Listing.Listed_Entry'(Name => Unbounded.To_Unbounded_String ("docs/a.md"), others => <>));
      Model.Add_Results (Browser, Generation, Found, Finished => False);
      Model.Add_Results (Browser, Generation + 1, Found, Finished => False);
      AUnit.Assertions.Assert
        (Model.Shown_Count (Browser.Panes (Model.Current_Pane)) = 1, "results of another search are dropped");
      AUnit.Assertions.Assert
        (Model.Selected_Path (Browser.Panes (Model.Current_Pane)) = "/home/user/docs/a.md",
         "a result is a path below the root");

      Model.Reload (Browser, Model.Current_Pane);
      AUnit.Assertions.Assert (not Browser.Panes (Model.Current_Pane).Pending, "results are never read again");
      Model.Add_Results (Browser, Generation, Found, Finished => True);
      AUnit.Assertions.Assert (Browser.Panes (Model.Current_Pane).State = Model.Loaded, "finished");

      Model.Leave (Browser);
      AUnit.Assertions.Assert
        (not Model.Is_Searching (Browser)
         and then Ada.Strings.Unbounded.To_String (Browser.Panes (Model.Current_Pane).Path) = "/home/user",
         "leaving results goes back to the directory searched");
   end Test_Search_Pane;

   procedure Test_Walk (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      if FS.Exists (Root) then
         Ada.Directories.Delete_Tree (Root);
      end if;

      Ada.Directories.Create_Path (Root & "/docs/deep");
      Ada.Directories.Create_Path (Root & "/.hidden");
      Write (Root & "/README.md", "Hello World");
      Write (Root & "/docs/guide.md", "nothing here");
      Write (Root & "/docs/deep/notes.txt", "the needle is HERE");
      Write (Root & "/.hidden/secret.md", "needle");
      Write (Root & "/blob.bin", "needle" & Character'Val (0));

      --  A link back up the tree must not make the walk go round for ever.
      AUnit.Assertions.Assert (FS.Create_Link ("..", Root & "/docs/up"), "fixture link");

      AUnit.Assertions.Assert (Run ("*.md", Search.By_Name) = "README.md docs/guide.md", "names, hidden left out");
      AUnit.Assertions.Assert
        (Run ("*.md", Search.By_Name, Hidden => True) = ".hidden/secret.md README.md docs/guide.md",
         "hidden too, when shown");
      AUnit.Assertions.Assert (Run ("deep", Search.By_Name) = "docs/deep", "directories match by name too");
      AUnit.Assertions.Assert
        (Run ("NEEDLE", Search.By_Content) = "docs/deep/notes.txt",
         "contents, regardless of case; binary files and hidden ones left out");

      AUnit.Assertions.Assert (FS.Delete_Link (Root & "/docs/up"), "fixture link removed");
      Ada.Directories.Delete_Tree (Root);
   end Test_Walk;

   procedure Write (Name, Text : String) is
      Ok : Boolean;
   begin
      FS.Write_File (Name, Text, Append_Mode => False, Ok => Ok);
      AUnit.Assertions.Assert (Ok, "fixture written: " & Name);
   end Write;
end Search_Tests;
