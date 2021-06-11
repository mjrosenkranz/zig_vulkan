///! Interface for all windows we can access
const std = @import("std");
const Window = @This();
const c = @import("../c.zig");

/// Window geometry
pub const Geom = struct {
    x: i16 = 100,
    y: i16 = 100,
    w: u16 = 100,
    h: u16 = 100,
};

geom: Geom = .{},
/// Captures all events on this window
flushFn: fn (self: *Window) bool,
// Function for getting the surface
vksurfaceFn: fn (self: *Window, instance: *c.VkInstance) anyerror!c.VkSurfaceKHR,

/// Captures all events on this window
pub fn flush(self: *Window) bool {
    return self.flushFn(self);
}

pub fn getVkSurface(self: *Window, instance: *c.VkInstance) !c.VkSurfaceKHR {
    return self.vksurfaceFn(self, instance);
}

pub fn resize(self: *Window, dims: Geom) !void {
    self.geom = dims;
}
