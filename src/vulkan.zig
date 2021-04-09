const std = @import("std");
const win = @import("window.zig");
const Allocator = std.mem.Allocator;
const c = @cImport({
    @cInclude("GLFW/glfw3.h");
    @cInclude("vulkan/vulkan.h");
});

const stype = c.enum_VkStructureType;

/// Initialize vulkan!
//pub fn init() !void {
//    try createInstance();
//}

pub fn createInstance(allocator: *Allocator, comptime wtype: type, window: wtype) !void {
    var appInfo: c.VkApplicationInfo = undefined;

    appInfo.sType = stype.VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = "Hello Triangle";
    appInfo.applicationVersion = c.VK_MAKE_VERSION(1, 0, 0);
    appInfo.pEngineName = "No Engine";
    appInfo.engineVersion = c.VK_MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = c.VK_API_VERSION_1_0;

    var createInfo: c.VkInstanceCreateInfo = undefined;

    createInfo.sType = stype.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo = &appInfo;

    var extensions = window.getExt(allocator);
}
