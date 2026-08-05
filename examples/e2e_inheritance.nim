import std/syncio
type
  Animal = ref object of RootObj
    name: string
  Dog = ref object of Animal
    tricks: int
method speak(a: Animal): string {.base.} = "..."
method speak(d: Dog): string = "woof"
var xs: seq[Animal] = @[]
xs.add Animal(name: "generic")
xs.add Dog(name: "rex", tricks: 3)
for a in xs:
  echo a.name & ":" & speak(a)
