const std = @import("std");
const Io = std.Io;

const zap_router = @import("zap_router");
const zap = @import("zap");
const ZapRouter = zap_router.ZapRouter;

pub fn main() !void {
    // Prints to stderr, unbuffered, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

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
