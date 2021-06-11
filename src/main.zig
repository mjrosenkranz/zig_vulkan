const std = @import("std");
const win = @import("window.zig");
const renderer = @import("renderer/vulkan.zig");
const os = std.os;

pub fn loop(window: *win.Window) void {
    while (window.flush()) {

    }
}

const allocator = std.heap.page_allocator;
pub fn main() !void {
    var w = try win.xcb.init(.{});
    errdefer w.deinit();

    var ren = try renderer.init(allocator);
    defer ren.deinit();

    loop(&w.window);
}
