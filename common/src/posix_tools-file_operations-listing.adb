with Ada.Containers.Generic_Array_Sort;
with Ada.Unchecked_Deallocation;
with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.Natural_Order;

package body Posix_Tools.File_Operations.Listing is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Modes renames Posix_Tools.Text.File_Modes;
   package Unbounded renames Ada.Strings.Unbounded;

   use type FS.File_Kind;
   use type FS.Listed_Kind;
   use type FS.Special_File_Kind;

   function Describe
     (Directory   : String;
      Name        : String;
      Listed      : FS.Listed_Kind;
      With_Status : Boolean) return Listed_Entry;

   --  What the entry at Path is, asking the host, following a link.
   function Kind_Through_Link (Path : String) return Entry_Kind;

   function Describe
     (Directory   : String;
      Name        : String;
      Listed      : FS.Listed_Kind;
      With_Status : Boolean) return Listed_Entry
   is
      Item : Listed_Entry;
   begin
      Item.Name := Unbounded.To_Unbounded_String (Name);

      if not With_Status then
         Item.Is_Link := Listed = FS.Listed_Link;
         Item.Kind := (if Listed = FS.Listed_Directory then Directory_Entry else Regular_Entry);
         return Item;
      end if;

      declare
         Path      : constant String := FS.Child_Path (Directory, Name);
         Type_Code : Modes.File_Type_Code;
      begin
         Item.Status := FS.Entry_Status_Of (Path);
         Type_Code := (if Item.Status.Available then Modes.File_Type (Item.Status.Mode) else 0);

         Item.Is_Link :=
           (if Type_Code /= 0 then Type_Code = Modes.Type_Link
            elsif Listed /= FS.Listed_Unknown then Listed = FS.Listed_Link
            else FS.Is_Link (Path));

         if Item.Is_Link then
            if not FS.Read_Link_Target (Path, Item.Link_Target) then
               Item.Link_Target := Unbounded.Null_Unbounded_String;
            end if;

            Item.Kind := Kind_Through_Link (Path);
            return Item;
         end if;

         case Type_Code is
            when Modes.Type_Directory =>
               Item.Kind := Directory_Entry;
            when Modes.Type_Regular =>
               Item.Kind := Regular_Entry;
            when Modes.Type_FIFO =>
               Item.Kind := FIFO_Entry;
            when Modes.Type_Character_Device =>
               Item.Kind := Character_Device_Entry;
            when Modes.Type_Block_Device =>
               Item.Kind := Block_Device_Entry;
            when Modes.Type_Socket =>
               Item.Kind := Socket_Entry;
            when others =>
               Item.Kind :=
                 (case Listed is
                    when FS.Listed_Directory => Directory_Entry,
                    when FS.Listed_Regular => Regular_Entry,
                    when FS.Listed_Link | FS.Listed_Other | FS.Listed_Unknown => Kind_Through_Link (Path));
         end case;
      end;

      return Item;
   end Describe;

   function Extension (Name : String) return String is
   begin
      for I in reverse Name'First + 1 .. Name'Last loop
         if Name (I) = '.' then
            return Name (I + 1 .. Name'Last);
         end if;
      end loop;

      return "";
   end Extension;

   function Kind_Through_Link (Path : String) return Entry_Kind is
   begin
      case FS.Kind (Path) is
         when FS.Missing_File =>
            return Missing_Entry;
         when FS.Directory =>
            return Directory_Entry;
         when FS.Ordinary_File =>
            return Regular_Entry;
         when FS.Special_File =>
            case FS.Special_File_Info_Of (Path).Kind is
               when FS.FIFO =>
                  return FIFO_Entry;
               when FS.Character_Device =>
                  return Character_Device_Entry;
               when FS.Block_Device =>
                  return Block_Device_Entry;
               when FS.Socket =>
                  return Socket_Entry;
               when FS.Not_Special | FS.Other_Special =>
                  return Other_Entry;
            end case;
      end case;
   end Kind_Through_Link;

   procedure Read_Directory
     (Path           : String;
      Options        : Read_Options;
      Entries        : out Entry_Vectors.Vector;
      Outcome        : out Read_Outcome;
      Stop_Requested : access function return Boolean := null)
   is
      Stopped : Boolean := False;

      procedure Add (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean);

      procedure Add (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean) is
      begin
         if Stop_Requested /= null and then Stop_Requested.all then
            Stopped := True;
            Stop := True;
         elsif Options.Include_Hidden or else not Is_Hidden (Name) then
            Entries.Append (Describe (Path, Name, Kind, Options.With_Status));
         end if;
      end Add;

      procedure Each is new FS.For_Each_Listed_Entry (Add);

      Ok : Boolean;
   begin
      Entries.Clear;
      Each (Path, Ok);
      Outcome := (if not Ok then Read_Failed elsif Stopped then Read_Stopped else Read_Complete);
   end Read_Directory;

   procedure Sort (Entries : in out Entry_Vectors.Vector; Order : Sort_Order) is
      type Name_Access is access String;

      --  What an entry is compared by, taken out of it once, so that
      --  comparing allocates nothing and sorting moves only numbers.
      type Sort_Key_Record is record
         --  The name, its ASCII letters folded when Order folds case: only
         --  ever compared, by byte, and only made for a key that compares
         --  names or extensions.
         Name      : Name_Access;
         --  Natural_Order's key for the name, under Order's folding: the key
         --  itself, or what breaks a tie under another.
         Collated  : Name_Access;
         --  Where the extension starts in Name; zero when it has none.
         Extension : Natural := 0;
         Directory : Boolean := False;
         Kind      : Entry_Kind := Regular_Entry;
         Size      : Long_Long_Integer := 0;
         Modified  : Long_Long_Integer := 0;
      end record;

      type Key_Array is array (Positive range <>) of Sort_Key_Record;
      type Key_Array_Access is access Key_Array;
      type Index_Array is array (Positive range <>) of Positive;
      type Index_Array_Access is access Index_Array;

      procedure Free is new Ada.Unchecked_Deallocation (String, Name_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Key_Array, Key_Array_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Index_Array, Index_Array_Access);

      Count : constant Natural := Natural (Entries.Length);

      --  On the heap: a large directory's keys would not fit a task's stack.
      --  Made in the body, not here, so that the handler there frees the
      --  one made should making the other raise.
      Keys     : Key_Array_Access;
      Order_Of : Index_Array_Access;

      function Before (Left, Right : Positive) return Boolean;

      --  Take each entry's key out of it into Keys, and number Order_Of.
      procedure Build_Keys;

      --  Free the keys' strings, and Keys and Order_Of themselves.
      procedure Free_Keys;

      --  Put Entries in the order Order_Of gives.
      procedure Reorder;

      --  Whether Left comes before Right under Order's key alone.
      function Key_Less (Left, Right : Sort_Key_Record) return Boolean;

      function Name_Before (Left, Right : String) return Boolean is (Left < Right);

      --  The extension of Item's name: what Extension returns, as a slice.
      function Extension_Of (Item : Sort_Key_Record) return String is
        (if Item.Extension = 0 then "" else Item.Name (Item.Extension .. Item.Name'Last));

      function Before (Left, Right : Positive) return Boolean is
         L : Sort_Key_Record renames Keys (Left);
         R : Sort_Key_Record renames Keys (Right);
      begin
         if Order.Directories_First and then L.Directory /= R.Directory then
            return L.Directory;
         elsif Order.Key = By_Natural_Name then
            --  A total order: no two names are equal under it.
            return (if Order.Descending then R.Collated.all < L.Collated.all else L.Collated.all < R.Collated.all);
         elsif Key_Less (L, R) then
            return not Order.Descending;
         elsif Key_Less (R, L) then
            return Order.Descending;
         else
            --  Equal under the key: a fixed order by name, whatever the direction.
            return L.Collated.all < R.Collated.all;
         end if;
      end Before;

      procedure Build_Keys is
      begin
         for I in 1 .. Count loop
            declare
               Item  : Listed_Entry renames Entries.Constant_Reference (I).Element.all;
               Plain : constant String := Unbounded.To_String (Item.Name);
               Key   : Sort_Key_Record renames Keys (I);
            begin
               Key.Directory := Item.Kind = Directory_Entry;
               Key.Kind := Item.Kind;
               Key.Size := Item.Status.Size;
               Key.Modified := Item.Status.Modified_Seconds;

               --  Each string goes into Keys as it is made, so that Sort's
               --  handler frees it should making the next one raise.
               Key.Collated := new String'(Posix_Tools.Text.Natural_Order.Sort_Key (Plain, Order.Fold_Case));

               if Order.Key in By_Name | By_Extension | By_Kind then
                  Key.Name := new String'(Plain);

                  --  Only ASCII letters fold: the bytes of a UTF-8 name above
                  --  127 are parts of characters, not letters of their own.
                  if Order.Fold_Case then
                     for C of Key.Name.all loop
                        if C in 'A' .. 'Z' then
                           C := Character'Val (Character'Pos (C) + 32);
                        end if;
                     end loop;
                  end if;

                  declare
                     Suffix : constant String := Extension (Key.Name.all);
                  begin
                     if Suffix'Length > 0 then
                        Key.Extension := Key.Name'Last - Suffix'Length + 1;
                     end if;
                  end;
               end if;
            end;

            Order_Of (I) := I;
         end loop;
      end Build_Keys;

      procedure Free_Keys is
      begin
         if Keys /= null then
            for Item of Keys.all loop
               Free (Item.Name);
               Free (Item.Collated);
            end loop;
         end if;

         Free (Keys);
         Free (Order_Of);
      end Free_Keys;

      function Key_Less (Left, Right : Sort_Key_Record) return Boolean is
      begin
         case Order.Key is
            when By_Natural_Name =>
               return Left.Collated.all < Right.Collated.all;
            when By_Name =>
               return Name_Before (Left.Name.all, Right.Name.all);
            when By_Extension =>
               return Name_Before (Extension_Of (Left), Extension_Of (Right));
            when By_Size =>
               return Left.Size < Right.Size;
            when By_Modified =>
               return Left.Modified < Right.Modified;
            when By_Kind =>
               return Entry_Kind'Pos (Left.Kind) < Entry_Kind'Pos (Right.Kind)
                 or else (Left.Kind = Right.Kind and then Name_Before (Extension_Of (Left), Extension_Of (Right)));
         end case;
      end Key_Less;

      procedure Sort_Indices is new Ada.Containers.Generic_Array_Sort (Positive, Positive, Index_Array, Before);

      procedure Reorder is
         Sorted : Entry_Vectors.Vector;
      begin
         Sorted.Reserve_Capacity (Ada.Containers.Count_Type (Count));

         for Index of Order_Of.all loop
            Sorted.Append (Entries (Index));
         end loop;

         Entries.Move (Sorted);
      end Reorder;
   begin
      if Count < 2 then
         return;
      end if;

      Keys := new Key_Array (1 .. Count);
      Order_Of := new Index_Array (1 .. Count);
      Build_Keys;
      Sort_Indices (Order_Of.all);
      Reorder;
      Free_Keys;
   exception
      when others =>
         Free_Keys;
         raise;
   end Sort;
end Posix_Tools.File_Operations.Listing;
