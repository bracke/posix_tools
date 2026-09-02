with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
private with Awk_CLI_Context_State;

package Awk_CLI is
   --  Testable top-level runner for the awk executable.
   --
   --  This package is internal CLI infrastructure. It is public only so the
   --  executable and AUnit harness can exercise the same code path; it is not
   --  a stable reusable library API.

   type Exit_Code is range 0 .. 255;

   type Invocation_Context is tagged limited private;
   --  Complete host invocation model used by the runner.

   package String_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Ada.Strings.Unbounded.Unbounded_String,
      "="          => Ada.Strings.Unbounded."=");

   --  @param Context Invocation context to populate from the process.
   procedure Initialize_From_Process (Context : in out Invocation_Context);

   --  @param Context Invocation context to reset.
   procedure Clear (Context : in out Invocation_Context);

   --  @param Context Invocation context to execute.
   --  @return Stable process exit code.
   function Run (Context : in out Invocation_Context) return Exit_Code;

private
   package U renames Ada.Strings.Unbounded;
   package State renames Awk_CLI_Context_State;

   Default_Locale : constant String := "en";
   Default_Catalog_Path : constant String := "resources/messages/catalog.txt";

   type Invocation_Configuration is record
      Arguments       : String_Vectors.Vector;
      Locale          : U.Unbounded_String := U.To_Unbounded_String (Default_Locale);
      Catalog_Path    : U.Unbounded_String :=
        U.To_Unbounded_String (Default_Catalog_Path);
      Use_Process     : Boolean := False;
      Stdout_Terminal : Boolean := False;
      Stderr_Terminal : Boolean := False;
      No_Color        : Boolean := False;
   end record;

   type Invocation_Context is tagged limited record
      Config          : Invocation_Configuration;
      IO              : State.Virtual_IO_State;
      Last_Diagnostic : State.Diagnostic_State;
   end record;
end Awk_CLI;
