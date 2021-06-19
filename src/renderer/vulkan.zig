const std = @import("std");
const c = @import("../c.zig");
const win = @import("../window.zig");
const stype = c.enum_VkStructureType;
const Allocator = std.mem.Allocator;

const Self = @This();
const s = c.enum_VkStructureType;

// TODO: add more to this and make the vkSuccess function use it
const vkError = error {
    NoDevicesFound,
    NoSuitableDevice,
    RequiredExtNotFound,
    CannotCreateSwapchain,
    CannotCreateImageView,

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
var device: c.VkDevice = undefined;
var queue_indices: QueueFamilyIndices = undefined;

var graphics_queue: c.VkQueue = undefined;
var present_queue: c.VkQueue = undefined;

var swapchain: c.VkSwapchainKHR = undefined;
var swapchain_format: c.VkSurfaceFormatKHR = undefined;
var swapchain_extent: c.VkExtent2D = undefined;
var swapchain_images: []c.VkImage = undefined;

var image_views: []c.VkImageView = undefined;

var render_pass: c.VkRenderPass = undefined;

const required_ext = [_][]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME
};

pub fn init(allocator: *Allocator, window: *win.Window) !void {
    instance = try createInstance(allocator);
    surface = try window.getVkSurface(&instance);
    pdev = try pickPhysicalDevice(allocator);
    device = try createLogicalDevice(allocator);

    // setup queues
    c.vkGetDeviceQueue(device, queue_indices.graphics.?, 0, &graphics_queue);
    c.vkGetDeviceQueue(device, queue_indices.present.?, 0, &present_queue);

    swapchain = try createSwapchain(allocator);

    // get images
    var image_count: u32 = 0;
    try vkSuccess(c.vkGetSwapchainImagesKHR(device, swapchain, &image_count, null));
    swapchain_images = try allocator.alloc(c.VkImage, image_count);
    defer allocator.free(swapchain_images);
    try vkSuccess(c.vkGetSwapchainImagesKHR(device, swapchain, &image_count, swapchain_images.ptr));

    image_views = try createImageViews(allocator, swapchain_images.len);

    render_pass = try createRenderPass();
}

//pub fn deinit(self: *Self) void {
pub fn deinit() void {
    c.vkDestroyRenderPass(device, render_pass, null);
    for (image_views) |img| {
        c.vkDestroyImageView(device, img, null);
    }
    c.vkDestroySwapchainKHR(device, swapchain, null);
    c.vkDestroySurfaceKHR(instance, surface, null);
    c.vkDestroyDevice(device, null);
    c.vkDestroyInstance(instance, null);
}

fn vkSuccess(result: c.enum_VkResult) !void {
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
    try vkSuccess(c.vkEnumerateInstanceExtensionProperties(null, &extCount, null));
    std.log.info("Number of available extentions: {}", .{extCount});

    var extProperties = try allocator.alloc(c.VkExtensionProperties, extCount);
    defer allocator.free(extProperties);
    try vkSuccess(c.vkEnumerateInstanceExtensionProperties(null, &extCount, extProperties.ptr));

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

    try vkSuccess(c.vkCreateInstance(&createInfo, null, &inst));
    std.debug.print("Vk Instance created\n", .{});

    return inst;
}

fn hasValidationLayers(allocator: *Allocator) !bool {
    var layerCount: u32 = 0;
    try vkSuccess(c.vkEnumerateInstanceLayerProperties(&layerCount, null));

    var layers = try allocator.alloc(c.VkLayerProperties, layerCount);
    defer allocator.free(layers);

    try vkSuccess(c.vkEnumerateInstanceLayerProperties(&layerCount, layers.ptr));

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
    try vkSuccess(c.vkEnumeratePhysicalDevices(instance, &devCount, null));

    if (devCount == 0) {
        return vkError.NoDevicesFound;
    }

    std.log.info("{} physical devices found!", .{devCount});

    // get them devices
    var devices = try allocator.alloc(c.VkPhysicalDevice, devCount);
    defer allocator.free(devices);
    try vkSuccess(c.vkEnumeratePhysicalDevices(instance, &devCount, devices.ptr));

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
        try vkSuccess(c.vkGetPhysicalDeviceSurfaceSupportKHR(dev, i, surface, &has_present));
        if (has_present == 1) {
            ret.present = i;
        }
    }

    return ret;
}

fn hadRequiredExt(dev: c.VkPhysicalDevice, allocator: *Allocator) !bool {
    var ext_count: u32 = 0;
    try vkSuccess(c.vkEnumerateDeviceExtensionProperties(dev, null, &ext_count, null));
    var avail_ext = try allocator.alloc(c.VkExtensionProperties, ext_count);
    defer allocator.free(avail_ext);
    try vkSuccess(c.vkEnumerateDeviceExtensionProperties(dev, null, &ext_count, avail_ext.ptr));

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

fn createLogicalDevice(allocator: *Allocator) !c.VkDevice {
    var dev: c.VkDevice = undefined;
    var idx = std.ArrayList(u32).init(allocator);
    defer idx.deinit();

    var queues = std.ArrayList(c.VkDeviceQueueCreateInfo).init(allocator);
    defer queues.deinit();

    // TODO: figure out how many queues we need programatically
    // for now we know we only need one
    try idx.append(queue_indices.graphics.?);
    if (queue_indices.present.? != queue_indices.graphics.?) {
        try idx.append(queue_indices.present.?);
    }

    var priority: f32 = 1.0;

    for (idx.items) |i| {
        var create: c.VkDeviceQueueCreateInfo = .{
            .sType = s.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            // set graphics index
            .queueFamilyIndex = i,
            .queueCount = 1,
            // make this the highest priority
            .pQueuePriorities = &priority,
            .flags = 0,
            .pNext = null,
        };

        try queues.append(create);
    }

    var dev_create: c.VkDeviceCreateInfo = .{
        .sType = s.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = @intCast(u32, queues.items.len),
        .pQueueCreateInfos = queues.items.ptr,
        .pEnabledFeatures = null,
        // no extensions for now
        .enabledExtensionCount = @intCast(u32, required_ext.len),
        .ppEnabledExtensionNames = @ptrCast([*c]const [*c]const u8, &required_ext),
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .flags = 0,
        .pNext = null,
    };

    const layerNames = [_][]const u8{
        "VK_LAYER_KHRONOS_validation",
    };

    // add validation if we need to
    if (validationEnabled) {
        dev_create.enabledLayerCount = 1;
        dev_create.ppEnabledLayerNames = @ptrCast([*c]const [*c]const u8, &layerNames);
    }

    try vkSuccess(c.vkCreateDevice(pdev, &dev_create, null, &dev));
    return dev;
}

fn createSwapchain(allocator: *Allocator) !c.VkSwapchainKHR {
    // get swapchain support details
    var capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
    try vkSuccess(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(pdev, surface, &capabilities));

    // get formats
    var format_count: u32 = 0;
    try vkSuccess(c.vkGetPhysicalDeviceSurfaceFormatsKHR(pdev, surface, &format_count, null));
    var formats = try allocator.alloc(c.VkSurfaceFormatKHR, format_count);
    defer allocator.free(formats);
    try vkSuccess(c.vkGetPhysicalDeviceSurfaceFormatsKHR(pdev, surface, &format_count, formats.ptr));

    // get modes
    var mode_count: u32 = 0;
    try vkSuccess(c.vkGetPhysicalDeviceSurfacePresentModesKHR(pdev, surface, &mode_count, null));
    var modes = try allocator.alloc(c.VkPresentModeKHR, mode_count);
    defer allocator.free(modes);
    try vkSuccess(c.vkGetPhysicalDeviceSurfacePresentModesKHR(pdev, surface, &mode_count, modes.ptr));

    // verify swapchain details
    std.log.info("surface modes: {}, formats: {}", .{modes.len, formats.len});
    if (modes.len == 0 or formats.len == 0) return vkError.CannotCreateSwapchain;

    // chose best format, mode, and extent
    const format = bestFormat(formats);
    const mode = bestMode(modes);
    const extent = bestExtent(capabilities);

    // use at least one more than the minimum image count
    var image_count: u32 = capabilities.minImageCount + 1;
    // if that is more than the max image count then set it to the max
    if (capabilities.maxImageCount > 0 and image_count > capabilities.maxImageCount) {
        image_count = capabilities.maxImageCount;
    }

    var create: c.VkSwapchainCreateInfoKHR = .{
        .sType = s.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = surface,
        .minImageCount = image_count,
        .imageFormat = format.format,
        .imageColorSpace = format.colorSpace,
        .imageExtent = extent,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .imageSharingMode = c.VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
        .preTransform = capabilities.currentTransform,
        .compositeAlpha = c.VkCompositeAlphaFlagBitsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = mode,
        .clipped = c.VK_TRUE,
        .oldSwapchain = null,
        .pNext = null,
        .flags = 0,
    };

    // set member variables too
    swapchain_format = format;
    swapchain_extent = extent;

    // change sharing mode if the queues are different because we don't need to share queues
    if (queue_indices.graphics.? != queue_indices.present.?) {
        create.imageSharingMode = c.VkSharingMode.VK_SHARING_MODE_CONCURRENT;
        create.queueFamilyIndexCount = 2;
        create.pQueueFamilyIndices = &[_]u32{
            queue_indices.graphics.?,
            queue_indices.present.?
        };
    }

    var sc: c.VkSwapchainKHR = undefined;

    try vkSuccess(c.vkCreateSwapchainKHR(device, &create, null, &sc));

    return sc;
}

fn bestFormat(formats: []c.VkSurfaceFormatKHR) c.VkSurfaceFormatKHR {
    for (formats) |f| {
        if (f.format == c.VkFormat.VK_FORMAT_B8G8R8A8_SRGB and f.colorSpace == c.VkColorSpaceKHR.VK_COLORSPACE_SRGB_NONLINEAR_KHR)
            return f;
    }

    std.log.warn("Could not find preferred format", .{});
    // default to first if there are no modes we want
    return formats[0];
}

fn bestMode(modes: []c.VkPresentModeKHR) c.VkPresentModeKHR {
    for (modes) |m| {
        std.log.info("pmode: {}", .{m});
        if (m == c.VkPresentModeKHR.VK_PRESENT_MODE_MAILBOX_KHR) {
            return m;
        }
    }

    std.log.warn("Could not find preferred present mode", .{});
    // if we don't have mailbox then this is guranteed to exist
    return c.VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR;
}

fn bestExtent(capabilities: c.VkSurfaceCapabilitiesKHR) c.VkExtent2D {
    std.log.info("extent: {}x{}", .{capabilities.currentExtent.width, capabilities.currentExtent.height});
    return capabilities.currentExtent;
}

fn createImageViews(allocator: *Allocator, num: usize) ![]c.VkImageView {
    var ivs = try allocator.alloc(c.VkImageView, num);

    var i:u32 = 0;
    while (i < ivs.len) : (i+=1) {
        var create: c.VkImageViewCreateInfo = .{
            .sType = s.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = swapchain_images[i],
            .viewType = c.VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
            .format = swapchain_format.format,

            //// leave colors normal order
            .components = c.VkComponentMapping{
                .r = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
            },

            //// define purpose and region
            //// here we just want to copy color
            .subresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                //// we only need one level since our sc has only one
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
            .pNext = null,
            .flags = 0,
        };

        if (c.vkCreateImageView(device, &create, null, &ivs[i]) != c.VkResult.VK_SUCCESS) {
            return vkError.CannotCreateImageView;
        }
    }

    return ivs;
}

fn createRenderPass() !c.VkRenderPass {
    // describe our color only attachment
    var color_attachment: c.VkAttachmentDescription = .{
        .format = swapchain_format.format,
        // not doing multisampling
        .samples = c.VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, 
        // clear on load
        .loadOp = c.VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
        // don't care about the stencil for now
        .stencilLoadOp = c.VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        // initial is undefined but we want to present to swapchain at the end
        .initialLayout = c.VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
        .flags = 0,
    };

    // reference to the above attachment
    var color_attachment_ref: c.VkAttachmentReference = .{
        .attachment = 0,
        .layout = c.VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };

    // create a color subpass
    var  subpass: c.VkSubpassDescription = .{
        .pipelineBindPoint = c.VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = &color_attachment_ref,

        .inputAttachmentCount = 0,
        .pInputAttachments = null,
        .pResolveAttachments = null,
        .pDepthStencilAttachment = null,
        .preserveAttachmentCount = 0,
        .pPreserveAttachments = null,
        .flags = 0,
    };

    var dependency: c.VkSubpassDependency = .{
        .dependencyFlags = 0,
        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .srcAccessMask = 0,
        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
    };

    var render_pass_info: c.VkRenderPassCreateInfo = .{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1,
        .pAttachments = &color_attachment,
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 1,
        .pDependencies = &dependency,
        .pNext = null,
        .flags = 0,
    };


    var rp: c.VkRenderPass = undefined;
    try vkSuccess(c.vkCreateRenderPass(device, &render_pass_info, null, &rp));
    return rp;
}
