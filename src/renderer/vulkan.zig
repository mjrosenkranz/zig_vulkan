const std = @import("std");
const c = @import("vulkan");
const win = @import("window.zig");
const stype = c.enum_VkStructureType;
const Allocator = std.mem.Allocator;

const Self = @This();
const s = c.enum_VkStructureType;

var validationEnabled: bool = true;

instance: c.VkInstance = undefined,


pub fn init(allocator: *Allocator) !Self {
    return Self{
        .instance = try createInstance(allocator),
    };
}

pub fn deinit(self: *Self) void {
    c.vkDestroyInstance(self.instance, null);
}

fn vksuccess(result: c.enum_VkResult) !void {
    if (result != c.enum_VkResult.VK_SUCCESS) {
        return error.Unexpected;
    }
}
//fn(.vulkan.enum_VkDebugUtilsMessageSeverityFlagBitsEXT,
//    u32,
//    [*c]const .vulkan.struct_VkDebugUtilsMessengerCallbackDataEXT,
//    ?*c_void)
fn debugCallback(
    severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    msgType: c.VkDebugUtilsMessageTypeFlagsEXT,
    data: [*c]const c.VkDebugUtilsMessengerCallbackDataEXT,
    userdata: ?*c_void,
)  callconv(.C) u32 {
    std.log.warn("{s}", .{data.*.pMessage});
    return c.VK_FALSE;
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
    try vksuccess(c.vkEnumerateInstanceExtensionProperties(null, &extCount, null));
    std.log.info("Number of available extentions: {}", .{extCount});

    var extProperties = try allocator.alloc(c.VkExtensionProperties, extCount);
    defer allocator.free(extProperties);
    try vksuccess(c.vkEnumerateInstanceExtensionProperties(null, &extCount, extProperties.ptr));

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
        // TODO: enable only extensions we are using
        .ppEnabledExtensionNames = extensions.items.ptr,
        .enabledLayerCount = 0, // change this when we add some validation
        .ppEnabledLayerNames = null, // change this when we add some validation
        .pNext = null,
        .flags = 0,
    };

    // add validation if needbe
    if (validationEnabled and try hasValidationLayers(allocator)) {
        createInfo.enabledLayerCount = 1;
        const layernames: [*]const u8 = "VK_LAYER_KHRONOS_validation";
        createInfo.ppEnabledLayerNames = &layernames;

        // create the debug thingy
        var debug: c.VkDebugUtilsMessengerCreateInfoEXT = .{
            .sType = s.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT
                | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT
                |c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT
                | c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT
                |c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = debugCallback,
            .pUserData = null,
            .flags = 0,
            .pNext = null,
        };


        // set this to be created by the instance
        createInfo.pNext =@ptrCast(*c.VkDebugUtilsMessengerCreateInfoEXT, &debug) ;
    }

    var inst: c.VkInstance = undefined;

    try vksuccess(c.vkCreateInstance(&createInfo, null, &inst));
    std.debug.print("Vk Instance created\n", .{});

    return inst;
}

fn hasValidationLayers(allocator: *Allocator) !bool {
    var layerCount: u32 = 0;
    try vksuccess(c.vkEnumerateInstanceLayerProperties(&layerCount, null));

    var layers = try allocator.alloc(c.VkLayerProperties, layerCount);
    defer allocator.free(layers);

    try vksuccess(c.vkEnumerateInstanceLayerProperties(&layerCount, layers.ptr));

    var i: usize = 0;
    // TODO: string compare these bad boys
//    while (i < layerCount) : (i += 1) {
//        // compare
//        if ("VK_LAYER_KHRONOS_validation" == layers[i].layerName) {
//            return true;
//        }
//    }
//    return false;
    return true;
}
