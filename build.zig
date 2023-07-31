const std = @import("std");

pub fn build(b: *std.Build) void {
    const chips: []const []const u8 = &.{
        "stm32g030c",
        "stm32g030f",
        "stm32g030j",
        "stm32g030k",
    };

    const microbe_rt_dep = b.dependency("microbe-rt", .{});
    const microbe_rt_module = microbe_rt_dep.module("microbe");
    const chip_util_module = microbe_rt_dep.module("chip_util");
    for (chips) |name| {
        const module = b.addModule(name, .{
            .source_file = .{
                .path = std.fmt.allocPrint(b.allocator, "src/{s}.zig", .{ name }) catch unreachable,
            },
            .dependencies = &.{
                .{ .name = "microbe", .module = microbe_rt_module },
                .{ .name = "chip_util", .module = chip_util_module },
            },
        });
        module.dependencies.put("chip", module) catch unreachable;
    }
}
