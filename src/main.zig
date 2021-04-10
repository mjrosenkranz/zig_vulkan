const std = @import("std");
const win = @import("window.zig");
const vk = @import("vulkan.zig");
const os = std.os;
const stdin = std.io.getStdIn().reader();
const Allocator = std.mem.Allocator;

const allocator = std.heap.c_allocator;
var window = undefined;
var instance = undefined;
var quit = false;

pub fn init() !void {
    var act = os.Sigaction{
        .handler = .{ .sigaction = handler },
        .mask = os.empty_sigset,
        .flags = (os.SA_SIGINFO | os.SA_RESETHAND),
    };
    os.sigaction(os.SIGINT, &act, null);
    window = try win.glfwwin(800, 600);
    instance = try vk.createInstance(allocator, @TypeOf(window), window);
}

pub fn shutdown() void {
    vk.destroyInstance(instance);
    window.destroy();
}

pub fn main() !void {
    try init();
    while (!quit) {
        var e: win.Event = window.poll();
        if (e == win.Event.Close) {
            quit = true;
        }
    }
    shutdown();
}

fn handler(sig: i32, info: *const os.siginfo_t, ctx_ptr: ?*const c_void) callconv(.C) void {
    if (sig == os.SIGINT)
        quit = true;
    std.debug.warn("\nShutting down...\n", .{});
    shutdown();
}
