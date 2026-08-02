## Probe: the several ways a program can touch stdout.
import std/syncio

echo "via echo"
write stdout, "via write stdout\n"
stdout.write "via stdout.write\n"
flushFile(stdout)
