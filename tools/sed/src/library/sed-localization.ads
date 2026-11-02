private with Ada.Containers.Indefinite_Vectors;
private with Ada.Strings.Unbounded;

--  Adapter over the message catalogue.
--
--  Messages are looked up through Posix_Tools.Localization, the project's
--  one adapter over the message formatting library. Every
--  user-facing string in the program -- usage, help, option descriptions,
--  version labels, diagnostics, hints -- is resolved through here from a
--  stable key, so no layer builds a sentence by concatenating fragments and
--  no layer assumes English word order.
--
--  Sed data never passes through this package. Script text, option spellings,
--  labels, file names and source excerpts appear only as arguments, and are
--  escaped by the caller before they get here.
--
--  When no catalogue can be loaded, or it lacks a message, the adapter
--  renders the message's English text, which Sed.Localization.Defaults holds
--  for every message of the catalogue: a message identifier is never shown.
package Sed.Localization is

   type Catalog is limited private;

   --  Load a catalogue and select the active locale.
   --
   --  @param Item Catalogue to initialize.
   --  @param Catalog_Path Path to the catalogue file; may be empty.
   --  @param Locale Requested locale name; empty selects the catalogue
   --    default locale.
   procedure Initialize
     (Item : in out Catalog;
      Catalog_Path : String;
      Locale : String);

   --  @param Item Catalogue to inspect.
   --  @return True when messages resolve from a real catalogue.
   function Is_Valid (Item : Catalog) return Boolean;

   --  @param Item Catalogue to inspect.
   --  @return Active locale name, possibly empty.
   function Locale (Item : Catalog) return String;

   --  Named arguments for a message.
   type Parameters is limited private;

   --  @param Args Argument set to update.
   --  @param Name Argument name used in the template.
   --  @param Value Text value; the caller has already escaped it.
   procedure Set
     (Args : in out Parameters;
      Name : String;
      Value : String);

   --  @param Args Argument set to update.
   --  @param Name Argument name used in the template.
   --  @param Value Integer value, formatted by the catalogue.
   procedure Set
     (Args : in out Parameters;
      Name : String;
      Value : Line_Count);

   --  Render a message with no arguments.
   --
   --  @param Item Catalogue to render from.
   --  @param Key Stable message key.
   --  @return Rendered text, in English when the catalogue cannot give it.
   function Text (Item : Catalog; Key : String) return String;

   --  Render a message with named arguments.
   --
   --  @param Item Catalogue to render from.
   --  @param Key Stable message key.
   --  @param Args Named arguments.
   --  @return Rendered text, in English when the catalogue cannot give it.
   function Text
     (Item : Catalog;
      Key : String;
      Args : Parameters) return String;

   --  Whether a key resolves in the catalogue or the English defaults.
   --
   --  Used by catalogue validation rather than by rendering, which always
   --  degrades to English instead of failing.
   --
   --  @param Item Catalogue to inspect.
   --  @param Key Stable message key.
   --  @return True when the key resolves.
   function Has_Key (Item : Catalog; Key : String) return Boolean;

private

   package U renames Ada.Strings.Unbounded;

   type Catalog is limited record
      Path : U.Unbounded_String := U.Null_Unbounded_String;
      Locale : U.Unbounded_String := U.Null_Unbounded_String;
      Valid : Boolean := False;
   end record;

   type Parameter is record
      Name : U.Unbounded_String;
      Value : U.Unbounded_String;
   end record;

   package Parameter_Vectors is new Ada.Containers.Indefinite_Vectors
     (Positive, Parameter);

   type Parameters is limited record
      Values : Parameter_Vectors.Vector;
   end record;

end Sed.Localization;
