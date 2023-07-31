const std = @import("std");
const root = @import("root");
const microbe = @import("microbe");
const registers = @import("registers.zig");
const clocks = @import("clocks.zig");
const VectorTable = registers.VectorTable;
const InterruptType = registers.InterruptType;

// This comes from the linker and indicates where the stack segment ends, which
// is where the initial stack pointer should be.  It's not a function, but by
// pretending that it is, zig realizes that its address is constant, which doesn't
// happen with declaring it as extern const anyopaque and then taking its address.
// We need it to be comptime constant so that we can put it in the comptime
// constant VectorTable.
extern fn _stack_end() void;

// Defined in the config module
extern fn _init_ram() void;

/// This is the logical entry point for microbe.
/// It will invoke the main function from the root source file and provide error return handling
/// align(4) shouldn't be necessary here, but sometimes zig ends up using align(2) on arm for some reason...
export fn _start() align(4) callconv(.C) noreturn {
    if (!@hasDecl(root, "main")) {
        @compileError("The root source file must provide a public function main!");
    }

    _init_ram();

    if (@hasDecl(root, "init")) {
        root.init();
    }

    clocks.init(root.clocks);

    const main_fn = @field(root, "main");
    const info: std.builtin.Type = @typeInfo(@TypeOf(main_fn));

    if (info != .Fn or info.Fn.params.len > 0) {
        @compileError("main must be either 'pub fn main() void' or 'pub fn main() !void'.");
    }

    if (info.Fn.calling_convention == .Async) {
        @compileError("TODO: Event loop not supported.");
    }

    if (@typeInfo(info.Fn.return_type.?) == .ErrorUnion) {
        main_fn() catch |err| @panic(@errorName(err));
    } else {
        main_fn();
    }

    // TODO consider putting the core to sleep?

    microbe.hang();
}

export const vector_table: VectorTable linksection(".vector_table") = blk: {
    var tmp: VectorTable = .{
        .initial_stack_pointer = _stack_end,
        .Reset = .{ .C = _start },
    };
    if (@hasDecl(root, "interrupts")) {
        if (@typeInfo(root.interrupts) != .Struct)
            @compileLog("root.interrupts must be a struct");

        inline for (@typeInfo(root.interrupts).Struct.decls) |decl| {
            const function = @field(root.interrupts, decl.name);

            if (!@hasField(VectorTable, decl.name) or !@hasField(InterruptType, decl.name)) {
                var msg: []const u8 = "There is no such interrupt as '" ++ decl.name ++ "'. Declarations in 'interrupts' must be one of:\n";
                inline for (std.meta.fields(VectorTable)) |field| {
                    if (@hasField(InterruptType, field.name)) {
                        msg = msg ++ "    " ++ field.name ++ "\n";
                    }
                }

                @compileError(msg);
            }

            @field(tmp, decl.name) = createInterruptVector(function);
        }
    }
    break :blk tmp;
};

fn createInterruptVector(comptime function: anytype) InterruptVector {
    const calling_convention = @typeInfo(@TypeOf(function)).Fn.calling_convention;
    return switch (calling_convention) {
        .C => .{ .C = function },
        .Naked => .{ .Naked = function },
        // for unspecified calling convention we are going to generate small wrapper
        .Unspecified => .{
            .C = struct {
                fn wrapper() callconv(.C) void {
                    if (calling_convention == .Unspecified) // TODO: workaround for some weird stage1 bug
                        @call(.{ .modifier = .always_inline }, function, .{});
                }
            }.wrapper,
        },

        else => |val| {
            const conv_name = inline for (std.meta.fields(std.builtin.CallingConvention)) |field| {
                if (val == @field(std.builtin.CallingConvention, field.name))
                    break field.name;
            } else unreachable;

            @compileError("unsupported calling convention for interrupt vector: " ++ conv_name);
        },
    };
}

pub fn flushInstructionCache() void {
    asm volatile ("isb");
}
pub fn instructionFence() void {
    asm volatile ("dsb");
}
pub fn memoryFence() void {
    asm volatile ("dmb");
}

pub fn softReset() void {
    registers.SCS.SCB.AIRCR.write(.{
        .SYSRESETREQ = 1,
        .VECTKEY = 0x05FA,
    });
}
