with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Posix_Tools.Host_Adapters.File_System;

--  Reading a directory into entries that carry what a listing shows: what
--  each entry is, where a link points, and the entry's own status.
package Posix_Tools.File_Operations.Listing is
   type Entry_Kind is
     (Directory_Entry,
      Regular_Entry,
      FIFO_Entry,
      Character_Device_Entry,
      Block_Device_Entry,
      Socket_Entry,
      Other_Entry,
      --  A link whose target does not exist.
      Missing_Entry);

   type Listed_Entry is record
      Name        : Ada.Strings.Unbounded.Unbounded_String;
      --  What the entry is, through a symbolic link when it is one.
      Kind        : Entry_Kind := Regular_Entry;
      Is_Link     : Boolean := False;
      Link_Target : Ada.Strings.Unbounded.Unbounded_String;
      --  The entry's own status; a link's own, not its target's. Left empty
      --  when the listing was read without status.
      Status      : Posix_Tools.Host_Adapters.File_System.Entry_Status;
   end record;

   package Entry_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Listed_Entry);

   type Read_Options is record
      --  Include names that start with a dot.
      Include_Hidden : Boolean := False;
      --  Look each entry up for its kind, link target, and status. Without
      --  it only the names are filled in, from a single read of the directory.
      With_Status    : Boolean := True;
   end record;

   type Read_Outcome is (Read_Complete, Read_Stopped, Read_Failed);

   function Is_Hidden (Name : String) return Boolean is
     (Name'Length > 0 and then Name (Name'First) = '.');

   --  Read Path's entries, . and .. left out, in the order the directory gives
   --  them. Stop_Requested, when given, is asked between entries; once it
   --  answers True the read ends with Read_Stopped and the entries so far.
   procedure Read_Directory
     (Path           : String;
      Options        : Read_Options;
      Entries        : out Entry_Vectors.Vector;
      Outcome        : out Read_Outcome;
      Stop_Requested : access function return Boolean := null);

   type Sort_Key is
     (By_Natural_Name,
      By_Name,
      By_Extension,
      By_Size,
      By_Modified,
      By_Kind);

   type Sort_Order is record
      Key               : Sort_Key := By_Natural_Name;
      Descending        : Boolean := False;
      Directories_First : Boolean := True;
      --  Compare ASCII letters regardless of case in name comparisons.
      Fold_Case         : Boolean := True;
   end record;

   --  Order Entries by Order. Entries equal under its key keep a fixed order
   --  by name, so that a re-read of an unchanged directory sorts the same.
   procedure Sort (Entries : in out Entry_Vectors.Vector; Order : Sort_Order);

   --  The extension of Name: what follows its last dot, unless that dot is
   --  its first character. Empty when it has none.
   function Extension (Name : String) return String;
end Posix_Tools.File_Operations.Listing;
