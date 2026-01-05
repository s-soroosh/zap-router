const std = @import("std");
const Io = std.Io;

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
    // In order to allocate memory we must construct an `Allocator` instance.
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit(); // This checks for leaks.
    const gpa = debug_allocator.allocator();

    // In order to do I/O operations we must construct an `Io` instance.
    var threaded: std.Io.Threaded = .init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try stdout_writer.flush();

    var router = try ZapRouter.init(gpa);
    defer router.deinit();

    try router.route(.GET, "/hello", sayHello);

    var zap_server1 = zap.HttpListener.init(.{ .port = 3000, .on_request = router.onRequest(), .log = false });

    try zap_server1.listen();

    zap.start(.{ .threads = 8, .workers = 1 });
}
