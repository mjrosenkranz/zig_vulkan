const std = @import("std");
const win = @import("window.zig");
const Allocator = std.mem.Allocator;
const c = @cImport({
    @cInclude("GLFW/glfw3.h");
    @cInclude("vulkan/vulkan.h");
    //@cInclude("vulkan/vulkan.h");
});

const stype = c.enum_VkStructureType;

pub fn vksucess(result: c.enum_VkResult) !void {
    if (result != c.enum_VkResult.VK_SUCCESS) {
        return error.Unexpected;
    }
}

/// Initialize vulkan!
//pub fn init() !void {
//    try createInstance();
//}

pub fn createInstance(allocator: *Allocator, comptime wtype: type, window: wtype) !void {
    var instance: c.VkInstance = undefined;
    // create app info
    var appInfo: c.VkApplicationInfo = undefined;
    appInfo.sType = stype.VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = "Hello Triangle";
    appInfo.applicationVersion = c.VK_MAKE_VERSION(1, 0, 0);
    appInfo.pEngineName = "No Engine";
    appInfo.engineVersion = c.VK_MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = c.VK_API_VERSION_1_0;

    // get extensions we need
    var extensions = try window.getExt(allocator);
    defer allocator.free(extensions);

    // create creation info
    var createInfo: c.VkInstanceCreateInfo = .{
        .sType = stype.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .enabledExtensionCount = @intCast(u32, extensions.len),
        .ppEnabledExtensionNames = extensions.ptr,
        .enabledLayerCount = 0, // change this when we add some validation
        .ppEnabledLayerNames = null, // change this when we add some validation
        .pNext = null,
        .flags = 0,
    };

    try vksucess(c.vkCreateInstance(&createInfo, null, &instance));
}
