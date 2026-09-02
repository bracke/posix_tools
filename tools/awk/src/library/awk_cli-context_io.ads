with Ada.Strings.Unbounded;

with Awk_CLI.Environment;
with Awk_CLI.Platform;
with Awk_CLI.Redirections;

package Awk_CLI.Context_IO is
   --  Invocation-context I/O mutation helpers.
   --
   --  This child package owns captured stream storage, virtual file I/O, and
   --  process-backed environment access for an invocation context. AWK output
   --  content is forwarded exactly and never localized or styled.

   package U renames Ada.Strings.Unbounded;

   --  @param Context Invocation context to inspect.
   --  @param Path Virtual file path to read.
   --  @param Content Complete virtual file text when reading succeeds.
   --  @param Found True when Path matched a virtual file entry.
   --  @return Read status for a found virtual file; Open_Failed when absent.
   function Read_Virtual_File
     (Context : Invocation_Context;
      Path    : String;
      Content : out U.Unbounded_String;
      Found   : out Boolean) return Awk_CLI.Platform.Read_Status;

   --  @param Context Invocation context to inspect.
   --  @param Path Host or virtual file path to read.
   --  @param Content Complete file text when reading succeeds.
   --  @return Read status distinguishing success, open failure, and read failure.
   function Read_File
     (Context : Invocation_Context;
      Path    : String;
      Content : out U.Unbounded_String) return Awk_CLI.Platform.Read_Status;

   --  @param Context Invocation context to update.
   --  @param Content Exact standard-output content to write.
   --  @return True when output was accepted by the context and host.
   function Write_Standard_Output
     (Context : in out Invocation_Context;
      Content : String) return Boolean;

   --  @param Context Invocation context to update.
   --  @param Content Exact diagnostic or help text to write.
   --  @return True when output was accepted by the context and host.
   function Write_Standard_Error
     (Context : in out Invocation_Context;
      Content : String) return Boolean;

   --  @param Context Invocation context to update.
   --  @param Path Redirection target path.
   --  @param Content Exact redirected output content to write.
   --  @param Append Whether append semantics are requested.
   --  @return Host redirection write status.
   function Write_File
     (Context : in out Invocation_Context;
      Path    : String;
      Content : String;
      Append  : Boolean) return Awk_CLI.Redirections.Write_Status;

   --  @param Context Invocation context to inspect.
   --  @return Normalized environment entries for interpreter execution.
   function Current_Environment
     (Context : Invocation_Context) return Awk_CLI.Environment.Entry_Vectors.Vector;
end Awk_CLI.Context_IO;
