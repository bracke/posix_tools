# rg examples

The native Ada executable supports bounded sequential searches of standard
input, explicit files, and recursive directory roots. For example:

```text
rg -S Ada src
rg --hidden --max-depth 2 -F TODO .
```

Run `rg --help` for the currently supported compatibility surface.
