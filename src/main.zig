const std = @import("std");
const zap = @import("zap");
const zap_router = @import("zap_router");
const ZapRouter = zap_router.ZapRouter;
const PathVariables = std.StringHashMap([]const u8);

fn sayHello(req: zap.Request, _: PathVariables) !void {
    try req.sendBody("Hello");
}

fn sayUserId(req: zap.Request, pv: PathVariables) !void {
    var buf: [32]u8 = undefined;
    const count = try std.fmt.bufPrint(&buf, "userId: {s}", .{pv.get("userId") orelse "0"});
    try req.sendBody(count);
}

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit(); // This checks for leaks.
    const gpa = debug_allocator.allocator();

    var router = try ZapRouter.init(gpa);
    defer router.deinit();

    try router.route(.GET, "/hello", sayHello);
    try router.route(.GET, "/users/{userId}", sayUserId);

    var zap_server1 = zap.HttpListener.init(.{ .port = 3000, .on_request = router.onRequest(), .log = false });

    try zap_server1.listen();

    zap.start(.{ .threads = 8, .workers = 1 });
}
