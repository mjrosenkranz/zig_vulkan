const std = @import("std");
const stdin = std.io.getStdIn().reader();
const win = @import("window.zig");

pub fn main() !void {
    const window = try win.glfwwin(800, 600);
    defer window.destroy();

    var quit = false;
    while (!quit) {
        var e: win.Event = window.poll();
        if (e == win.Event.Close) {
            quit = true;
        }
    }
}
