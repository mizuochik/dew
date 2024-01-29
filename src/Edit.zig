const std = @import("std");

const TextRef = @import("TextRef.zig");
const Client = @import("Client.zig");

active_ref: ?*TextRef = null,
