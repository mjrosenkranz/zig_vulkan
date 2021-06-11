///! Interface for all windows we can access

const std = @import("std");
const Window = @This();

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

/// Captures all events on this window
pub fn flush(self: *Window) bool {
    return self.flushFn(self);
}

pub fn resize(self: *Window, dims: Geom) !void {
    self.geom = dims;
}
