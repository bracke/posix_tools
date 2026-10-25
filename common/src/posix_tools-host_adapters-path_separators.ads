--  How this host spells the separator between pathname components, for
--  command algorithms that must accept a host spelling where POSIX writes '/'.
package Posix_Tools.Host_Adapters.Path_Separators is
   --  The host's own separator: '/' on POSIX hosts, '\' on Windows.
   function Directory_Separator return Character;
end Posix_Tools.Host_Adapters.Path_Separators;
