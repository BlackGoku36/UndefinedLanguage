
# TODO

- Types: Struct, Enum, Array, String.

- Functions: Foreign Function/Variable Interface, to interact with JS without any hardcoding.

- Loops: For loop. Also break and continue of course.

## Bugs in compiler

1.
```
var x: float = 5;// generate x it as int and not float
```
PARSER: The 5 is parsed as int instead of float.
CodeGen: false positive. It generate the code treating it as int, when it should generate float.