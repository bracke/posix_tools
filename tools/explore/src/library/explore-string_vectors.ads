with Ada.Containers.Indefinite_Vectors;

--  A list of strings, as explore passes paths, lines, and patterns around.
package Explore.String_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);
