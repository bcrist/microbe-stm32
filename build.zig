const std = @import("std");

pub fn build(b: *std.Build) void {
    const microbe_arm_dep = b.dependency("microbe-arm", .{});

    const m0plus_chips: []const []const u8 = &.{
        "stm32g030c",
        "stm32g030f",
        "stm32g030j",
        "stm32g030k",
    };

    const m0plus_core_module = microbe_arm_dep.module("m0plus");
    for (m0plus_chips) |name| {
        _ = b.addModule(name, .{
            .source_file = .{ .path = "src/" ++ name ++ ".zig" },
            .dependencies = &.{
                .name = "core",
                .module = m0plus_core_module,
            },
        });
    }
}
