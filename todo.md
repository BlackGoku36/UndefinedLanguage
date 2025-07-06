
# TODO

- Implement parser for function parameters and function return type
- Implement WASM codegen for function parameters and return
- Implement parser and WASM codegen for branches
- Implement parser and WASM codegen for loops

## Bugs in compiler

1.
```
var x: float = 5;// generate x it as int and not float
```
PARSER: The 5 is parsed as int instead of float.
CodeGen: false positive. It generate the code treating it as int, when it should generate float.