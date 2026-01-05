const std = @import("std");

const StringHashMap = std.StringHashMap;
const startsWith = std.mem.startsWith;
const endsWith = std.mem.endsWith;
const split = std.mem.splitAny;

pub fn Node(T: type) type {
    return struct {
        const Self = @This();
        isAnswer: bool,
        staticChildren: StringHashMap(*Node(T)),
        dynamicChildren: StringHashMap(*Node(T)),
        dynamic: bool,
        data: ?T,

        pub fn init(allocator: std.mem.Allocator, isAnswer: bool, dynamic: bool, data: ?T) !Self {
            return .{
                .staticChildren = StringHashMap(*Self).init(allocator),
                .dynamicChildren = StringHashMap(*Self).init(allocator),
                .isAnswer = isAnswer,
                .dynamic = dynamic,
                .data = data,
            };
        }

        pub fn deinit(self: *Self) void {
            self.staticChildren.clearAndFree();
            self.dynamicChildren.clearAndFree();
        }
    };
}

pub fn Trie(T: type) type {
    return struct {
        const Self = @This();
        _root: *Node(T),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) !Self {
            return .{ .allocator = allocator, ._root = try _createNode(allocator, T, null) };
        }

        pub fn deinit(self: *Self) void {
            self._root.deinit();
        }

        pub fn addPath(self: *Self, path: []const u8, data: T) !void {
            var parts = split(comptime u8, path, "/");
            var current_node = self._root;
            while (parts.next()) |part| {
                if (part.len == 0) continue;
                if (try _isDynamicNode(part)) {
                    const new_node = try _createNode(self.allocator, T, data);
                    try current_node.dynamicChildren.put(part[1 .. part.len - 1], new_node);
                    // TODO: add a test
                    current_node = new_node;
                } else {
                    if (current_node.staticChildren.get(part)) |node| {
                        current_node = node;
                    } else {
                        const new_node = try _createNode(self.allocator, T, data);
                        try current_node.staticChildren.put(part, new_node);
                        current_node = new_node;
                    }
                }
            }
            current_node.isAnswer = true;
        }
    };
}

fn _createNode(allocator: std.mem.Allocator, T: type, data: ?T) !*Node(T) {
    const node = try allocator.create(Node(T));
    node.* = try Node(T).init(allocator, false, false, data);
    return node;
}

fn _isDynamicNode(part: []const u8) !bool {
    if (startsWith(u8, part, "{")) {
        if (!endsWith(u8, part, "}")) {
            return error.InvalidPathParameter;
        }
        return true;
    }
    return false;
}

// TODO: fix memory leaks
test "add path" {
    var trie = try Trie(u8).init(std.heap.c_allocator);
    defer trie.deinit();
    try trie.addPath("/users/{userId}", 1);
    try std.testing.expect(trie._root.staticChildren.contains("users"));
}

test "add path with multiple static sections" {
    var trie = try Trie(u8).init(std.heap.c_allocator);
    defer trie.deinit();
    try trie.addPath("/part1/part2/part3", 2);
    try std.testing.expect(trie._root.staticChildren.get("part1").?.staticChildren.get("part2").?.staticChildren.contains("part3"));
}

test "add path with prefix overlap" {
    var trie = try Trie(u8).init(std.heap.c_allocator);
    defer trie.deinit();
    try trie.addPath("/part1/part2/part3", 3);
    try trie.addPath("/part1/part4/part5", 4);
    try std.testing.expectEqual(2, trie._root.staticChildren.get("part1").?.staticChildren.count());
}

test "path variables" {
    var trie = try Trie(u8).init(std.heap.c_allocator);
    defer trie.deinit();
    try trie.addPath("/users/{userId}", 1);
    try std.testing.expectEqual(1, trie._root.staticChildren.get("users").?.dynamicChildren.count());
    try std.testing.expect(trie._root.staticChildren.get("users").?.dynamicChildren.get("userId") != null);
}
