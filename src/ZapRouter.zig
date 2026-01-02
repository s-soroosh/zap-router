const std = @import("std");
const zap = @import("zap");
const Self = @This();

const Allocator = std.mem.Allocator;
routes: std.StringHashMap(zap.HttpRequestFn),

pub const Method = enum { GET, POST, DELETE, HEAD, PUT, PATCH, OPTION };
var instance: *Self = undefined;

pub fn init(allocator: Allocator) Self {
    const routes = std.StringHashMap(zap.HttpRequestFn).init(allocator);
    return .{ .routes = routes };
}

pub fn route(self: *Self, method: Method, path: []const u8, handler: zap.HttpRequestFn) !void {
    _ = method;
    try self.routes.put(path, handler);
}
pub fn dispatch(self: *Self, request: zap.Request) !void {
    std.debug.print("you are here!!!", .{});
    if (request.path) |path| {
        if (self.routes.get(path)) |handler| return handler(request);
    }
    return request.sendBody("oops!");
}

pub fn onRequest(self: *Self) zap.HttpRequestFn {
    instance = self;
    const obj = struct {
        pub fn apply(req: zap.Request) !void {
            return dispatch(instance, req);
        }
    };
    return obj.apply;
}


pub fn deinit(self: *Self) void {
    self.routes.deinit();
}
