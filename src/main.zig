const std = @import("std");
const zap = @import("zap");
const zap_router = @import("zap_router");
const ZapRouter = zap_router.ZapRouter;

fn dispatchRequest(req: zap.Request) !void {
    try req.sendJson("{\"message\":\"Hello dude\"}");
}

fn sayHello(req: zap.Request) !void {
    try req.sendBody("Hello");
}

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit(); // This checks for leaks.
    const gpa = debug_allocator.allocator();

    var router = try ZapRouter.init(gpa);
    defer router.deinit();

    try router.route(.GET, "/hello", sayHello);

    var zap_server1 = zap.HttpListener.init(.{ .port = 3000, .on_request = router.onRequest(), .log = false });

    try zap_server1.listen();

    zap.start(.{ .threads = 8, .workers = 1 });
}
