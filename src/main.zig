const std = @import("std");
const zcloc = @import("root.zig");
const clap = @import("clap");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-x, --exclude <str>... Exclude directories from search
        \\<str>...
        \\
    );
    // Parse and display help message on error.
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = null,
        .allocator = alloc,
    }) catch {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});

    if (res.positionals.len != 1)
        return clap.usage(std.io.getStdErr().writer(), clap.Help, &params);

    const cwd_path = try std.fs.cwd().realpathAlloc(alloc, res.positionals[0]);
    defer alloc.free(cwd_path);

    var proc = try zcloc.Processor.init(cwd_path, res.args.exclude, alloc);
    defer proc.deinit();

    try proc.get_files();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try proc.print_stats(stdout);

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
