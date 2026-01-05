const std = @import("std");
const zap = @import("zap");
const Trie = @import("Trie.zig").Trie;
const Self = @This();
const find = @import("PathFinder.zig").find;

const Allocator = std.mem.Allocator;
routes: std.StringHashMap(zap.HttpRequestFn),
trie: Trie(zap.HttpRequestFn),
allocator: Allocator,

pub const Method = enum { GET, POST, DELETE, HEAD, PUT, PATCH, OPTION };
var instance: *Self = undefined;

pub fn init(allocator: Allocator) !Self {
    const routes = std.StringHashMap(zap.HttpRequestFn).init(allocator);
    const t = try Trie(zap.HttpRequestFn).init(allocator);
    return .{ .routes = routes, .trie = t, .allocator = allocator };
}

pub fn route(self: *Self, method: Method, path: []const u8, handler: zap.HttpRequestFn) !void {
    _ = method;
    try self.trie.addPath(path, handler);
    try self.routes.put(path, handler);
}
pub fn dispatch(self: *Self, request: zap.Request) !void {
    std.debug.print("you are here: {s}\n", .{request.path.?});

    if (request.path) |path| {
        const p = try find(self.allocator, self.trie, path);
        return p.handler(request);
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
