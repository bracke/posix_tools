with Posix_Tools.Version;

--  Authoritative version identity.
--
--  The version comes from the Alire crate configuration, which Alire itself
--  derives from alire.toml. There is therefore no second place to update and
--  no way for the manifest, the executable and the release artifacts to
--  disagree; posix_tools package checks ship this metadata with the command.
--
--  Nothing here is a build timestamp, host name, user name, absolute path or
--  any other value that would make two builds of the same source differ.
package Sed.Version is

   --  posix_tools release version.
   Value : constant String := Posix_Tools.Version.Version_String;

   --  Crate name, which is also the installed executable name.
   Crate : constant String := "sed";

   --  Distribution licence identifier.
   License : constant String := "MIT";

   --  Name of the sed-language engine this program is built against.
   Engine_Name : constant String := "sedlib";

   --  Engine version this build was compiled against.
   --
   --  The Alire manifest pins sedlib exactly, so the reported engine version
   --  should track the one actually linked in.
   Engine_Version : constant String := "0.1.0-dev";

   --  Whether this version is a prerelease.
   --
   --  The program must not present itself as a completed POSIX-conforming
   --  release while the documented baseline is still being finished.
   --
   --  @return True when the version carries a prerelease suffix.
   function Is_Prerelease return Boolean
     is (for some Index in Value'Range => Value (Index) = '-');

end Sed.Version;
