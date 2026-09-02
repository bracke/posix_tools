# Quickstart

Run direct programs, program files, standard input, and named input files:

```sh
awk '{ print $1 }' input.txt
awk -F: '{ print $1 }' /etc/passwd
awk -f script.awk data.txt
```
