const std = @import("std");
const c = @import("vulkan");
const win = @import("window.zig");
const stype = c.enum_VkStructureType;
const Allocator = std.mem.Allocator;

const Self = @This();
const s = c.enum_VkStructureType;

instance: c.VkInstance = undefined,


pub fn init(allocator: *Allocator) !Self {
    return Self{
        .instance = try createInstance(allocator),
    };
}

pub fn deinit(self: *Self) void {
    c.vkDestroyInstance(self.instance, null);
}

fn vksucess(result: c.enum_VkResult) !void {
    if (result != c.enum_VkResult.VK_SUCCESS) {
        return error.Unexpected;
    }
}

fn createInstance(allocator: *Allocator) !c.VkInstance {
    // create app info
    var appInfo: c.VkApplicationInfo = .{
        .sType = s.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .pApplicationName = "TestApp",
        .pEngineName = "octal-zig",
        .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = c.VK_API_VERSION_1_2,
        .pNext = null,
    };

    // get extensions we need
    var extCount: u32 = 0;
    try vksucess(c.vkEnumerateInstanceExtensionProperties(null, &extCount, null));
    std.log.info("Number of extentions: {}", .{extCount});

    var extProperties = try allocator.alloc(c.VkExtensionProperties, extCount);
    defer allocator.free(extProperties);
    try vksucess(c.vkEnumerateInstanceExtensionProperties(null, &extCount, extProperties.ptr));

    var extensions = std.ArrayList([*]const u8).init(allocator);
    defer extensions.deinit();

    {
        var i: usize = 0;
        while (i < extCount) : (i += 1) {
            try extensions.append(&extProperties[i].extensionName);
            std.log.info("ext: {s}", .{extensions.items[i][0..256]});
        }
    }


    // create creation info
    var createInfo: c.VkInstanceCreateInfo = .{
        .sType = s.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .enabledExtensionCount = extCount,
        .ppEnabledExtensionNames = extensions.items.ptr,
        .enabledLayerCount = 0, // change this when we add some validation
        .ppEnabledLayerNames = null, // change this when we add some validation
        .pNext = null,
        .flags = 0,
    };

    var inst: c.VkInstance = undefined;

    try vksucess(c.vkCreateInstance(&createInfo, null, &inst));
    std.debug.print("Vk Instance created\n", .{});

    return inst;
    //return error.Unexpected;
}
