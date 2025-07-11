const std = @import("std");
const Ast = @import("ast.zig").Ast;
const Allocator = std.mem.Allocator;

pub const Type = enum {
    t_int,
    t_float,
    t_bool,
    t_void,

    pub fn str(var_type: Type) []const u8 {
        switch (var_type) {
            .t_int => return "t_int",
            .t_float => return "t_float",
            .t_bool => return "t_bool",
            .t_void => return "t_void",
        }
    }
};

const VarSymbol = struct {
    // Is it ok to pass as slice? As original source would need to be alive,
    // is it ok to keep source code alive all the time?
    name: []u8,
    type: Type,
    // TODO: is this needed?
    expr_node: u32,
};

pub const SymbolTable = struct {
    pub var varTable: std.MultiArrayList(VarSymbol) = .empty;

    pub fn destroyTable(allocator: Allocator) void {
        varTable.deinit(allocator);
    }

    pub fn appendVar(allocator: Allocator, symbol: VarSymbol) usize {
        varTable.append(allocator, symbol) catch |err| {
            std.debug.print("Unable to create entry in varTable symbol table: {}", .{err});
        };

        return varTable.len - 1;
    }

    pub fn exists(name: []u8) bool {
        var exist: bool = false;
        for (varTable.items(.name)) |var_name| {
            if (std.mem.eql(u8, name, var_name)) exist = true;
        }
        return exist;
    }

    pub fn findByName(name: []u8) ?VarSymbol {
        for (0.., varTable.items(.name)) |i, var_name| {
            if (std.mem.eql(u8, name, var_name)) {
                return varTable.get(i);
            }
        }
        return null;
    }

    pub fn printVar() void {
        for (0.., varTable.items(.name), varTable.items(.type), varTable.items(.expr_node)) |idx, name, var_type, expr_node| {
            std.debug.print("{d})\nName: {s}\nVar Type: {s}\nExpr Node: {d}\n", .{ idx, name, var_type.str(), expr_node });
        }
    }
};

const ExprSymbol = struct {
    type: Type,
};

pub const ExprTypeTable = struct {
    pub var table: std.ArrayListUnmanaged(ExprSymbol) = .empty;

    pub fn appendExprType(allocator: Allocator, expr_type: Type) usize {
        table.append(allocator, .{ .type = expr_type }) catch |err| {
            std.debug.print("Unable to create entry in ExprSymbol: {}", .{err});
        };
        return table.items.len - 1;
    }

    pub fn printExprTypes() void {
        for (0.., table.items) |i, expr_type| {
            std.debug.print("{d}) Type: {s}\n", .{ i, expr_type.type.str() });
        }
    }

    pub fn destroyTable(allocator: Allocator) void {
        table.deinit(allocator);
    }
};

pub const FnCallSymbol = struct {
    name_node: usize,
    arguments: [10]usize,
    arguments_len: usize = 0,
};

pub const FnCallTable = struct {
    pub var table: std.ArrayListUnmanaged(FnCallSymbol) = .empty;

    pub fn appendFunction(allocator: Allocator, fn_call_symbol: FnCallSymbol) usize {
        table.append(allocator, fn_call_symbol) catch |err| {
            std.debug.print("Unable to create entry in FnCallTable: {}", .{err});
        };
        return table.items.len - 1;
    }

    pub fn printFunctions(source: []u8, ast: *Ast) void {
        for (0.., table.items) |i, function_call| {
            const name = ast.nodes.items[function_call.name_node];
            const args_len = function_call.arguments_len;
            std.debug.print("{d})\n", .{i});
            std.debug.print("Name: {s}\n", .{source[name.loc.start..name.loc.end]});
            std.debug.print("Argument: \n   Size: {d}\n", .{args_len});
            std.debug.print("   Nodes: \n", .{});
            for (0..args_len) |arg_idx| {
                const arg_node_idx = function_call.arguments[arg_idx];
                const arg_name = ast.nodes.items[arg_node_idx];
                std.debug.print("       {d}: {d} ({s})\n", .{ arg_idx, arg_node_idx, source[arg_name.loc.start..arg_name.loc.end] });
                std.debug.print("       Ast:---\n", .{});
                ast.print(arg_node_idx, 0, 5);
                std.debug.print("       ---\n", .{});
            }
            std.debug.print("\n-\n\n", .{});
        }
    }

    pub fn destroyTable(allocator: Allocator) void {
        table.deinit(allocator);
    }
};

pub const FnSymbol = struct {
    name_node: usize,
    return_type: Type,
    parameter_start: usize,
    parameter_end: usize,
    scope_idx: usize,
};

pub const FnParameterSymbol = struct {
    name_node: usize,
    parameter_type: Type,
};

pub const FnTable = struct {
    pub var table: std.ArrayListUnmanaged(FnSymbol) = .empty;
    pub var parameters: std.ArrayListUnmanaged(FnParameterSymbol) = .empty;

    pub fn appendFunction(allocator: Allocator, fn_symbol: FnSymbol) usize {
        table.append(allocator, fn_symbol) catch |err| {
            std.debug.print("Unable to create entry in FnTable: {}", .{err});
        };
        return table.items.len - 1;
    }

    pub fn getMainIdx(source: []u8, ast: Ast) !u32 {
        for (0.., table.items) |i, function| {
            const name = ast.nodes.items[function.name_node];
            const function_name = source[name.loc.start..name.loc.end];
            if (std.mem.eql(u8, function_name, "main")) {
                return @intCast(i);
            }
        }
        return error.MainNotFound;
    }

    pub fn getFunctionIdx(fn_call_name_node: usize, source: []u8, ast: Ast) !u32 {
        for (0.., table.items) |i, function| {
            const name = ast.nodes.items[function.name_node];
            const call_name = ast.nodes.items[fn_call_name_node];
            const function_name = source[name.loc.start..name.loc.end];
            const function_call_name = source[call_name.loc.start..call_name.loc.end];
            if (std.mem.eql(u8, function_name, function_call_name)) {
                return @intCast(i);
            }
        }
        return error.FunctionNotFound;
    }

    pub fn printFunctions(source: []u8, ast: Ast) void {
        for (0.., table.items) |i, function| {
            const name = ast.nodes.items[function.name_node];
            std.debug.print("{d})\n", .{i});
            std.debug.print("Name: {s}\n", .{source[name.loc.start..name.loc.end]});
            std.debug.print("Parameter: \n   Size: {d}\n", .{function.parameter_end - function.parameter_start});
            std.debug.print("   Types:\n", .{});
            for (function.parameter_start..function.parameter_end) |param_idx| {
                std.debug.print("       {d}: {s}\n", .{ param_idx, parameters.items[param_idx].parameter_type.str() });
            }
            std.debug.print("Return type: {s}\n", .{function.return_type.str()});
            std.debug.print("Scope's nodes: ", .{});
            const scope_table = MultiScopeTable.table.items[function.scope_idx];
            for (scope_table.items) |node_idx| {
                std.debug.print("{d}, ", .{node_idx});
            }
            std.debug.print("\n-\n\n", .{});
        }
    }

    pub fn destroyTable(allocator: Allocator) void {
        table.deinit(allocator);
        parameters.deinit(allocator);
    }
};

pub const IfSymbol = struct {
    if_scope_idx: usize,
    else_scope_idx: usize,
};

pub const IfTable = struct {
    pub var table: std.ArrayListUnmanaged(IfSymbol) = .empty;

    pub fn appendIf(allocator: Allocator, if_symbol: IfSymbol) usize {
        table.append(allocator, if_symbol) catch |err| {
            std.debug.print("Unable to create entry in FnTable: {}", .{err});
        };
        return table.items.len - 1;
    }

    pub fn printIfs() void {
        for (0.., table.items) |i, if_symbol| {
            std.debug.print("{d})\n", .{i});
            std.debug.print("If Scope Idx: {d}\n", .{if_symbol.if_scope_idx});
            std.debug.print("Else Scope Idx: {d}\n", .{if_symbol.else_scope_idx});
        }
    }

    pub fn destroyTable(allocator: Allocator) void {
        table.deinit(allocator);
    }
};

pub const MultiScopeTable = struct {
    pub var table: std.ArrayListUnmanaged(std.ArrayListUnmanaged(usize)) = .empty;

    pub fn createScope(allocator: std.mem.Allocator) usize {
        table.append(allocator, .empty) catch |err| {
            std.debug.print("Unable to create scope entry in multi-scope table: {}", .{err});
        };
        return table.items.len - 1;
    }

    pub fn destroyTable(allocator: std.mem.Allocator) void {
        for (table.items) |*scope| {
            scope.deinit(allocator);
        }
        table.deinit(allocator);
    }
};
