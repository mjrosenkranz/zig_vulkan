//! Wrapper for our game window
const std = @import("std");
const Window = @import("../window.zig").Window;
const Allocator = std.mem.Allocator;
const c = @cImport(
    @cInclude("GLFW/glfw3.h"),
);

pub const glfwWindow = struct {
    window: Window = .{
        .flushFn = flush,
    },

    const Self = @This();

    pub fn init(dims: Window.Geom) Self {
        return .{
            .window = .{
                .flushFn = flush,
                .geom = dims,
            },
        };
    }

    pub fn deinit() void {

    }

    fn flush(window: *Window) bool {
        const self = @fieldParentPtr(Self, "window", window);
        std.log.info("flush from glfw x: {}", .{window.geom.x});
        return true;
    }
};

///// Window error union
//const WindowError = error{ GlfwInitFailed, GlfwCreateWindowFailed };
//
//pub const Event = enum { None, Close };
//
//pub const Window: type = comptime {
//    // TODO change based on platform
//    return GLFWwintype;
//};
//
//pub fn WindowType(
//    comptime inner: type,
//    comptime destroyFn: fn (win: inner) void,
//    comptime pollFn: fn (win: inner) Event,
//    comptime getExtFn: fn (win: inner, allocator: *Allocator) Allocator.Error![][*]const u8,
//) type {
//    return struct {
//        win: inner,
//        const Self = @This();
//        pub fn destroy(self: Self) void {
//            destroyFn(self.win);
//        }
//        pub fn poll(self: Self) Event {
//            return pollFn(self.win);
//        }
//        pub fn getExt(self: Self, allocator: *Allocator) ![][*]const u8 {
//            return getExtFn(self.win, allocator);
//        }
//    };
//}
//
//pub const GLFWwintype = WindowType(*c.GLFWwindow, GLFWDestroy, GLFWPoll, GLFWExt);
//
///// Creates a glfw window
//pub fn glfwwin(w: u32, h: u32) WindowError!GLFWwintype {
//    if (c.glfwInit() == 0) return error.GlfwInitFailed;
//
//    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
//    // delete this later
//    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);
//
//    const win = c.glfwCreateWindow(@bitCast(c_int, w), @bitCast(c_int, h), "Vulkan", null, null) orelse return error.GlfwCreateWindowFailed;
//    return GLFWwintype{ .win = win };
//}
//
//fn GLFWDestroy(win: *c.GLFWwindow) void {
//    c.glfwDestroyWindow(win);
//    c.glfwTerminate();
//}
//
//fn GLFWPoll(win: *c.GLFWwindow) Event {
//    c.glfwPollEvents();
//    if (c.glfwWindowShouldClose(win) != 0) {
//        return Event.Close;
//    }
//
//    // TODO: add more events hehe
//
//    return Event.None;
//}
//
//fn GLFWExt(win: *c.GLFWwindow, allocator: *Allocator) Allocator.Error![][*]const u8 {
//    var extCount: u32 = 0;
//    var ext_arr = @ptrCast([*]const [*]const u8, c.glfwGetRequiredInstanceExtensions(&extCount));
//
//    // convert to arraylist
//    var extensions = std.ArrayList([*]const u8).init(allocator);
//    errdefer extensions.deinit();
//    try extensions.appendSlice(ext_arr[0..extCount]);
//    // add validation later I guess
//    //try extensions.append(c.VK_EXT_DEBUG_REPORT_EXTZENSION_NAME);
//
//    return extensions.toOwnedSlice();
//}
//
//pub fn Create(w: u32, h: u32) !Window {
//    // TODO: dynamic dispatch here based on system
//    // for now just calls this guy
//    return glfwwin(w, h);
//}
