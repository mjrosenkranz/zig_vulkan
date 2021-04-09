const std = @import("std");
const win = @import("window.zig");
const vk = @import("vulkan.zig");
const os = std.os;
const stdin = std.io.getStdIn().reader();
const Allocator = std.mem.Allocator;

var quit = false;

fn handler(sig: i32, info: *const os.siginfo_t, ctx_ptr: ?*const c_void) callconv(.C) void {
    if (sig == os.SIGINT)
        quit = true;

    std.debug.warn("\nShutting down...\n", .{});
}

pub fn main() !void {
    const window = try win.glfwwin(800, 600);
    defer window.destroy();

    var act = os.Sigaction{
        .handler = .{ .sigaction = handler },
        .mask = os.empty_sigset,
        .flags = (os.SA_SIGINFO | os.SA_RESETHAND),
    };
    os.sigaction(os.SIGINT, &act, null);

    const allocator = std.heap.c_allocator;

    var instance = try vk.createInstance(allocator, @TypeOf(window), window);
    defer vk.destroyInstance(instance);

    while (!quit) {
        var e: win.Event = window.poll();
        if (e == win.Event.Close) {
            quit = true;
        }
    }
}
