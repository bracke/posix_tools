with Posix_Tools.Text.Natural_Order;

package body Posix_Tools.File_Operations.Listing is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Unbounded renames Ada.Strings.Unbounded;

   use type FS.File_Kind;
   use type FS.Listed_Kind;
   use type FS.Special_File_Kind;

   --  The file type field of a POSIX mode word, as a number: zero where the
   --  host's mode carries no type.
   function Mode_Type (Mode : Natural) return Natural is ((Mode / 8#10000#) mod 16);

   Type_FIFO             : constant := 1;
   Type_Character_Device : constant := 2;
   Type_Directory        : constant := 4;
   Type_Block_Device     : constant := 6;
   Type_Regular          : constant := 8;
   Type_Link             : constant := 10;
   Type_Socket           : constant := 12;

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
         Type_Code : Natural;
      begin
         Item.Status := FS.Entry_Status_Of (Path);
         Type_Code := (if Item.Status.Available then Mode_Type (Item.Status.Mode) else 0);

         Item.Is_Link :=
           (if Type_Code /= 0 then Type_Code = Type_Link
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
            when Type_Directory =>
               Item.Kind := Directory_Entry;
            when Type_Regular =>
               Item.Kind := Regular_Entry;
            when Type_FIFO =>
               Item.Kind := FIFO_Entry;
            when Type_Character_Device =>
               Item.Kind := Character_Device_Entry;
            when Type_Block_Device =>
               Item.Kind := Block_Device_Entry;
            when Type_Socket =>
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
      function Before (Left, Right : Listed_Entry) return Boolean;

      --  Whether Left comes before Right under Order's key alone.
      function Key_Less (Left, Right : Listed_Entry) return Boolean;

      function Name_Less (Left, Right : String) return Boolean;

      function Before (Left, Right : Listed_Entry) return Boolean is
         Left_Directory  : constant Boolean := Left.Kind = Directory_Entry;
         Right_Directory : constant Boolean := Right.Kind = Directory_Entry;
      begin
         if Order.Directories_First and then Left_Directory /= Right_Directory then
            return Left_Directory;
         end if;

         if Key_Less (Left, Right) then
            return not Order.Descending;
         elsif Key_Less (Left => Right, Right => Left) then
            return Order.Descending;
         end if;

         --  Equal under the key: a fixed order by name, whatever the direction.
         return Posix_Tools.Text.Natural_Order.Less
           (Unbounded.To_String (Left.Name), Unbounded.To_String (Right.Name), Order.Fold_Case);
      end Before;

      function Key_Less (Left, Right : Listed_Entry) return Boolean is
         Left_Name  : constant String := Unbounded.To_String (Left.Name);
         Right_Name : constant String := Unbounded.To_String (Right.Name);
      begin
         case Order.Key is
            when By_Natural_Name =>
               return Posix_Tools.Text.Natural_Order.Less (Left_Name, Right_Name, Order.Fold_Case);
            when By_Name =>
               return Name_Less (Left_Name, Right_Name);
            when By_Extension =>
               return Name_Less (Extension (Left_Name), Extension (Right_Name));
            when By_Size =>
               return Left.Status.Size < Right.Status.Size;
            when By_Modified =>
               return Left.Status.Modified_Seconds < Right.Status.Modified_Seconds;
            when By_Kind =>
               return Entry_Kind'Pos (Left.Kind) < Entry_Kind'Pos (Right.Kind)
                 or else (Left.Kind = Right.Kind
                          and then Name_Less (Extension (Left_Name), Extension (Right_Name)));
         end case;
      end Key_Less;

      function Name_Less (Left, Right : String) return Boolean is
         --  Only ASCII letters fold: the bytes of a UTF-8 name above 127 are
         --  parts of characters, not letters of their own.
         function Folded (Text : String) return String is
           ([for C of Text =>
               (if C in 'A' .. 'Z' then Character'Val (Character'Pos (C) + 32) else C)]);
      begin
         if Order.Fold_Case then
            return Folded (Left) < Folded (Right);
         else
            return Left < Right;
         end if;
      end Name_Less;

      package Sorting is new Entry_Vectors.Generic_Sorting (Before);
   begin
      Sorting.Sort (Entries);
   end Sort;
end Posix_Tools.File_Operations.Listing;
