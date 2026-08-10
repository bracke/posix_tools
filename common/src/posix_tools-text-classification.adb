with Posix_Tools.Text.Whitespace_Data;

package body Posix_Tools.Text.Classification is
   function Is_Whitespace (Code_Point : Long_Long_Integer) return Boolean is
   begin
      return Posix_Tools.Text.Whitespace_Data.Is_Whitespace (Code_Point);
   end Is_Whitespace;
end Posix_Tools.Text.Classification;
