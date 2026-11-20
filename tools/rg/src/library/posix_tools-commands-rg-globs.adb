with Version.Ignore;

package body Posix_Tools.Commands.Rg.Globs is
   use Ada.Strings.Unbounded;

   procedure Add (Self : in out Policy; Source : String) is
      First          : Positive := Source'First;
      Last           : Natural := Source'Last;
      Include        : Boolean := True;
      Directory_Only : Boolean := False;
   begin
      if Source'Length = 0 then
         Self.Rules.Append
           (Rule'(Pattern        => Null_Unbounded_String,
             Include        => True,
             Directory_Only => False,
             Has_Slash      => False));
         Self.Has_Includes := True;
         return;
      end if;

      if Source (First) = '!' then
         Include := False;
         First := First + 1;
      elsif Source'Length >= 2
        and then Source (First) = '\'
        and then Source (First + 1) = '!'
      then
         First := First + 1;
      end if;

      if First > Last then
         Self.Rules.Append
           (Rule'(Pattern        => Null_Unbounded_String,
             Include        => Include,
             Directory_Only => False,
             Has_Slash      => False));
         Self.Has_Includes := Self.Has_Includes or else Include;
         return;
      end if;

      if Source (First) = '/' then
         First := First + 1;
      end if;
      if First > Last then
         Self.Rules.Append
           (Rule'(Pattern        => Null_Unbounded_String,
             Include        => Include,
             Directory_Only => False,
             Has_Slash      => False));
         Self.Has_Includes := Self.Has_Includes or else Include;
         return;
      end if;

      if Source (Last) = '/' then
         Directory_Only := True;
         Last := Last - 1;
      end if;
      if First > Last then
         Self.Rules.Append
           (Rule'(Pattern        => Null_Unbounded_String,
             Include        => Include,
             Directory_Only => Directory_Only,
             Has_Slash      => False));
         Self.Has_Includes := Self.Has_Includes or else Include;
         return;
      end if;

      declare
         Pattern : constant String := Source (First .. Last);
      begin
         Self.Rules.Append
           (Rule'(Pattern        => To_Unbounded_String (Pattern),
             Include        => Include,
             Directory_Only => Directory_Only,
             Has_Slash      => (for some Item of Pattern => Item = '/')));
         Self.Has_Includes := Self.Has_Includes or else Include;
      end;
   end Add;

   function Is_Empty (Self : Policy) return Boolean is
   begin
      return Self.Rules.Is_Empty;
   end Is_Empty;

   function Leaf_Name (Path : String) return String is
   begin
      for Index in reverse Path'Range loop
         if Path (Index) = '/' or else Path (Index) = '\' then
            return Path (Index + 1 .. Path'Last);
         end if;
      end loop;
      return Path;
   end Leaf_Name;

   function Evaluate
     (Self          : Policy;
      Relative_Path : String;
      Is_Directory  : Boolean) return Decision
   is
      Result : Decision;
   begin
      for Item of Self.Rules loop
         if (not Item.Directory_Only or else Is_Directory)
           and then Version.Ignore.Wildcard_Matches
             (To_String (Item.Pattern),
              (if Item.Has_Slash then Relative_Path else Leaf_Name (Relative_Path)))
         then
            Result := (Has_Match => True, Is_Included => Item.Include);
         end if;
      end loop;
      return Result;
   end Evaluate;

   function Selects_Unmatched_File (Self : Policy) return Boolean is
   begin
      return not Self.Has_Includes;
   end Selects_Unmatched_File;
end Posix_Tools.Commands.Rg.Globs;
