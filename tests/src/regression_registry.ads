--  Validated generated/regressions.csv data shared by test selection and
--  metadata validation. Parsing and schema validation operate on supplied
--  content before the thin filesystem reader exposes rows to consumers.
package Regression_Registry is
   procedure For_Each_Row
     (Visit : not null access procedure
        (Line_Number : Positive;
         Id           : String;
         Command      : String;
         Summary      : String;
         Tests        : String));

   procedure For_Each_Test_Reference
     (References : String;
      Visit      : not null access procedure (Reference : String);
      Count      : out Natural;
      Has_Empty  : out Boolean);

   --  References that name AUnit tests. Regression-prefixed references are
   --  direct registrations; the other prefixes can become selector aliases.
   function Is_AUnit_Reference (Reference : String) return Boolean;
   function Is_Aliasable_AUnit_Reference
     (Reference : String) return Boolean;
private
   procedure Self_Test;
end Regression_Registry;
