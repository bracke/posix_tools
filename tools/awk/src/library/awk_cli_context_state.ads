with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package Awk_CLI_Context_State is
   --  Internal storage model for Awk_CLI invocation contexts.
   --
   --  This package is not a stable public API. It keeps test-harness virtual
   --  I/O storage out of the root Awk_CLI spec while avoiding a parent/child
   --  circular dependency.

   package U renames Ada.Strings.Unbounded;

   type Virtual_File is record
      Path     : U.Unbounded_String;
      Content  : U.Unbounded_String;
      Readable : Boolean := True;
      Writable : Boolean := True;
      Openable : Boolean := True;
   end record;

   type Env_Item is record
      Name  : U.Unbounded_String;
      Value : U.Unbounded_String;
   end record;

   type Write_Operation is record
      Path    : U.Unbounded_String;
      Content : U.Unbounded_String;
      Append  : Boolean := False;
   end record;

   type Command_Output is record
      Command : U.Unbounded_String;
      Output  : U.Unbounded_String;
   end record;

   package File_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Virtual_File);
   package Env_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Env_Item);
   package Write_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Write_Operation);
   package Command_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Command_Output);

   type Virtual_IO_State is record
      Standard_In  : U.Unbounded_String;
      Files        : File_Vectors.Vector;
      Commands     : Command_Vectors.Vector;
      Environment  : Env_Vectors.Vector;
      Standard_Out : U.Unbounded_String;
      Standard_Err : U.Unbounded_String;
      Writes       : Write_Vectors.Vector;
      Stdin_Fails  : Boolean := False;
      Stdout_Fails : Boolean := False;
      Stderr_Fails : Boolean := False;
   end record;

   type Diagnostic_State is record
      Set      : Boolean := False;
      Id       : U.Unbounded_String;
      Category : U.Unbounded_String;
      Severity : U.Unbounded_String;
   end record;
end Awk_CLI_Context_State;
