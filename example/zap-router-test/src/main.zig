const std = @import("std");
const Io = std.Io;

const zap_router = @import("zap_router");
const zap = @import("zap");
const ZapRouter = zap_router.ZapRouter;

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit(); // This checks for leaks.
    const gpa = debug_allocator.allocator();

    var threaded: std.Io.Threaded = .init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try stdout_writer.flush(); // Don't forget to flush!
    var router = ZapRouter.init(gpa);
    try router.route(.GET, "/test", testFunction);

    var listener = zap.HttpListener.init(.{ .port = 3002, .on_request = router.onRequest() });
    try listener.listen();

    zap.start(.{ .workers = 1, .threads = 2 });
}

fn testFunction(req: zap.Request) !void {
    try req.sendBody("test");
}
