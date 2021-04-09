const std = @import("std");
const stdin = std.io.getStdIn().reader();
const win = @import("window.zig");

pub fn main() !void {
    const window = try win.glfwwin(800, 600);
    defer window.destroy();

    var buf: [1]u8 = undefined;
    _ = try stdin.readUntilDelimiterOrEof(buf[0..], '\n');
}
