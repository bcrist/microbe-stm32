const std = @import("std");
const chip = @import("chip");
const util = @import("chip_util");

pub const Type = chip.registers.InterruptType;

pub fn isEnabled(comptime interrupt: Type) bool {
    if (@intFromEnum(interrupt) >= 0) {
        return @field(chip.registers.SCS.NVIC.ISER.read(), @tagName(interrupt)) == 1;
    } else {
        return true;
    }
}

pub fn setEnabled(comptime interrupt: Type, comptime enabled: bool) void {
    if (@intFromEnum(interrupt) >= 0) {
        if (enabled) {
            const ISER_Type = chip.registers.SCS.NVIC.ISER.underlying_type;
            const val = ISER_Type{};
            @field(val, @tagName(interrupt)) = 1;
            chip.registers.SCS.NVIC.ISER.write(val);
        } else {
            const ICER_Type = chip.registers.SCS.NVIC.ICER.underlying_type;
            const val = ICER_Type{};
            @field(val, @tagName(interrupt)) = 1;
            chip.registers.SCS.NVIC.ICER.write(val);
        }
    } else {
        @compileError("This exception is permanently enabled!");
    }
}

pub const configureEnables = util.configureInterruptEnables;

pub fn getPriority(comptime interrupt: Type) u8 {
    if (@intFromEnum(interrupt) >= 0) {
        const reg_name = std.fmt.comptimePrint("IP{}", .{@as(u5, @intCast(@intFromEnum(interrupt))) / 4});
        const val = @field(chip.registers.SCS.NVIC, reg_name).read();
        return @shlExact(@as(u8, @intCast(@field(val, @tagName(interrupt)))), 4);
    } else return @shlExact(@as(u8, @intCast(switch (interrupt) {
        .SVCall => chip.registers.SCS.SCB.SHPR2.read().SVCALLPRI,
        .PendSV => chip.registers.SCS.SCB.SHPR3.read().PENDSVPRI,
        .SysTick => chip.registers.SCS.SCB.SHPR3.read().SYSTICKPRI,
        else => @compileError("Exception priority is fixed!"),
    })), 4);
}

pub fn setPriority(comptime interrupt: Type, priority: u8) void {
    const p4: u4 = @as(u4, @intCast(@shrExact(priority, 4)));
    if (@intFromEnum(interrupt) >= 0) {
        const reg_name = std.fmt.comptimePrint("IP{}", .{@as(u5, @intCast(@intFromEnum(interrupt))) / 4});
        const val = @field(chip.registers.SCS.NVIC, reg_name).read();
        @field(val, @tagName(interrupt)) = p4;
        @field(chip.registers.SCS.NVIC, reg_name).write(val);
    } else switch (interrupt) {
        .SVCall => chip.registers.SCS.SCB.SHPR2.modify(.{ .SVCALLPRI = p4 }),
        .PendSV => chip.registers.SCS.SCB.SHPR3.modify(.{ .PENDSVPRI = p4 }),
        .SysTick => chip.registers.SCS.SCB.SHPR3.modify(.{ .SYSTICKPRI = p4 }),
        else => @compileError("Exception priority is fixed!"),
    }
}

pub const configurePriorities = util.configureInterruptPriorities;

pub fn isPending(comptime interrupt: Type) bool {
    if (@intFromEnum(interrupt) >= 0) {
        return @field(chip.registers.SCS.NVIC.ISPR.read(), @tagName(interrupt)) != 0;
    } else return switch (interrupt) {
        .NMI => chip.registers.SCS.NVIC.ICSR.read().NMIPENDSET != 0,
        .PendSV => chip.registers.SCS.NVIC.ICSR.read().PENDSVSET != 0,
        .SysTick => chip.registers.SCS.NVIC.ICSR.read().PENDSTSET != 0,
        else => @compileError("Unsupported exception type!"),
    };
}

pub fn setPending(comptime interrupt: Type, comptime pending: bool) void {
    if (@intFromEnum(interrupt) >= 0) {
        if (pending) {
            const ISPR_Type = chip.registers.SCS.NVIC.ISPR.underlying_type;
            const val = ISPR_Type{};
            @field(val, @tagName(interrupt)) = 1;
            chip.registers.SCS.NVIC.ISPR.write(val);
        } else {
            const ICPR_Type = chip.registers.SCS.NVIC.ICPR.underlying_type;
            const val = ICPR_Type{};
            @field(val, @tagName(interrupt)) = 1;
            chip.registers.SCS.NVIC.ICPR.write(val);
        }
    } else switch (interrupt) {
        .NMI => {
            if (!pending) {
                @compileError("NMI can't be unpended!");
            }
            const ICSR_Type = chip.registers.SCS.NVIC.ICSR.underlying_type;
            const val = ICSR_Type{};
            @field(val, @tagName(interrupt)) = 1;
            chip.registers.SCS.NVIC.ICSR.write(val);
        },
        .PendSV => {
            const ICSR_Type = chip.registers.SCS.NVIC.ICSR.underlying_type;
            const val = ICSR_Type{};
            if (pending) {
                val.PENDSVSET = 1;
            } else {
                val.PENDSVSET = 0;
            }
            chip.registers.SCS.NVIC.ICSR.write(val);
        },
        .SysTick => {
            const ICSR_Type = chip.registers.SCS.NVIC.ICSR.underlying_type;
            const val = ICSR_Type{};
            if (pending) {
                val.PENDSTSET = 1;
            } else {
                val.PENDSTSET = 0;
            }
            chip.registers.SCS.NVIC.ICSR.write(val);
        },
        else => @compileError("Unsupported exception type!"),
    }
}

pub fn areGloballyEnabled() bool {
    return !asm volatile ("mrs r0, primask"
        : [ret] "={r0}" (-> bool),
        :
        : "r0"
    );
}

pub fn setGloballyEnabled(comptime enabled: bool) void {
    if (enabled) {
        asm volatile ("cpsie i");
    } else {
        asm volatile ("cpsid i");
    }
}

pub fn waitForInterrupt() void {
    asm volatile ("wfi");
}

pub fn isInterrupting() bool {
    return !asm volatile ("mrs r0, ipsr"
        : [ret] "={r0}" (-> bool),
        :
        : "r0"
    );
}
