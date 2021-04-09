const c = @cImport(
    @cInclude("GLFW/glfw3.h"),
);

const WindowError = error{ GlfwInitFailed, GlfwCreateWindowFailed };

pub fn Window(
    comptime inner: type,
    comptime destroyFn: fn (win: inner) void,
) type {
    return struct {
        win: inner,
        const Self = @This();
        pub fn destroy(self: Self) void {
            destroyFn(self.win);
        }
    };
}

pub const GLFWwintype = Window(*c.GLFWwindow, GLFWDestroy);

fn GLFWDestroy(win: *c.GLFWwindow) void {
    c.glfwDestroyWindow(win);
    c.glfwTerminate();
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

    // TODO: cast to c type
    const win = c.glfwCreateWindow(800, 600, "Vulkan", null, null) orelse return error.GlfwCreateWindowFailed;
    return GLFWwintype{ .win = win };
}
