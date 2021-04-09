//! Wrapper for our game window
const std = @import("std");
const c = @cImport(
    @cInclude("GLFW/glfw3.h"),
);

/// Window error union
const WindowError = error{ GlfwInitFailed, GlfwCreateWindowFailed };

pub const Event = enum { None, Close };

pub fn Window(
    comptime inner: type,
    comptime destroyFn: fn (win: inner) void,
    comptime pollFn: fn (win: inner) Event,
) type {
    return struct {
        win: inner,
        const Self = @This();
        pub fn destroy(self: Self) void {
            destroyFn(self.win);
        }
        pub fn poll(self: Self) Event {
            return pollFn(self.win);
        }
    };
}

pub const GLFWwintype = Window(*c.GLFWwindow, GLFWDestroy, GLFWPoll);

fn GLFWDestroy(win: *c.GLFWwindow) void {
    c.glfwDestroyWindow(win);
    c.glfwTerminate();
}

fn GLFWPoll(win: *c.GLFWwindow) Event {
    c.glfwPollEvents();
    if (c.glfwWindowShouldClose(win) != 0) {
        return Event.Close;
    }

    // TODO: add more events hehe

    return Event.None;
}

pub fn Create(w: u32, h: u32) !Window {
    // TODO: dynamic dispatch here based on system
    // for now just calls this guy
    return glfwwin(w, h);
}

/// Creates a glfw window
pub fn glfwwin(w: u32, h: u32) WindowError!GLFWwintype {
    if (c.glfwInit() == 0) return error.GlfwInitFailed;

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    // delete this later
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);

    const win = c.glfwCreateWindow(@bitCast(c_int, w), @bitCast(c_int, h), "Vulkan", null, null) orelse return error.GlfwCreateWindowFailed;
    return GLFWwintype{ .win = win };
}
