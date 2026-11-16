private with Ada.Strings.Unbounded;

package Posix_Tools.Text.File_Descriptions is
   type Classifier is private;

   procedure Update (State : in out Classifier; Data : String);
   --  True once the built-in signature window is complete and later bytes
   --  cannot change the generic binary classification.
   function Classification_Complete (State : Classifier) return Boolean;
   function Description (State : Classifier; Mime_Mode : Boolean) return String;

   --  The bounded prefix needed to evaluate every supported rule in a magic
   --  file, and the result of evaluating those rules against such a prefix.
   function Magic_Prefix_Length (Magic_Text : String) return Natural;
   function Magic_Description
     (Data       : String;
      Mime_Mode  : Boolean;
      Magic_Text : String;
      Found      : out Boolean) return String;

   function Content_Description
     (Data       : String;
      Mime_Mode  : Boolean;
      Magic_Text : String;
      Has_Magic  : Boolean) return String;

private
   type Classifier is record
      Prefix   : Ada.Strings.Unbounded.Unbounded_String;
      Saw_Byte : Boolean := False;
      Saw_NUL  : Boolean := False;
      Saw_Text : Boolean := True;
   end record;
end Posix_Tools.Text.File_Descriptions;
