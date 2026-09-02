package Awk_CLI.Compatibility is
   --  Internal registry of reviewed compatibility behavior.
   --
   --  Entries are not a promise of full POSIX conformance. They record how the
   --  resolved awklib version behaves for CLI compatibility review.

   type Compatibility_Status is
     (Supported,
      Supported_With_Documented_Difference,
      Unsupported_By_Awklib,
      CLI_Specific);

   type Compatibility_Area is
     (Command_Line,
      Lexical_Syntax,
      Grammar,
      Expressions,
      Regular_Expressions,
      Fields_And_Records,
      Built_In_Variables,
      Built_In_Functions,
      Getline,
      Redirection,
      Input,
      Output_Formatting,
      Encoding);

   --  @return Number of reviewed registry entries.
   function Count return Natural;

   --  @param Index Registry entry index.
   --  @return Stable compatibility ID for entry Index.
   function Id (Index : Positive) return String with Pre => Index <= Count;

   --  @param Index Registry entry index.
   --  @return Functional area covered by entry Index.
   function Area (Index : Positive) return Compatibility_Area with Pre => Index <= Count;

   --  @param Index Registry entry index.
   --  @return Reviewed support status for entry Index.
   function Status (Index : Positive) return Compatibility_Status with Pre => Index <= Count;

   --  @param Index Registry entry index.
   --  @return Concise behavior description for entry Index.
   function Description (Index : Positive) return String with Pre => Index <= Count;

   --  @param Index Registry entry index.
   --  @return awklib capability or limitation source for entry Index.
   function Source (Index : Positive) return String with Pre => Index <= Count;

   --  @param Index Registry entry index.
   --  @return Documentation reference for entry Index.
   function Documentation (Index : Positive) return String with Pre => Index <= Count;

   --  @param Index Registry entry index.
   --  @return Closest test reference for entry Index.
   function Test_Reference (Index : Positive) return String with Pre => Index <= Count;

   --  @param Value Compatibility ID to find.
   --  @return True when Value is present as a stable registry ID.
   function Has_Id (Value : String) return Boolean;
end Awk_CLI.Compatibility;
