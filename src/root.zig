const std = @import("std");
const zap = @import("zap");
pub const PathVariables = std.StringHashMap([]const u8);
pub const HttpRequestFn = *const fn (zap.Request, std.StringHashMap([]const u8)) anyerror!void;
pub const ZapRouter = @import("ZapRouter.zig");

// TODO: add tests
