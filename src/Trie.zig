const std = @import("std");

const Self = @This();
const StringHashMap = std.StringHashMap;
const startsWith = std.mem.startsWith;
const endsWith = std.mem.endsWith;
const split = std.mem.splitAny;

pub const Node = struct {
    isAnswer: bool,
    staticChildren: StringHashMap(*Node),
    dynamicChildren: StringHashMap(*Node),
    dynamic: bool,

    pub fn init(allocator: std.mem.Allocator, isAnswer: bool, dynamic: bool) !Node {
        return .{
            .staticChildren = StringHashMap(*Node).init(allocator),
            .dynamicChildren = StringHashMap(*Node).init(allocator),
            .isAnswer = isAnswer,
            .dynamic = dynamic,
        };
    }

    pub fn deinit(self: *Node) void {
        self.staticChildren.clearAndFree();
        self.dynamicChildren.clearAndFree();
    }
};

_root: *Node,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{ .allocator = allocator, ._root = try _createNode(allocator) };
}

pub fn deinit(self: *Self) void {
    self._root.deinit();
}

pub fn addPath(self: *Self, path: []const u8) !void {
    var parts = split(comptime u8, path, "/");
    var root = self._root;
    while (parts.next()) |part| {
        if (part.len == 0) continue;
        if (try _isDynamicNode(part)) {
            std.debug.print("This is a parameter\n", .{});
            const new_node = try _createNode(self.allocator);
            try root.dynamicChildren.put(part[1 .. part.len - 1], new_node);
        } else {
            if (root.staticChildren.get(part)) |node| {
                root = node;
            } else {
                const new_node = try _createNode(self.allocator);
                // std.debug.print("part:{s} new node: {any}\n", .{part, new_node});
                try root.staticChildren.put(part, new_node);
                root = new_node;
            }
        }
    }
}

fn _createNode(allocator: std.mem.Allocator) !*Node {
    const node = try allocator.create(Node);
    node.* = try Node.init(allocator, false, false);
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
    var trie = try Self.init(std.heap.c_allocator);
    defer trie.deinit();
    try trie.addPath("/users/{userId}");
    try std.testing.expect(trie._root.staticChildren.contains("users"));
}

test "add path with multiple static sections" {
    var trie = try Self.init(std.heap.c_allocator);
    defer trie.deinit();
    try trie.addPath("/part1/part2/part3");
    try std.testing.expect(trie._root.staticChildren.get("part1").?.staticChildren.get("part2").?.staticChildren.contains("part3"));
}

test "add path with prefix overlap" {
    var trie = try Self.init(std.heap.c_allocator);
    defer trie.deinit();
    try trie.addPath("/part1/part2/part3");
    try trie.addPath("/part1/part4/part5");
    try std.testing.expectEqual(2, trie._root.staticChildren.get("part1").?.staticChildren.count());
}

test "path variables" {
    var trie = try Self.init(std.heap.c_allocator);
    defer trie.deinit();
    try trie.addPath("/users/{userId}");
    try std.testing.expectEqual(1, trie._root.staticChildren.get("users").?.dynamicChildren.count());
    try std.testing.expect(trie._root.staticChildren.get("users").?.dynamicChildren.get("userId") != null);
}
