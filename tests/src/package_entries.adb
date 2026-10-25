with Ada.Containers.Generic_Array_Sort;
with Ada.Strings.Unbounded;
with Project_Tools.Files;
with Tooling_Support;

procedure Package_Entries is
   use Ada.Strings.Unbounded;
   use type Project_Tools.Files.Path_List;

   function "+" (Text : String) return Unbounded_String renames To_Unbounded_String;

   procedure Sort is new Ada.Containers.Generic_Array_Sort
     (Index_Type   => Positive,
      Element_Type => Unbounded_String,
      Array_Type   => Project_Tools.Files.Path_List);

   Root_Files : constant Project_Tools.Files.Path_List :=
     [+".gitattributes", +"alire.toml", +"posix_tools.gpr", +"README.md", +"LICENSE", +"CHANGELOG.md",
      +"SECURITY.md"];

   Trees : constant Project_Tools.Files.Name_List :=
     [+".github", +"common", +"docs", +"fixtures", +"generated", +"src", +"tests", +"tools"];

   --  Directories .gitignore keeps out, wherever they occur, and the test
   --  scratch directory under generated.
   Skipped_Directories : constant Project_Tools.Files.Name_List :=
     [+"alire", +"bin", +"obj", +"lib", +"config", +"dist", +"test-work"];

   Written_By_Packaging : constant Project_Tools.Files.Path_List :=
     [+"generated/package-files.txt", +"generated/package-manifest.txt", +"generated/release-checksums.txt"];

   function Ends_With (Text, Suffix : String) return Boolean is
     (Text'Length >= Suffix'Length and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix);

   --  The file patterns .gitignore keeps out.
   function Is_Ignored_Name (Path : String) return Boolean is
      Slash : Natural := Path'First - 1;
   begin
      for I in Path'Range loop
         if Path (I) = '/' then
            Slash := I;
         end if;
      end loop;

      declare
         Name : constant String := Path (Slash + 1 .. Path'Last);
      begin
         return Ends_With (Name, ".ali") or else Ends_With (Name, ".o") or else Ends_With (Name, ".lexch")
           or else Ends_With (Name, ".bexch") or else Ends_With (Name, ".cswi") or else Ends_With (Name, ".stdout")
           or else Ends_With (Name, ".stderr") or else Ends_With (Name, "~")
           or else (Name'Length >= 2 and then Name (Name'First .. Name'First + 1) = ".#")
           or else Name = ".DS_Store" or else Name = "Thumbs.db";
      end;
   end Is_Ignored_Name;

   function Is_Written_By_Packaging (Path : String) return Boolean is
   begin
      for Item of Written_By_Packaging loop
         if To_String (Item) = Path then
            return True;
         end if;
      end loop;

      return False;
   end Is_Written_By_Packaging;

   function Tree_Files (Index : Positive) return Project_Tools.Files.Path_List is
   begin
      if Index > Trees'Last then
         return [1 .. 0 => <>];
      end if;

      return
        Project_Tools.Files.List_Tree
          (Project_Tools.Files.Join (Tooling_Support.Root, To_String (Trees (Index))),
           Skip_Entries => Skipped_Directories)
        & Tree_Files (Index + 1);
   end Tree_Files;

   Prefix : constant String := Tooling_Support.Root & "/";
   Found  : Project_Tools.Files.Path_List := Root_Files & Tree_Files (Trees'First);
begin
   for Item of Found loop
      declare
         Path : constant String := To_String (Item);
      begin
         if Path'Length > Prefix'Length and then Path (Path'First .. Path'First + Prefix'Length - 1) = Prefix then
            Item := +Path (Path'First + Prefix'Length .. Path'Last);
         end if;
      end;
   end loop;

   Sort (Found);

   for Item of Found loop
      if not Is_Ignored_Name (To_String (Item)) and then not Is_Written_By_Packaging (To_String (Item)) then
         Add_Entry (To_String (Item));
      end if;
   end loop;
end Package_Entries;
