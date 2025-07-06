const std = @import("std");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const tables = @import("tables.zig");
const SymbolTable = tables.SymbolTable;
const ExprTypeTable = tables.ExprTypeTable;
const FnTable = tables.FnTable;
const FnCallTable = tables.FnCallTable;
const IfTable = tables.IfTable;
const MultiScopeTable = tables.MultiScopeTable;
const analyzer = @import("analyzer.zig");

const wasm_codegen = @import("wasm/codegen.zig");

var gp: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    var allocator = gp.allocator();
    defer _ = gp.deinit();

    var source_name: [50]u8 = undefined;
    var source_name_len: usize = 0;

    {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);

        if (args.len > 1) {
            source_name_len = args[1].len;
            @memcpy(source_name[0..source_name_len], args[1]);
            // source_name = args[1];
        } else {
            std.debug.print("Expected 1 argument as file name. Found none.\n", .{});
            return error.ExpectedArgumentFoundNone;
        }
    }

    std.debug.print("File: {s}\n", .{source_name[0..source_name_len]});

    var file = try std.fs.cwd().openFile(source_name[0..source_name_len], .{});
    defer file.close();

    const buffer_size = 10000;
    const source = try file.readToEndAlloc(allocator, buffer_size);
    defer allocator.free(source);

    var tokenizer = Tokenizer.init(allocator, source, source_name[0..source_name_len]);
    defer tokenizer.deinit();

    tokenizer.tokenize();
    std.debug.print("\n------ TOKENS ------\n", .{});
    tokenizer.print();

    SymbolTable.createTables(allocator);
    defer SymbolTable.destroyTable();

    ExprTypeTable.createTable(allocator);
    defer ExprTypeTable.destroyTable();

    FnTable.createTable(allocator);
    defer FnTable.destroyTable();

    FnCallTable.createTable(allocator);
    defer FnCallTable.destroyTable();

    IfTable.createTable(allocator);
    defer IfTable.destroyTable();

    defer MultiScopeTable.destroyTable(allocator);

    var parser = Parser.init(allocator, tokenizer);
    defer parser.deinit();

    parser.parse(allocator);
    analyzer.analyze(&parser);

    std.debug.print("\n------ AST ------\n", .{});
    parser.ast.printAst(&parser.ast_roots);

    std.debug.print("\n------ VAR SYMBOL TABLE ------\n", .{});
    SymbolTable.printVar();

    std.debug.print("\n------ EXPR TYPE TABLE -------\n", .{});
    ExprTypeTable.printExprTypes();

    std.debug.print("\n------ FN TABLE -------\n", .{});
    FnTable.printFunctions(source, parser.ast);

    std.debug.print("\n------ FN CALL TABLE -------\n", .{});
    FnCallTable.printFunctions(source, &parser.ast);

    std.debug.print("\n------ IFs TABLE -------\n", .{});
    IfTable.printIfs();

    std.debug.print("\n-----------------------------\n", .{});

    var out_file = try std.fs.cwd().createFile("out.wasm", .{});
    defer out_file.close();

    try wasm_codegen.outputFile(out_file, &parser, source, allocator);
}
