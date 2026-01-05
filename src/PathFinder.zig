const std = @import("std");
const zap = @import("zap");
const Trie = @import("Trie.zig").Trie;

const StringHashMap = std.StringHashMap;
const logger = std.log.scoped(.path_finder);
pub const HttpRequestFn0 = *const fn (zap.Request, std.StringHashMap([]const u8)) anyerror!void;

pub const Path = struct {
    params: StringHashMap([]const u8),
    handler: HttpRequestFn0,

    //implement deinit
};

pub fn find(allocator: std.mem.Allocator, trie: Trie(HttpRequestFn0), path: []const u8) !Path {
    if (path.len == 0) return error.InvalidPath;
    var path_parts = std.mem.splitAny(u8, path, "/");
    var current_node = trie._root;
    var params = StringHashMap([]const u8).init(allocator);
    while (path_parts.next()) |path_part| {
        if (std.mem.eql(u8, path_part, "")) continue;
        if (current_node.staticChildren.get(path_part)) |node| {
            current_node = node;
        } else {

            if (current_node.dynamicChildren.count() != 0) {
                var dynamicNodeIterator = current_node.dynamicChildren.keyIterator();
                const key = dynamicNodeIterator.next().?.*;
                try params.put(key, path_part);
                current_node = current_node.dynamicChildren.get(key).?;
                logger.info("current node: {any} \n", .{current_node});
            } else {
                return error.RouteNotFound;
            }
        }
    }

    if (current_node.isAnswer) {
        return .{
            .params = params,
            .handler = current_node.data.?,
        };
    } else {
        return error.RouteNotFound;
    }
}

fn _handle(req: zap.Request) !void {
    _ = req;
}

// memory leak
test "basic success" {
    var trie = try Trie(zap.HttpRequestFn).init(std.heap.page_allocator);
    try trie.addPath("/users/register", _handle);
    const result = try find(std.testing.allocator, trie, "/users/register");

    try std.testing.expect(result.params.count() == 0);
}

test "basic failure" {
    var trie = try Trie(zap.HttpRequestFn).init(std.heap.page_allocator);
    try trie.addPath("/users/404", _handle);
    const find_result = find(std.testing.allocator, trie, "/users/register");

    try std.testing.expectError(error.RouteNotFound, find_result);
}
