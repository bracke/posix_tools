private package Posix_Tools.Commands.Sort_Keys.Comparison is
   --  The rules a key is compared by. POSIX sort: "When ordering options
   --  appear independent of key field specifications, the requested field
   --  ordering rules are applied globally to all sort keys. When attached to a
   --  specific key, the specified ordering options override all global
   --  ordering options for that key."
   function Effective_Rules
     (Key    : Sort_Key_Definition;
      Global : Ordering_Rules) return Ordering_Rules;

   --  The text a key is compared by, built once per line: the canonical
   --  numeric field for -n, otherwise the selected bytes after -b -d -f -i,
   --  turned into a collation key for the locale when no -d -f -i applies.
   --  Whole_Line selects the entire line, which is the key without -k.
   function Key_Text
     (Line       : String;
      Key        : Sort_Key_Definition;
      Rules      : Ordering_Rules;
      Options    : Sort_Options;
      Whole_Line : Boolean) return String;

   --  Compares two texts built by Key_Text with the same Rules: negative,
   --  zero or positive, already reversed for -r.
   function Compare_Key_Texts
     (Left, Right : String;
      Rules       : Ordering_Rules) return Integer;

   --  Byte order: negative, zero or positive.
   function Compare_Bytes (Left, Right : String) return Integer;
end Posix_Tools.Commands.Sort_Keys.Comparison;
