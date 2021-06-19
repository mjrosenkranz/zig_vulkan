const std = @import("std");
const c = @import("../c.zig");
const win = @import("../window.zig");
const stype = c.enum_VkStructureType;
const Allocator = std.mem.Allocator;

const Self = @This();
const s = c.enum_VkStructureType;

// TODO: add more to this and make the vksuccess function use it
const vkError = error {
    NoDevicesFound,
    NoSuitableDevice,
    RequiredExtNotFound,
};

const QueueFamilyIndices = struct {
    graphics: ?u32 = null,
    present: ?u32 = null,
};

//TODO: maybe make this implicit to the build level
/// Should we include the validation layers
pub var validationEnabled: bool = true;

var instance: c.VkInstance = undefined;
var surface: c.VkSurfaceKHR = undefined;
var pdev: c.VkPhysicalDevice = undefined;
var queue_indices: QueueFamilyIndices = undefined;

const required_ext = [_][]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME
};

pub fn init(allocator: *Allocator, window: *win.Window) !void {
    instance = try createInstance(allocator);
    surface = try window.getVkSurface(&instance);
    pdev = try pickPhysicalDevice(allocator);
}

//pub fn deinit(self: *Self) void {
pub fn deinit() void {
    c.vkDestroySurfaceKHR(instance, surface, null);
    c.vkDestroyInstance(instance, null);
}

fn vksuccess(result: c.enum_VkResult) !void {
    if (result != c.enum_VkResult.VK_SUCCESS) {
        return error.Unexpected;
    }
}

fn debugCallback(
    severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    msgType: c.VkDebugUtilsMessageTypeFlagsEXT,
    data: [*c]const c.VkDebugUtilsMessengerCallbackDataEXT,
    userdata: ?*c_void,
)  callconv(.C) u32 {
    // TODO: use different log levels
    std.log.debug("{s}", .{data.*.pMessage});
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

    var i: usize = 0;
    while (i < extCount) : (i += 1) {
        try extensions.append(&extProperties[i].extensionName);
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

fn pickPhysicalDevice(allocator: *Allocator) !c.VkPhysicalDevice {

    var dev: c.VkPhysicalDevice = undefined;

    var devCount: u32 = 0;
    try vksuccess(c.vkEnumeratePhysicalDevices(instance, &devCount, null));

    if (devCount == 0) {
        return vkError.NoDevicesFound;
    }

    std.log.info("{} physical devices found!", .{devCount});

    // get them devices
    var devices = try allocator.alloc(c.VkPhysicalDevice, devCount);
    defer allocator.free(devices);
    try vksuccess(c.vkEnumeratePhysicalDevices(instance, &devCount, devices.ptr));

    for (devices) |d| {
        dev = d;
        // get properties of the device
        var props: c.VkPhysicalDeviceProperties = undefined;
        var features: c.VkPhysicalDeviceFeatures = undefined;

        c.vkGetPhysicalDeviceProperties(dev, &props);
        c.vkGetPhysicalDeviceFeatures(dev, &features);

        queue_indices = try findQueueFamliyIndices(d, allocator);

        std.log.info("device {s}, type {}", .{props.deviceName, props.deviceType});

        // TODO: make config of required features
        // for now hardcoded

        // checks if we have graphics and present features
        if (
            features.geometryShader == 1
            and queue_indices.graphics != null
            and queue_indices.present != null
        ) {
            // if so then we need to check if we have all the required extensions
            if (!try hadRequiredExt(dev, allocator)) {
                return vkError.RequiredExtNotFound;
            }

            return dev;
        }
    }
    return vkError.NoSuitableDevice;
}

fn findQueueFamliyIndices(dev: c.VkPhysicalDevice, allocator: *Allocator) !QueueFamilyIndices {
    var ret: QueueFamilyIndices = .{};
    // find queue families
    var queue_count: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(dev, &queue_count, null);

    var queue_families = try allocator.alloc(c.VkQueueFamilyProperties, queue_count);
    defer allocator.free(queue_families);

    c.vkGetPhysicalDeviceQueueFamilyProperties(dev, &queue_count, queue_families.ptr);


    var i: u32 = 0;
    while (i < queue_count) : (i += 1) {
        // has graphics support
        if ((queue_families[@intCast(usize,i)].queueFlags & c.VK_QUEUE_GRAPHICS_BIT) == 1) {
            ret.graphics = i;
        }
        // presentation support
        var has_present: u32 = 0;
        try vksuccess(c.vkGetPhysicalDeviceSurfaceSupportKHR(dev, i, surface, &has_present));
        if (has_present == 1) {
            ret.present = i;
        }
    }

    return ret;
}

fn hadRequiredExt(dev: c.VkPhysicalDevice, allocator: *Allocator) !bool {
    var ext_count: u32 = 0;
    try vksuccess(c.vkEnumerateDeviceExtensionProperties(dev, null, &ext_count, null));
    var avail_ext = try allocator.alloc(c.VkExtensionProperties, ext_count);
    defer allocator.free(avail_ext);
    try vksuccess(c.vkEnumerateDeviceExtensionProperties(dev, null, &ext_count, avail_ext.ptr));

    // check if we have this extension in required list
    for (required_ext) |re| {
        var found = false;
        for (avail_ext) |ext| {
            const name = std.mem.span(&ext.extensionName);
            // TODO: make this work better with edge cases
            if (std.mem.indexOfDiff(u8, re, name) == re.len) {
                found = true;
            }
        }

        if (!found) {
            std.log.err("Cound not find {s}", .{re});
            return false;
        }
    }

    return true;
}
