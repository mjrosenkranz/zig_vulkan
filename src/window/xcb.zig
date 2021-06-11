const std = @import("std");
const c = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("X11/Xlib-xcb.h");
    @cInclude("X11/Xlib.h");
});
const Window = @import("../window.zig").Window;

const xcbError = error {
    Connection,
    FlushError
};

pub const xcbWindow = struct {
    window: Window = .{
        .flushFn = flush,
    },

    display: ?*c.Display = null,
    connection: *c.xcb_connection_t = undefined,
    screen: *c.xcb_screen_t = undefined,
    win: c.xcb_window_t = undefined,
    wm_proto: c.xcb_atom_t = undefined,
    wm_del: c.xcb_atom_t = undefined,

    const Self = @This();

    pub fn init(dims: Window.Geom) !Self {
        // open the display
        var display = c.XOpenDisplay(null).?;
        _ = c.XAutoRepeatOff(display);

        // get connection
        var connection = c.XGetXCBConnection(display).?;

        if (c.xcb_connection_has_error(connection) != 0) {
            return xcbError.Connection;
        }

        var itr: c.xcb_screen_iterator_t = c.xcb_setup_roots_iterator(c.xcb_get_setup(connection));
        // Use the last screen
        var screen = @ptrCast(*c.xcb_screen_t, itr.data);

        // Allocate an id for our window
        var window = c.xcb_generate_id(connection);

        // We are setting the background pixel color and the event mask
        const mask: u32  = c.XCB_CW_BACK_PIXEL | c.XCB_CW_EVENT_MASK;

        // background color and events to request
        const values = [_]u32 {screen.*.black_pixel, c.XCB_EVENT_MASK_BUTTON_PRESS | c.XCB_EVENT_MASK_BUTTON_RELEASE |
            c.XCB_EVENT_MASK_KEY_PRESS | c.XCB_EVENT_MASK_KEY_RELEASE |
                c.XCB_EVENT_MASK_EXPOSURE | c.XCB_EVENT_MASK_POINTER_MOTION |
                c.XCB_EVENT_MASK_STRUCTURE_NOTIFY};

        // Create the window
        const cookie: c.xcb_void_cookie_t = c.xcb_create_window(
            connection,
            c.XCB_COPY_FROM_PARENT,
            window,
            screen.*.root,
            0,
            0,
            200,
            200,
            0,
            c.XCB_WINDOW_CLASS_INPUT_OUTPUT,
            screen.*.root_visual,
            mask,
            values[0..]);

        // Notify us when the window manager wants to delete the window
        const datomname = "WM_DELETE_WINDOW";
        const wm_delete_reply = c.xcb_intern_atom_reply(
            connection,
            c.xcb_intern_atom(
                connection,
                0,
                datomname.len,
                datomname),
            null);
        const patomname = "WM_PROTOCOLS";
        const wm_protocols_reply = c.xcb_intern_atom_reply(
            connection,
            c.xcb_intern_atom(
                connection,
                0,
                patomname.len,
                patomname),
            null);

        //// store the atoms
        var wm_del = wm_delete_reply.*.atom;
        var wm_proto = wm_protocols_reply.*.atom;

        // ask the sever to actually set the atom
        _ = c.xcb_change_property(
            connection,
            c.XCB_PROP_MODE_REPLACE,
            window,
            wm_proto,
            4,
            32,
            1,
            &wm_del);

        // Map the window to the screen
        _ = c.xcb_map_window(connection, window);

        // flush pending actions to the server
        if (c.xcb_flush(connection) <= 0) {
            return xcbError.FlushError;
        }


        return Self{
            .display= display,
            .connection= connection,
            .screen= screen,
            .win= window,
            .wm_proto= wm_proto,
            .wm_del= wm_del,
        };
    }

    pub fn flush(window: *Window) bool {
        const self = @fieldParentPtr(Self, "window", window);

        // Poll for events until null is returned.
        while (true) {
            const event = c.xcb_poll_for_event(self.connection);
            if (event == 0) {
                break;
            }

            // Input events
            switch (event.*.response_type & ~@as(u32, 0x80)) {
                c.XCB_KEY_PRESS => {
                    const kev = @ptrCast(*c.xcb_key_press_event_t, event);
                },
                c.XCB_KEY_RELEASE => {
                    const kev = @ptrCast(*c.xcb_key_press_event_t, event);
                },
                c.XCB_CLIENT_MESSAGE => {
                    const cm = @ptrCast(*c.xcb_client_message_event_t, event);
                    // Window close
                    if (cm.*.data.data32[0] == self.wm_del) {
                        return false;
                    }
                },
                else => continue,
            }
            _ = c.xcb_flush(self.connection);
        }
        return true;
    }

    pub fn deinit(self: *Self) void {
        _ = c.XAutoRepeatOn(self.display);
        _ = c.xcb_destroy_window(self.connection, self.win);
    }
};
