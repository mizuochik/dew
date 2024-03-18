const builtin = @import("builtin");

pub usingnamespace @cImport({
    @cInclude(switch (builtin.os.tag) {
        .linux => "linux/ioctl.h",
        else => "sys/ioctl.h",
    });
    @cInclude("yaml.h");
});
