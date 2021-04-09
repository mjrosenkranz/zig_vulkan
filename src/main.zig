const std = @import("std");

const c = @cImport(
    @cInclude("GLFW/glfw3.h"),
);

pub fn initWindow() anyerror!*c.GLFWwindow {
    if (c.glfwInit() == 0) return error.GlfwInitFailed;

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    // delete this later
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);

    return c.glfwCreateWindow(800, 600, "Vulkan", null, null) orelse error.GlfwCreateWindowFailed;
}

pub fn destroyWindow(window: *c.GLFWwindow) void {
    c.glfwDestroyWindow(window);
    c.glfwTerminate();
}

pub fn main() !void {
    const win = try initWindow();
    defer destroyWindow(win);

    std.time.sleep(3000000000);
}
