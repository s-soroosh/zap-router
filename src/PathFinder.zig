const std = @import("std");
const zap = @import("zap");
const Trie = @import("Trie.zig").Trie;

const StringHashMap = std.StringHashMap;

pub const Path = struct {
    params: StringHashMap([]const u8),
    handler: *zap.HttpRequestFn,
};

pub fn find(trie: Trie(zap.HttpRequestFn), path: []const u8) !Path {
    if (path.len == 0) return error.InvalidPath;
    const path_parts = std.mem.splitAny(u8, path, "/");
    var current_node = trie._root;
    var params = StringHashMap([]const u8);
    while (path_parts.next()) |path_part| {
        if (current_node.staticChildren.getPtr(path_part)) |node| {
            current_node = node;
        } else {
            if (current_node.dynamicChildren.count() != 0) {
                const key = current_node.dynamicChildren.keyIterator().next().?;
                params.put(key, path_part);
                current_node = current_node.dynamicChildren.get(key).?;
            } else {
                return error.RouteNotFound;
            }
        }
    }

    if (current_node.isAnswer) {
        return .{
            .params = params,
            .handler = current_node.data,
        };
    }
}

fn _handle(req: zap.Request) !void {
    _ = req;
}

test "basic" {
    var trie = try Trie(zap.HttpRequestFn).init(std.heap.page_allocator);
    try trie.addPath("/users/register", _handle);
    try std.testing.expect(1 == 1);
}
