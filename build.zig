const std = @import("std");

pub fn build(b: *std.Build) void {
    const microbe_arm_dep = b.dependency("microbe-arm", .{});
    const microbe_rt_dep = b.dependency("microbe-rt", .{});
    const microbe_rt_module = microbe_rt_dep.module("microbe");
    const chip_util_module = microbe_rt_dep.module("chip_util");

    const m0plus_chips: []const []const u8 = &.{
        "stm32g030c",
        "stm32g030f",
        "stm32g030j",
        "stm32g030k",
    };

    const m0plus_core_module = microbe_arm_dep.module("m0plus");
    for (m0plus_chips) |name| {
        const module = b.addModule(name, .{
            .source_file = .{
                .path = std.fmt.allocPrint(b.allocator, "src/{s}.zig", .{ name }) catch unreachable,
            },
            .dependencies = &.{
                .{ .name = "microbe", .module = microbe_rt_module },
                .{ .name = "chip_util", .module = chip_util_module },
                .{ .name = "core", .module = m0plus_core_module },
            },
        });
        module.dependencies.put("chip", module) catch unreachable;
    }
}
