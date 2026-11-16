package Posix_Tools.Accounts
  with SPARK_Mode => On
is
   --  POSIX uid_t and gid_t are unsigned 32-bit values.  Keep this type
   --  independent of Natural, whose upper bound is normally 2**31 - 1.
   type Id is mod 2**32;

   --  Id'Last is reserved by the native ownership API as its "leave this
   --  side unchanged" marker, so it is not a settable account identifier.
   function Can_Set (Value : Id) return Boolean is (Value /= Id'Last);

   --  An ownership update keeps or replaces one side explicitly.  Keeping is
   --  control state, not a magic Id that callers can accidentally accept as
   --  user input.
   type Update is private;
   function Keep return Update;
   function Set_To (Value : Id) return Update
     with Pre => Can_Set (Value);

   --  Translate an explicit update at the host chown boundary.  Only the
   --  filesystem adapter should need the reserved native marker.
   function Value_Or_Keep (Item : Update) return Id;

   type Parse_Result is record
      Valid : Boolean := False;
      Value : Id := 0;
   end record;

   function Image (Value : Id) return String;

   function Parse (Text : String) return Parse_Result
     with Post =>
       (if not Parse'Result.Valid then Parse'Result.Value = 0);

private
   type Update is record
      Change : Boolean := False;
      Value  : Id := 0;
   end record;
end Posix_Tools.Accounts;
