with Ada.Exceptions;
with Ada.Real_Time;
with Ada.Streams;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Rg.Ignore;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Rg_Arithmetic;
with Posix_Tools.Rg_Parallel;
with System.Multiprocessors;

package body Posix_Tools.Commands.Rg.Traversal is
   package File_System renames Posix_Tools.Host_Adapters.File_System;
   package Ignore renames Posix_Tools.Commands.Rg.Ignore;

   use type File_System.Entry_Kind;
   use type File_System.Entry_Identity;
   use type File_System.Listed_Kind;
   use type Ada.Calendar.Time;
   use type Ada.Real_Time.Time;

   Max_Pending_Bytes : constant Natural := 64 * 1024 * 1024;
   function Added (Left, Right : Natural) return Natural renames
     Posix_Tools.Rg_Arithmetic.Saturating_Add;

   function Is_Metadata_Sort (Order : Sort_Order) return Boolean is
     (Order in Modified_Ascending | Modified_Descending
       | Accessed_Ascending | Accessed_Descending
       | Created_Ascending | Created_Descending);

   function Effective_Worker_Count
     (Threads : Natural;
      Sort    : Sort_Order) return Positive
   is
      Requested : constant Natural :=
        (if Threads = 0
         then Natural (System.Multiprocessors.Number_Of_CPUs)
         else Threads);
   begin
      return
        Posix_Tools.Rg_Parallel.Bounded_Worker_Count
          (Requested, Sorted => Sort /= Unsorted);
   end Effective_Worker_Count;

   procedure Add_File
     (Context        : in out Posix_Tools.Commands.Contexts.Context'Class;
      Files          : in out File_Set;
      Name           : String;
      Label          : String;
      Standard_Input : Boolean;
      Outcome        : in out Traversal_Outcome;
      Recursive      : Boolean := False)
   is
      Required : Natural := 0;
   begin
      if Files.Failed then
         Outcome.Input_Error := True;
      elsif Name'Length > Max_Pending_Bytes
        or else Label'Length > Max_Pending_Bytes - Name'Length
        or else Name'Length + Label'Length > Max_Pending_Bytes - Files.Bytes
      then
         if not Files.Failed then
            Posix_Tools.Commands.Rg.Diagnostics.Error_Line
              (Context, "sorted path set exceeds the 64 MiB limit");
         end if;
         Files.Failed := True;
         Outcome.Input_Error := True;
      else
         Required := Name'Length + Label'Length;
         Files.Items.Append
           (File_Record'
              (Name           => Ada.Strings.Unbounded.To_Unbounded_String (Name),
               Label          => Ada.Strings.Unbounded.To_Unbounded_String (Label),
               Standard_Input => Standard_Input,
               Recursive      => Recursive,
               Sequence       => Natural (Files.Items.Length) + 1,
               others         => <>));
         Files.Bytes := Files.Bytes + Required;
      end if;
   end Add_File;

   function Ascending_Before (Left, Right : File_Record) return Boolean is
   begin
      if Left.Key_Available /= Right.Key_Available then
         return Left.Key_Available;
      elsif Left.Key_Available and then Left.Key /= Right.Key then
         return Left.Key < Right.Key;
      else
         return Left.Sequence < Right.Sequence;
      end if;
   end Ascending_Before;

   function Descending_Before (Left, Right : File_Record) return Boolean is
   begin
      if Left.Key_Available /= Right.Key_Available then
         return not Left.Key_Available;
      elsif Left.Key_Available and then Left.Key /= Right.Key then
         return Left.Key > Right.Key;
      else
         return Left.Sequence < Right.Sequence;
      end if;
   end Descending_Before;

   package Ascending_Sorting is new File_Vectors.Generic_Sorting
     ("<" => Ascending_Before);
   package Descending_Sorting is new File_Vectors.Generic_Sorting
     ("<" => Descending_Before);

   function File_Count (Files : File_Set) return Natural is
     (Natural (Files.Items.Length));

   function Files_Ready (Files : File_Set) return Boolean is (not Files.Failed);

   function File_Name (Files : File_Set; Index : Positive) return String is
     (Ada.Strings.Unbounded.To_String (Files.Items.Element (Index).Name));

   function File_Label (Files : File_Set; Index : Positive) return String is
     (Ada.Strings.Unbounded.To_String (Files.Items.Element (Index).Label));

   generic
      with procedure Process_File
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Name    : String;
         Label   : String;
         Outcome : in out Traversal_Outcome);
   procedure Walk_Tree
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Root    : String;
      Options : Discovery_Options;
      Outcome : out Traversal_Outcome);

   procedure Walk_Tree
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Root    : String;
      Options : Discovery_Options;
      Outcome : out Traversal_Outcome)
   is
      Policy : Ignore.Policy;

      type Directory_Key is record
         Identity  : File_System.Entry_Identity;
         Canonical : Ada.Strings.Unbounded.Unbounded_String;
         Label     : Ada.Strings.Unbounded.Unbounded_String;
      end record;

      package Directory_Key_Vectors is new Ada.Containers.Vectors
        (Index_Type   => Positive,
         Element_Type => Directory_Key);

      Ancestors : Directory_Key_Vectors.Vector;
      Root_Device : Long_Long_Integer := 0;
      Root_Device_Available : Boolean := False;

      type Pending_File is record
         Name  : Ada.Strings.Unbounded.Unbounded_String;
         Label : Ada.Strings.Unbounded.Unbounded_String;
      end record;

      package Pending_File_Vectors is new Ada.Containers.Vectors
        (Index_Type   => Positive,
         Element_Type => Pending_File);

      function Before (Left, Right : Pending_File) return Boolean;

      package Pending_File_Sorting is new Pending_File_Vectors.Generic_Sorting
        ("<" => Before);

      Pending       : Pending_File_Vectors.Vector;
      Pending_Bytes : Natural := 0;
      Collection_Failed : Boolean := False;

      function Before (Left, Right : Pending_File) return Boolean is
         use Ada.Strings.Unbounded;
      begin
         return Left.Label < Right.Label
           or else (Left.Label = Right.Label and then Left.Name < Right.Name);
      end Before;

      procedure Select_File (Name, Label : String);

      procedure Select_File (Name, Label : String) is
         Required : Natural := 0;
      begin
         Posix_Tools.Commands.Rg.Diagnostics.Trace
           (Context, Options.Diagnostics, "rg::walk", "selected " & Label);
         if Options.Sort = Unsorted or else Is_Metadata_Sort (Options.Sort) then
            Process_File (Context, Name, Label, Outcome);
         elsif Name'Length > Max_Pending_Bytes
           or else Label'Length > Max_Pending_Bytes - Name'Length
           or else Name'Length + Label'Length > Max_Pending_Bytes - Pending_Bytes
         then
            Posix_Tools.Commands.Rg.Diagnostics.Error_Line
              (Context, "sorted path set exceeds the 64 MiB limit");
            Outcome.Input_Error := True;
            Collection_Failed := True;
         else
            Required := Name'Length + Label'Length;
            Pending.Append
              (Pending_File'
                 (Name  => Ada.Strings.Unbounded.To_Unbounded_String (Name),
                  Label => Ada.Strings.Unbounded.To_Unbounded_String (Label)));
            Pending_Bytes := Pending_Bytes + Required;
         end if;
      end Select_File;

      function Key_For
        (Path    : String;
         Label   : String;
         Is_Link : Boolean) return Directory_Key;

      function Same_Directory (Left, Right : Directory_Key) return Boolean;

      function Key_For
        (Path    : String;
         Label   : String;
         Is_Link : Boolean) return Directory_Key
      is
         use Ada.Strings.Unbounded;
         Canonical : constant String := File_System.Real_Path (Path);
         Identity  : constant File_System.Entry_Identity :=
           (if Canonical /= ""
            then File_System.Entry_Identity_Of (Canonical)
            elsif not Is_Link
            then File_System.Entry_Identity_Of (Path)
            else (others => <>));
      begin
         return
           (Identity  => Identity,
            Canonical => To_Unbounded_String (Canonical),
            Label     => To_Unbounded_String (Label));
      end Key_For;

      function Same_Directory (Left, Right : Directory_Key) return Boolean is
         use Ada.Strings.Unbounded;
      begin
         if Left.Identity.Available and then Right.Identity.Available then
            return Left.Identity = Right.Identity;
         else
            return
              Length (Left.Canonical) > 0
              and then Left.Canonical = Right.Canonical;
         end if;
      end Same_Directory;

      procedure Walk
        (Directory          : String;
         Relative_Directory : String;
         Depth              : Natural);

      procedure Walk
        (Directory          : String;
         Relative_Directory : String;
         Depth              : Natural)
      is
         Loaded : Ignore.Load_Outcome;
         Listed : Boolean;
         Current_Key : constant Directory_Key :=
           Key_For
             (Directory,
              (if Relative_Directory = "" then Root else File_System.Child_Path (Root, Relative_Directory)),
              File_System.Is_Link (Directory));

         procedure Visit
           (Name : String;
            Kind : File_System.Listed_Kind;
            Stop : in out Boolean);

         procedure Visit
           (Name : String;
            Kind : File_System.Listed_Kind;
            Stop : in out Boolean)
         is
            Full_Name : constant String := File_System.Child_Path (Directory, Name);
            Relative  : constant String :=
              (if Relative_Directory = ""
               then Name
               else File_System.Child_Path (Relative_Directory, Name));
            Label     : constant String :=
              (if Root = "." and then not Options.Prefix_Dot
               then Relative
               else File_System.Child_Path (Root, Relative));
            Actual    : File_System.Entry_Kind;
            Is_Link   : Boolean;
            Is_Dir    : Boolean;
            Is_File   : Boolean;
            Within_Size : Boolean := True;
         begin
            if (not Options.Include_Hidden
                and then Name'Length > 0
                and then Name (Name'First) = '.')
              or else Name = ".git"
            then
               Posix_Tools.Commands.Rg.Diagnostics.Debug
                 (Context,
                  Options.Diagnostics,
                  "rg::walk",
                  "ignoring " & Label
                  & (if Name = ".git" then ": repository metadata" else ": hidden path"));
               return;
            end if;

            if Kind = File_System.Listed_Unknown then
               Actual := File_System.Entry_Kind_Of (Full_Name);
               Is_Link := Actual = File_System.Entry_Link;
            else
               Is_Link := Kind = File_System.Listed_Link;
            end if;

            if Is_Link and then Options.Follow_Links then
               case File_System.Kind (Full_Name) is
                  when File_System.Directory =>
                     Is_Dir := True;
                     Is_File := False;
                  when File_System.Ordinary_File =>
                     Is_Dir := False;
                     Is_File := True;
                  when File_System.Missing_File | File_System.Uninspectable_File =>
                     Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                       (Context, "cannot follow "
                        & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                     Outcome.Input_Error := True;
                     return;
                  when File_System.Special_File =>
                     Is_Dir := False;
                     Is_File := False;
               end case;
            elsif Is_Link then
               Is_Dir := False;
               Is_File := False;
            elsif Kind = File_System.Listed_Unknown then
               Is_Dir := Actual = File_System.Entry_Directory;
               Is_File := Actual = File_System.Entry_Regular;
            else
               Is_Dir := Kind = File_System.Listed_Directory;
               Is_File := Kind = File_System.Listed_Regular;
            end if;

            if Is_File and then Options.Max_File_Size < Long_Long_Integer'Last then
               declare
                  Status : constant File_System.Entry_Status :=
                    (if Is_Link
                     then File_System.File_Status_Of (Full_Name)
                     else File_System.Entry_Status_Of (Full_Name));
               begin
                  Within_Size :=
                    not Status.Available or else Status.Size <= Options.Max_File_Size;
               end;
            end if;

            declare
               Glob_Result : constant Posix_Tools.Commands.Rg.Globs.Decision :=
                 Posix_Tools.Commands.Rg.Globs.Evaluate
                   (Options.Glob_Policy, Relative, Is_Dir);
               Ignore_Result : constant Ignore.Decision :=
                 Ignore.Evaluate (Policy, Relative, Is_Dir);
               Is_Selected : constant Boolean :=
                 (if Glob_Result.Has_Match
                  then Glob_Result.Is_Included
                  elsif Is_Dir
                  then not Ignore_Result.Is_Ignored
                  else
                    Posix_Tools.Commands.Rg.Globs.Selects_Unmatched_File
                      (Options.Glob_Policy)
                    and then not Ignore_Result.Is_Ignored);
               Type_Selected : constant Boolean :=
                 not Is_File
                 or else Posix_Tools.Commands.Rg.Types.Selects
                   (Options.Type_Policy, Relative);
            begin
               if Is_Dir then
                  if Options.Max_Depth > 0
                    and then Depth < Options.Max_Depth - 1
                    and then Is_Selected
                  then
                     declare
                        use Ada.Strings.Unbounded;
                        Candidate : constant Directory_Key := Key_For (Full_Name, Label, Is_Link);
                        Loop_At   : Natural := 0;
                        Child_Device : Long_Long_Integer := 0;
                        Child_Device_Available : Boolean := False;
                        May_Descend : Boolean := True;
                     begin
                        if Options.One_File_System then
                           Child_Device := File_System.Device_Id (Full_Name, Child_Device_Available);
                           if not Child_Device_Available then
                              Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                                (Context, "cannot determine file system for "
                                 & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                              Outcome.Input_Error := True;
                              May_Descend := False;
                           elsif Child_Device /= Root_Device then
                              May_Descend := False;
                              Posix_Tools.Commands.Rg.Diagnostics.Debug
                                (Context,
                                 Options.Diagnostics,
                                 "rg::walk",
                                 "ignoring " & Label & ": different file system");
                           end if;
                        end if;

                        for Index in Ancestors.First_Index .. Ancestors.Last_Index loop
                           if Same_Directory (Candidate, Ancestors.Element (Index)) then
                              Loop_At := Index;
                              exit;
                           end if;
                        end loop;

                        if not May_Descend then
                           null;
                        elsif Loop_At /= 0 then
                           Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                             (Context, "File system loop found: "
                              & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label)
                              & " points to an ancestor "
                              & Posix_Tools.Commands.Helpers.Escape_Untrusted
                                (To_String (Ancestors.Element (Loop_At).Label)));
                           Outcome.Input_Error := True;
                        elsif Is_Link
                          and then not Candidate.Identity.Available
                          and then Length (Candidate.Canonical) = 0
                        then
                           Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                             (Context, "cannot safely follow "
                              & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                           Outcome.Input_Error := True;
                        else
                           Posix_Tools.Commands.Rg.Diagnostics.Trace
                             (Context, Options.Diagnostics, "rg::walk", "descending into " & Label);
                           Walk (Full_Name, Relative, Depth + 1);
                        end if;
                     end;
                  elsif not Is_Selected then
                     if Glob_Result.Has_Match then
                        Posix_Tools.Commands.Rg.Diagnostics.Debug
                          (Context, Options.Diagnostics, "rg::walk", "ignoring " & Label & ": glob override");
                     elsif Ignore_Result.Is_Ignored then
                        Posix_Tools.Commands.Rg.Diagnostics.Debug
                          (Context,
                           Options.Diagnostics,
                           "rg::ignore",
                           "ignoring " & Label & ": matched "
                           & Ada.Strings.Unbounded.To_String (Ignore_Result.Match.Pattern)
                           & " in "
                           & Ada.Strings.Unbounded.To_String (Ignore_Result.Match.Source_Path)
                           & ":" & Natural'Image (Ignore_Result.Match.Source_Line));
                     end if;
                  elsif Options.Max_Depth = 0 or else Depth >= Options.Max_Depth - 1 then
                     Posix_Tools.Commands.Rg.Diagnostics.Debug
                       (Context, Options.Diagnostics, "rg::walk", "ignoring " & Label & ": maximum depth reached");
                  end if;
               elsif Is_File
                 and then Is_Selected
                 and then Within_Size
                 and then Type_Selected
               then
                  Select_File (Full_Name, Label);
               elsif Is_File and then not Is_Selected then
                  if Glob_Result.Has_Match then
                     Posix_Tools.Commands.Rg.Diagnostics.Debug
                       (Context, Options.Diagnostics, "rg::walk", "ignoring " & Label & ": glob override");
                  elsif Ignore_Result.Is_Ignored then
                     Posix_Tools.Commands.Rg.Diagnostics.Debug
                       (Context,
                        Options.Diagnostics,
                        "rg::ignore",
                        "ignoring " & Label & ": matched "
                        & Ada.Strings.Unbounded.To_String (Ignore_Result.Match.Pattern)
                        & " in " & Ada.Strings.Unbounded.To_String (Ignore_Result.Match.Source_Path)
                        & ":" & Natural'Image (Ignore_Result.Match.Source_Line));
                  end if;
               elsif Is_File and then not Within_Size then
                  Posix_Tools.Commands.Rg.Diagnostics.Debug
                    (Context, Options.Diagnostics, "rg::walk", "ignoring " & Label & ": file is too large");
               elsif Is_File and then not Type_Selected then
                  Posix_Tools.Commands.Rg.Diagnostics.Debug
                    (Context, Options.Diagnostics, "rg::walk", "ignoring " & Label & ": file type filter");
               else
                  Posix_Tools.Commands.Rg.Diagnostics.Debug
                    (Context, Options.Diagnostics, "rg::walk", "ignoring " & Label & ": unsupported file type");
               end if;
            end;

            Stop := Collection_Failed
              or else Context.Output_Failed
              or else Outcome.Match_Error
              or else Outcome.Stop_All;
         end Visit;

         procedure List is new File_System.For_Each_Listed_Entry (Visit);
      begin
         Posix_Tools.Commands.Rg.Diagnostics.Trace
           (Context,
            Options.Diagnostics,
            "rg::walk",
            "reading directory "
            & (if Relative_Directory = "" then Root else File_System.Child_Path (Root, Relative_Directory)));
         Ancestors.Append (Current_Key);
         Ignore.Enter_Directory (Policy, Directory, Relative_Directory, Loaded);
         if Loaded.Sources_Loaded > 0 then
            Posix_Tools.Commands.Rg.Diagnostics.Debug
              (Context,
               Options.Diagnostics,
               "rg::ignore",
               "loaded" & Natural'Image (Loaded.Sources_Loaded)
               & " ignore source(s) with" & Natural'Image (Loaded.Rules_Added)
               & " rule(s) in " & Directory);
         end if;
         if Loaded.Had_Error then
            Posix_Tools.Commands.Rg.Diagnostics.Error_Line
              (Context, "could not load an ignore file in "
               & Posix_Tools.Commands.Helpers.Escape_Untrusted (Directory));
            Outcome.Input_Error := True;
         end if;

         if Depth < Options.Max_Depth and then not Context.Output_Failed then
            List (Directory, Listed);
            if not Listed then
               Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                 (Context, "cannot read directory "
                  & Posix_Tools.Commands.Helpers.Escape_Untrusted (Directory));
               Outcome.Input_Error := True;
            end if;
         end if;
         Ancestors.Delete_Last;
      end Walk;
   begin
      Outcome := (others => <>);
      Posix_Tools.Commands.Rg.Diagnostics.Debug
        (Context, Options.Diagnostics, "rg::walk", "search root " & Root);
      if Options.One_File_System then
         Root_Device := File_System.Device_Id (Root, Root_Device_Available);
         if not Root_Device_Available then
            Posix_Tools.Commands.Rg.Diagnostics.Error_Line
              (Context, "cannot determine file system for "
               & Posix_Tools.Commands.Helpers.Escape_Untrusted (Root));
            Outcome.Input_Error := True;
            return;
         end if;
      end if;
      Ignore.Initialize
        (Policy,
         Root,
         Use_Gitignore => Options.Use_Ignore and Options.Use_Vcs_Ignore,
         Use_Ignore    => Options.Use_Ignore,
         Use_Rgignore  => Options.Use_Ignore,
         Use_Parent    => Options.Use_Ignore and Options.Use_Parent_Ignore);
      Walk (Root, "", 0);

      if Options.Sort in Path_Ascending | Path_Descending
        and then not Collection_Failed
        and then not Pending.Is_Empty
      then
         Pending_File_Sorting.Sort (Pending);
         if Options.Sort = Path_Ascending then
            for Item of Pending loop
               Process_File
                 (Context,
                  Ada.Strings.Unbounded.To_String (Item.Name),
                  Ada.Strings.Unbounded.To_String (Item.Label),
                  Outcome);
               exit when Context.Output_Failed or else Outcome.Match_Error or else Outcome.Stop_All;
            end loop;
         else
            for Index in reverse Pending.First_Index .. Pending.Last_Index loop
               declare
                  Item : constant Pending_File := Pending.Element (Index);
               begin
                  Process_File
                    (Context,
                     Ada.Strings.Unbounded.To_String (Item.Name),
                     Ada.Strings.Unbounded.To_String (Item.Label),
                     Outcome);
               end;
               exit when Context.Output_Failed or else Outcome.Match_Error or else Outcome.Stop_All;
            end loop;
         end if;
      end if;
      Outcome.Output_Error := Outcome.Output_Error or else Context.Output_Failed;
   end Walk_Tree;

   procedure Collect_Tree
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Root    : String;
      Options : Discovery_Options;
      Files   : in out File_Set;
      Outcome : out Traversal_Outcome)
   is
      procedure Collect
        (Collect_Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Name            : String;
         Label           : String;
         Tree_Outcome    : in out Traversal_Outcome);

      procedure Collect
        (Collect_Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Name            : String;
         Label           : String;
         Tree_Outcome    : in out Traversal_Outcome) is
      begin
         Add_File
           (Collect_Context,
            Files,
            Name,
            Label,
            Standard_Input => False,
            Outcome        => Tree_Outcome,
            Recursive      => True);
      end Collect;

      procedure Walk is new Walk_Tree (Collect);
      Effective : Discovery_Options := Options;
   begin
      Effective.Sort := Unsorted;
      Walk (Context, Root, Effective, Outcome);
   end Collect_Tree;

   procedure Sort_Files
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Files   : in out File_Set;
      Order   : Sort_Order;
      Outcome : in out Traversal_Outcome)
   is
      function Key_Name return String;

      function Key_Name return String is
      begin
         case Order is
            when Modified_Ascending | Modified_Descending =>
               return "modification";
            when Accessed_Ascending | Accessed_Descending =>
               return "access";
            when Created_Ascending | Created_Descending =>
               return "creation";
            when others =>
               return "metadata";
         end case;
      end Key_Name;
   begin
      if Files.Failed or else not Is_Metadata_Sort (Order) then
         return;
      end if;

      for Index in Files.Items.First_Index .. Files.Items.Last_Index loop
         declare
            Item      : File_Record := Files.Items.Element (Index);
            Available : Boolean := False;
         begin
            if Item.Standard_Input then
               null;
            else
               case Order is
                  when Modified_Ascending | Modified_Descending =>
                     Available := File_System.Modification_Time
                       (Ada.Strings.Unbounded.To_String (Item.Name), Item.Key);
                  when Accessed_Ascending | Accessed_Descending =>
                     Available := File_System.Access_Time
                       (Ada.Strings.Unbounded.To_String (Item.Name), Item.Key);
                  when Created_Ascending | Created_Descending =>
                     declare
                        Name : constant String := Ada.Strings.Unbounded.To_String (Item.Name);
                        Resolved : constant String :=
                          (if File_System.Is_Link (Name)
                           then File_System.Real_Path (Name)
                           else Name);
                     begin
                        Available := Resolved /= ""
                          and then File_System.Creation_Time (Resolved, Item.Key);
                     end;
                  when others =>
                     null;
               end case;

               if not Available then
                  Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                    (Context, "cannot read " & Key_Name & " time for "
                     & Posix_Tools.Commands.Helpers.Escape_Untrusted
                       (Ada.Strings.Unbounded.To_String (Item.Label)));
                  Files.Failed := True;
                  Outcome.Input_Error := True;
               end if;
            end if;
            Item.Key_Available := Available;
            Files.Items.Replace_Element (Index, Item);
         end;
      end loop;

      if not Files.Failed then
         case Order is
            when Modified_Ascending | Accessed_Ascending | Created_Ascending =>
               Ascending_Sorting.Sort (Files.Items);
            when Modified_Descending | Accessed_Descending | Created_Descending =>
               Descending_Sorting.Sort (Files.Items);
            when others =>
               null;
         end case;
      end if;
   end Sort_Files;

   procedure Search_Core
     (Context  : in out Posix_Tools.Commands.Contexts.Context'Class;
      Root     : String;
      Provided_Files : File_Set;
      Files_Provided : Boolean;
      Patterns : Posix_Tools.Commands.Rg.Patterns.Compiled_Pattern_Array;
      Options  : Traversal_Options;
      Outcome  : out Traversal_Outcome)
   is
      procedure Search_File
        (Search_Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Name           : String;
         Label          : String;
         Tree_Outcome   : in out Traversal_Outcome);

      procedure Search_File
        (Search_Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Name           : String;
         Label          : String;
         Tree_Outcome   : in out Traversal_Outcome)
      is
         Result : Posix_Tools.Commands.Rg.Search.Search_Outcome;
         Search_Options : Posix_Tools.Commands.Rg.Search.Execution_Options := Options.Search;
         Started : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         Search_Options.Separate_First_Group :=
           Search_Options.Separate_First_Group or else Tree_Outcome.Had_Result;
         Posix_Tools.Commands.Rg.Search.Search_Source
           (Context     => Search_Context,
            Name        => Name,
            Label       => Label,
            Options     => Search_Options,
            Patterns    => Patterns,
            Outcome     => Result);
         Tree_Outcome.Had_Match := Tree_Outcome.Had_Match or else Result.Had_Match;
         Tree_Outcome.Had_Result := Tree_Outcome.Had_Result or else Result.Had_Result;
         Tree_Outcome.Stop_All := Tree_Outcome.Stop_All or else Result.Stop_All;
         Tree_Outcome.Input_Error := Tree_Outcome.Input_Error or else Result.Input_Error;
         Tree_Outcome.Match_Error := Tree_Outcome.Match_Error or else Result.Match_Error;
         Tree_Outcome.Output_Error := Tree_Outcome.Output_Error or else Result.Output_Error;
         Tree_Outcome.Match_Count := Added (Tree_Outcome.Match_Count, Result.Match_Count);
         Tree_Outcome.Matched_Lines := Added (Tree_Outcome.Matched_Lines, Result.Matched_Lines);
         if Result.Had_Match then
            Tree_Outcome.Files_With_Matches := Added (Tree_Outcome.Files_With_Matches, 1);
         end if;
         if Result.Was_Searched then
            Tree_Outcome.Files_Searched := Added (Tree_Outcome.Files_Searched, 1);
         end if;
         Tree_Outcome.Bytes_Searched := Added (Tree_Outcome.Bytes_Searched, Result.Bytes_Searched);
         Tree_Outcome.Bytes_Printed := Added (Tree_Outcome.Bytes_Printed, Result.Bytes_Printed);
         Tree_Outcome.Search_Time := Tree_Outcome.Search_Time
           + Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Started);
      end Search_File;

      procedure Walk is new Walk_Tree (Search_File);

      procedure Search_Parallel
        (Files          : File_Set;
         Worker_Count   : Positive;
         Search_Outcome : out Traversal_Outcome);

      procedure Search_Parallel
        (Files          : File_Set;
         Worker_Count   : Positive;
         Search_Outcome : out Traversal_Outcome)
      is
         use Ada.Strings.Unbounded;
         use type Ada.Streams.Stream_Element_Offset;
         use type Posix_Tools.Commands.Rg.Rendering.Result_Mode;
         use type Posix_Tools.Commands.Rg.Search.Binary_Policy;

         Max_Output_Bytes : constant Natural := 64 * 1024 * 1024;
         Max_Error_Bytes  : constant Natural := 4 * 1024 * 1024;

         type File_Record_Array is array (Positive range <>) of File_Record;
         Jobs : File_Record_Array (1 .. File_Count (Files));

         protected Work_Queue is
            procedure Take (Index : out Natural; Available : out Boolean);
            procedure Cancel;
            function Is_Cancelled return Boolean;
         private
            State : Posix_Tools.Rg_Parallel.Queue_State :=
              Posix_Tools.Rg_Parallel.Create (Jobs'Length);
         end Work_Queue;

         protected body Work_Queue is
            procedure Take (Index : out Natural; Available : out Boolean) is
            begin
               Posix_Tools.Rg_Parallel.Take (State, Index, Available);
            end Take;

            procedure Cancel is
            begin
               Posix_Tools.Rg_Parallel.Cancel (State);
            end Cancel;

            function Is_Cancelled return Boolean is
              (Posix_Tools.Rg_Parallel.Is_Cancelled (State));
         end Work_Queue;

         protected Output_Sink is
            entry Submit (Positive range Jobs'Range)
              (Output_Text  : String;
               Error_Text   : String;
               Label        : String;
               Result       : Posix_Tools.Commands.Rg.Search.Search_Outcome;
               Elapsed      : Duration;
               Buffer_Failed : Boolean);
            procedure Get (Result : out Traversal_Outcome);
         private
            Aggregate  : Traversal_Outcome;
            Seen_Output : Boolean := Options.Search.Separate_First_Group;
            Next_Output : Positive := Jobs'First;
         end Output_Sink;

         protected body Output_Sink is
            entry Submit (for Index in Positive range Jobs'Range)
              (Output_Text  : String;
               Error_Text   : String;
               Label        : String;
               Result       : Posix_Tools.Commands.Rg.Search.Search_Outcome;
               Elapsed      : Duration;
               Buffer_Failed : Boolean)
              when Index = Next_Output
            is
               Add_Separator : constant Boolean :=
                 Output_Text'Length > 0
                 and then Seen_Output
                 and then not Options.Search.Json_Output
                 and then
                   ((Options.Search.Style.Heading
                     and then Options.Search.Mode in
                       Posix_Tools.Commands.Rg.Rendering.Matching_Lines
                       | Posix_Tools.Commands.Rg.Rendering.Only_Matching)
                    or else
                      (Options.Search.Mode =
                         Posix_Tools.Commands.Rg.Rendering.Matching_Lines
                       and then
                         (Options.Search.Before_Context > 0
                          or else Options.Search.After_Context > 0)));
               Separator : constant String :=
                 (if Options.Search.Style.Heading
                  then String'(1 => Options.Search.Style.Record_Terminator)
                  else To_String (Options.Search.Context_Separator)
                    & String'(1 => Options.Search.Style.Record_Terminator));
            begin
               if Error_Text'Length > 0 then
                  Context.Put_Error (Error_Text);
               end if;

               if Buffer_Failed then
                  Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                    (Context, "parallel output exceeds the 64 MiB per-file limit: "
                     & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                  Aggregate.Output_Error := True;
               elsif Output_Text'Length > 0 then
                  if Add_Separator then
                     Context.Put (Separator);
                     Aggregate.Bytes_Printed := Added
                       (Aggregate.Bytes_Printed, Separator'Length);
                  end if;
                  Context.Put (Output_Text);
                  Seen_Output := True;
               end if;

               Aggregate.Had_Match := Aggregate.Had_Match or else Result.Had_Match;
               Aggregate.Had_Result := Aggregate.Had_Result or else Result.Had_Result;
               Aggregate.Stop_All := Aggregate.Stop_All or else Result.Stop_All;
               Aggregate.Input_Error := Aggregate.Input_Error or else Result.Input_Error;
               Aggregate.Match_Error := Aggregate.Match_Error or else Result.Match_Error;
               Aggregate.Output_Error := Aggregate.Output_Error
                 or else Result.Output_Error
                 or else Context.Output_Failed;
               Aggregate.Match_Count := Added (Aggregate.Match_Count, Result.Match_Count);
               Aggregate.Matched_Lines := Added (Aggregate.Matched_Lines, Result.Matched_Lines);
               if Result.Had_Match then
                  Aggregate.Files_With_Matches := Added (Aggregate.Files_With_Matches, 1);
               end if;
               if Result.Was_Searched then
                  Aggregate.Files_Searched := Added (Aggregate.Files_Searched, 1);
               end if;
               Aggregate.Bytes_Searched := Added
                 (Aggregate.Bytes_Searched, Result.Bytes_Searched);
               Aggregate.Bytes_Printed := Added
                 (Aggregate.Bytes_Printed, Result.Bytes_Printed);
               Aggregate.Search_Time := Aggregate.Search_Time + Elapsed;

               if Result.Stop_All or else Context.Output_Failed or else Buffer_Failed then
                  Work_Queue.Cancel;
               end if;
               if Next_Output < Jobs'Last then
                  Next_Output := Next_Output + 1;
               end if;
            end Submit;

            procedure Get (Result : out Traversal_Outcome) is
            begin
               Result := Aggregate;
            end Get;
         end Output_Sink;

         type Worker_Context is new Posix_Tools.Commands.Contexts.Context with record
            Output_Buffer : Unbounded_String;
            Error_Buffer  : Unbounded_String;
            Failed        : Boolean := False;
         end record;

         overriding procedure Put (Self : in out Worker_Context; Text : String);
         overriding procedure Put_Bytes
           (Self   : in out Worker_Context;
            Buffer : Ada.Streams.Stream_Element_Array;
            Last   : Ada.Streams.Stream_Element_Offset);
         overriding procedure Put_Error (Self : in out Worker_Context; Text : String);
         overriding procedure Put_Line (Self : in out Worker_Context; Text : String);
         overriding procedure Put_Error_Line (Self : in out Worker_Context; Text : String);
         overriding function Output_Failed (Self : Worker_Context) return Boolean;
         overriding procedure Mark_Output_Failure (Self : in out Worker_Context);

         procedure Put (Self : in out Worker_Context; Text : String) is
         begin
            if Text'Length > Max_Output_Bytes
              - Natural'Min (Length (Self.Output_Buffer), Max_Output_Bytes)
            then
               Self.Failed := True;
            else
               Append (Self.Output_Buffer, Text);
            end if;
         end Put;

         procedure Put_Bytes
           (Self   : in out Worker_Context;
            Buffer : Ada.Streams.Stream_Element_Array;
            Last   : Ada.Streams.Stream_Element_Offset)
         is
            Text : String (1 .. (if Last < Buffer'First then 0 else Natural (Last - Buffer'First + 1)));
         begin
            for Index in Text'Range loop
               Text (Index) := Character'Val
                 (Buffer (Buffer'First + Ada.Streams.Stream_Element_Offset (Index - 1)));
            end loop;
            Put (Self, Text);
         end Put_Bytes;

         procedure Put_Error (Self : in out Worker_Context; Text : String) is
         begin
            if Text'Length > Max_Error_Bytes
              - Natural'Min (Length (Self.Error_Buffer), Max_Error_Bytes)
            then
               Self.Failed := True;
            else
               Append (Self.Error_Buffer, Text);
            end if;
         end Put_Error;

         procedure Put_Line (Self : in out Worker_Context; Text : String) is
         begin
            Put (Self, Text & ASCII.LF);
         end Put_Line;

         procedure Put_Error_Line (Self : in out Worker_Context; Text : String) is
         begin
            Put_Error (Self, Text & ASCII.LF);
         end Put_Error_Line;

         function Output_Failed (Self : Worker_Context) return Boolean is
           (Self.Failed);

         procedure Mark_Output_Failure (Self : in out Worker_Context) is
         begin
            Self.Failed := True;
         end Mark_Output_Failure;

         procedure Reset (Self : in out Worker_Context) is
         begin
            Self.Output_Buffer := Null_Unbounded_String;
            Self.Error_Buffer := Null_Unbounded_String;
            Self.Failed := False;
         end Reset;

         type Worker_Context_Array is array (Positive range <>) of Worker_Context;
         Worker_Contexts : Worker_Context_Array (1 .. Worker_Count);

         task type Worker is
            entry Start (Identity : Positive);
         end Worker;

         task body Worker is
            function Cancelled return Boolean is
              (Work_Queue.Is_Cancelled);

            Worker_Id     : Positive := 1;
            Index         : Natural;
            Available     : Boolean;
         begin
            accept Start (Identity : Positive) do
               Worker_Id := Identity;
            end Start;
            declare
               Local_Context : Worker_Context renames Worker_Contexts (Worker_Id);
            begin
               loop
                  Work_Queue.Take (Index, Available);
                  exit when not Available;
                  Reset (Local_Context);
                  declare
                     Item           : constant File_Record := Jobs (Index);
                     Result         : Posix_Tools.Commands.Rg.Search.Search_Outcome;
                     Search_Options : Posix_Tools.Commands.Rg.Search.Execution_Options := Options.Search;
                     Started        : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
                  begin
                     Search_Options.Separate_First_Group := False;
                     Search_Options.Abort_Callback := Cancelled'Unrestricted_Access;
                     if not Item.Recursive
                       and then Search_Options.Binary =
                         Posix_Tools.Commands.Rg.Search.Detect_Binary
                     then
                        Search_Options.Binary := Posix_Tools.Commands.Rg.Search.Search_Binary;
                     end if;
                     if Cancelled then
                        Result := (Stop_All => True, others => <>);
                     else
                        Posix_Tools.Commands.Rg.Search.Search_Source
                          (Context  => Local_Context,
                           Name     => To_String (Item.Name),
                           Label    => To_String (Item.Label),
                           Options  => Search_Options,
                           Patterns => Patterns,
                           Outcome  => Result);
                        if Result.Stop_All then
                           Work_Queue.Cancel;
                        end if;
                     end if;
                     Output_Sink.Submit (Index)
                       (Output_Text   => To_String (Local_Context.Output_Buffer),
                        Error_Text    => To_String (Local_Context.Error_Buffer),
                        Label         => To_String (Jobs (Index).Label),
                        Result        => Result,
                        Elapsed       => Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Started),
                        Buffer_Failed => Local_Context.Failed);
                  exception
                     when Occurrence : others =>
                        Output_Sink.Submit (Index)
                          (Output_Text   => To_String (Local_Context.Output_Buffer),
                           Error_Text    =>
                             To_String (Local_Context.Error_Buffer)
                             & "rg: "
                             & Posix_Tools.Commands.Rg.Diagnostics.Localized
                                 (Local_Context,
                                  "worker failed for "
                                  & Posix_Tools.Commands.Helpers.Escape_Untrusted
                                      (To_String (Jobs (Index).Label))
                                  & ": " & Ada.Exceptions.Exception_Message (Occurrence))
                             & ASCII.LF,
                           Label         => To_String (Jobs (Index).Label),
                           Result        => (Input_Error => True, others => <>),
                           Elapsed       => 0.0,
                           Buffer_Failed => Local_Context.Failed);
                  end;
               end loop;
            end;
         end Worker;

      begin
         Search_Outcome := (others => <>);
         for Index in Jobs'Range loop
            Jobs (Index) := Files.Items.Element (Index);
         end loop;

         declare
            Workers : array (1 .. Worker_Count) of Worker;
         begin
            for Index in Workers'Range loop
               Workers (Index).Start (Index);
            end loop;
         end;
         Output_Sink.Get (Search_Outcome);
      end Search_Parallel;
   begin
      declare
         Effective : constant Natural :=
           Effective_Worker_Count (Options.Threads, Options.Sort);
         Discovery : constant Discovery_Options :=
           (Include_Hidden => Options.Include_Hidden,
            Use_Ignore     => Options.Use_Ignore,
            Use_Vcs_Ignore => Options.Use_Vcs_Ignore,
            Use_Parent_Ignore => Options.Use_Parent_Ignore,
            Follow_Links   => Options.Follow_Links,
            One_File_System => Options.One_File_System,
            Max_Depth      => Options.Max_Depth,
            Max_File_Size  => Options.Max_File_Size,
            Prefix_Dot     => Options.Prefix_Dot,
            Null_Pathnames => Options.Null_Pathnames,
            Sort           => Options.Sort,
            Glob_Policy    => Options.Glob_Policy,
            Type_Policy    => Options.Type_Policy,
            Style          => Options.Search.Style,
            Diagnostics    => Options.Diagnostics);
      begin
         Posix_Tools.Commands.Rg.Diagnostics.Debug
           (Context,
            Options.Diagnostics,
            "rg::workers",
            "using" & Natural'Image (Effective) & " worker thread(s)");

         if Files_Provided then
            Outcome := (others => <>);
            if Files_Ready (Provided_Files) and then File_Count (Provided_Files) > 0
              and then not Context.Output_Failed
            then
               Search_Parallel
                 (Provided_Files,
                  Natural'Min (Effective, File_Count (Provided_Files)),
                  Outcome);
            end if;
         elsif Effective = 1 then
            Walk (Context, Root, Discovery, Outcome);
         else
            declare
               Files          : File_Set;
               Collect_Result : Traversal_Outcome;
               Parallel_Result : Traversal_Outcome;
            begin
               Collect_Tree (Context, Root, Discovery, Files, Collect_Result);
               Outcome := Collect_Result;
               if Files_Ready (Files) and then File_Count (Files) > 0
                 and then not Context.Output_Failed
               then
                  Search_Parallel
                    (Files,
                     Natural'Min (Effective, File_Count (Files)),
                     Parallel_Result);
                  Outcome.Had_Match := Outcome.Had_Match or else Parallel_Result.Had_Match;
                  Outcome.Had_Result := Outcome.Had_Result or else Parallel_Result.Had_Result;
                  Outcome.Stop_All := Outcome.Stop_All or else Parallel_Result.Stop_All;
                  Outcome.Input_Error := Outcome.Input_Error or else Parallel_Result.Input_Error;
                  Outcome.Match_Error := Outcome.Match_Error or else Parallel_Result.Match_Error;
                  Outcome.Output_Error := Outcome.Output_Error or else Parallel_Result.Output_Error;
                  Outcome.Match_Count := Added (Outcome.Match_Count, Parallel_Result.Match_Count);
                  Outcome.Matched_Lines := Added (Outcome.Matched_Lines, Parallel_Result.Matched_Lines);
                  Outcome.Files_With_Matches := Added
                    (Outcome.Files_With_Matches, Parallel_Result.Files_With_Matches);
                  Outcome.Files_Searched := Added
                    (Outcome.Files_Searched, Parallel_Result.Files_Searched);
                  Outcome.Bytes_Searched := Added
                    (Outcome.Bytes_Searched, Parallel_Result.Bytes_Searched);
                  Outcome.Bytes_Printed := Added
                    (Outcome.Bytes_Printed, Parallel_Result.Bytes_Printed);
                  Outcome.Search_Time := Outcome.Search_Time + Parallel_Result.Search_Time;
               end if;
            end;
         end if;
      end;
   end Search_Core;

   procedure Search_Tree
     (Context  : in out Posix_Tools.Commands.Contexts.Context'Class;
      Root     : String;
      Patterns : Posix_Tools.Commands.Rg.Patterns.Compiled_Pattern_Array;
      Options  : Traversal_Options;
      Outcome  : out Traversal_Outcome) is
   begin
      Search_Core
        (Context,
         Root,
         Provided_Files => (others => <>),
         Files_Provided => False,
         Patterns       => Patterns,
         Options        => Options,
         Outcome        => Outcome);
   end Search_Tree;

   procedure Search_Files
     (Context  : in out Posix_Tools.Commands.Contexts.Context'Class;
      Files    : File_Set;
      Patterns : Posix_Tools.Commands.Rg.Patterns.Compiled_Pattern_Array;
      Options  : Traversal_Options;
      Outcome  : out Traversal_Outcome) is
   begin
      Search_Core
        (Context,
         Root           => "",
         Provided_Files => Files,
         Files_Provided => True,
         Patterns       => Patterns,
         Options        => Options,
         Outcome        => Outcome);
   end Search_Files;

   procedure List_Tree
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Root    : String;
      Options : Discovery_Options;
      Outcome : out Traversal_Outcome)
   is
      procedure List_File
        (Output_Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Name           : String;
         Label          : String;
         Tree_Outcome   : in out Traversal_Outcome);

      procedure List_File
        (Output_Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Name           : String;
         Label          : String;
         Tree_Outcome   : in out Traversal_Outcome)
      is
         pragma Unreferenced (Name);
      begin
         Posix_Tools.Commands.Rg.Rendering.Put_Path
           (Output_Context,
            Label,
            (if Options.Null_Pathnames then ASCII.NUL else ASCII.LF),
            Options.Style);
         Tree_Outcome.Had_Result := True;
         Tree_Outcome.Output_Error := Output_Context.Output_Failed;
      end List_File;

      procedure Walk is new Walk_Tree (List_File);
   begin
      Walk (Context, Root, Options, Outcome);
   end List_Tree;
end Posix_Tools.Commands.Rg.Traversal;
