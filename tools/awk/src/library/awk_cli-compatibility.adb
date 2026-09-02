with Ada.Strings.Unbounded;

package body Awk_CLI.Compatibility is
   package U renames Ada.Strings.Unbounded;

   type Compatibility_Entry is record
      Id             : U.Unbounded_String;
      Area           : Compatibility_Area;
      Status         : Compatibility_Status;
      Description    : U.Unbounded_String;
      Source         : U.Unbounded_String;
      Documentation  : U.Unbounded_String;
      Test_Reference : U.Unbounded_String;
   end record;

   function S (Value : String) return U.Unbounded_String is
     (U.To_Unbounded_String (Value));

   Doc_Compatibility : constant U.Unbounded_String := S ("docs/compatibility.md");
   Source_Awklib_0_1 : constant U.Unbounded_String := S ("resolved awklib 0.1.0 behavior");

   Entries : constant array (Positive range <>) of Compatibility_Entry :=
     [(Id             => S ("AWK-COMPAT-REGEX-001"),
       Area           => Regular_Expressions,
       Status         => Supported,
       Description    => S ("regular-expression integration follows resolved awklib behavior"),
       Source         => Source_Awklib_0_1,
       Documentation  => Doc_Compatibility,
       Test_Reference => S ("awk process : process filter expression smoke")),

      (Id             => S ("AWK-COMPAT-GETLINE-001"),
       Area           => Getline,
       Status         => Supported,
       Description    => S ("main-input getline from BEGIN is handled by resolved awklib"),
       Source         => Source_Awklib_0_1,
       Documentation  => Doc_Compatibility,
       Test_Reference => S ("awk context : context main getline from BEGIN")),

      (Id             => S ("AWK-COMPAT-GETLINE-002"),
       Area           => Getline,
       Status         => Supported,
       Description    => S ("command getline is handled through the awklib command callback"),
       Source         => Source_Awklib_0_1,
       Documentation  => Doc_Compatibility,
       Test_Reference => S ("awk process : process command getline")),

      (Id             => S ("AWK-COMPAT-UTF8-001"),
       Area           => Encoding,
       Status         => Supported,
       Description    => S ("malformed UTF-8 no longer requires a CLI compatibility limitation"),
       Source         => Source_Awklib_0_1,
       Documentation  => Doc_Compatibility,
       Test_Reference => S ("awk compatibility : compatibility registry")),

      (Id             => S ("AWK-COMPAT-PRINTF-001"),
       Area           => Output_Formatting,
       Status         => Supported,
       Description    => S ("printf %c field-width behavior follows resolved awklib"),
       Source         => Source_Awklib_0_1,
       Documentation  => Doc_Compatibility,
       Test_Reference => S ("awklib suite : Test_Printf_Flags")),

      (Id             => S ("AWK-COMPAT-ASSIGNMENT-001"),
       Area           => Command_Line,
       Status         => Supported,
       Description    => S ("positional runtime assignments are represented at the CLI boundary"),
       Source         => Source_Awklib_0_1,
       Documentation  => Doc_Compatibility,
       Test_Reference => S ("awk process : process runtime assignment positions")),

      (Id             => S ("AWK-COMPAT-REDIRECTION-001"),
       Area           => Redirection,
       Status         => Supported,
       Description    => S ("append redirection intent is exposed through awklib streaming callbacks"),
       Source         => Source_Awklib_0_1,
       Documentation  => Doc_Compatibility,
       Test_Reference => S ("awk process : process append redirection"))];

   function Registry_Entry (Index : Positive) return Compatibility_Entry is (Entries (Index));

   function Count return Natural is (Entries'Length);

   function Id (Index : Positive) return String is (U.To_String (Registry_Entry (Index).Id));

   function Area (Index : Positive) return Compatibility_Area is (Registry_Entry (Index).Area);

   function Status (Index : Positive) return Compatibility_Status is (Registry_Entry (Index).Status);

   function Description (Index : Positive) return String is
     (U.To_String (Registry_Entry (Index).Description));

   function Source (Index : Positive) return String is
     (U.To_String (Registry_Entry (Index).Source));

   function Documentation (Index : Positive) return String is
     (U.To_String (Registry_Entry (Index).Documentation));

   function Test_Reference (Index : Positive) return String is
     (U.To_String (Registry_Entry (Index).Test_Reference));

   function Has_Id (Value : String) return Boolean is
   begin
      for Item of Entries loop
         if U.To_String (Item.Id) = Value then
            return True;
         end if;
      end loop;
      return False;
   end Has_Id;
end Awk_CLI.Compatibility;
