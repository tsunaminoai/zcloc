const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;
const Languages = @import("langs.zig");

const Error = error{
    UnableToRead,
    NoFileOrDir,
    DiffQuotedComments,
    DiffExceededTimeout,
    LineCountExceededTimeout,
};
const max_allocation_size = 100_000_000;

alloc: Allocator,
stats: std.StringHashMap(LanguageStat),
file_queue: std.ArrayList(ProcessFile),
base_path: []u8,
sums: LanguageStat,
files_total: u64 = 0,
files_skipped: u64 = 0,
files_processed: u64 = 0,
lock: std.Thread.Mutex = std.Thread.Mutex{},
excludes: std.StringHashMap(u1),

const LanguageStat = struct {
    lang_name: [*:0]const u8,
    files_total: u64 = 0,
    lines_total: u64 = 0,
    lines_blank: u64 = 0,
    lines_code: u64 = 0,
    lines_comment: u64 = 0,

    pub fn add(self: *LanguageStat, other: LanguageStat) void {
        inline for (@typeInfo(LanguageStat).Struct.fields) |field| {
            switch (field.type) {
                u64 => {
                    // std.debug.print("{s} self: {s} = {}\n", .{ self.lang_name, field.name, @field(self, field.name) });
                    // std.debug.print("{s} other: {s} = {}\n", .{ self.lang_name, field.name, @field(other, field.name) });
                    @field(self, field.name) += @field(other, field.name);
                },
                else => {},
            }
        }
    }

    pub fn print(self: *LanguageStat, writer: anytype) !void {
        try writer.print("{s}\t\t{}\t\t{}\t\t{}\t\t{}\n", .{
            self.lang_name,
            self.files_total,
            self.lines_blank,
            self.lines_comment,
            self.lines_code,
        });
    }
};
const Self = @This();

/// Initializes the file processor
pub fn init(base: []u8, excludes: []const []const u8, alloc: Allocator) !Self {
    var s = Self{
        .alloc = alloc,
        .stats = std.StringHashMap(LanguageStat).init(alloc),
        .file_queue = std.ArrayList(ProcessFile).init(alloc),
        .sums = LanguageStat{ .lang_name = "Sum" },
        .base_path = base,
        .excludes = std.StringHashMap(u1).init(alloc),
    };
    if (excludes.len > 0)
        try s.hashExcludes(excludes);
    return s;
}

/// Deinitializes the file processor
pub fn deinit(self: *Self) void {
    self.stats.deinit();

    for (self.file_queue.items) |*f|
        self.alloc.free(f.path);
    self.file_queue.deinit();
    self.excludes.deinit();
}

/// Adds a list of files to exclude from processing
fn hashExcludes(self: *Self, excludes: []const []const u8) !void {
    try self.excludes.ensureTotalCapacity(@intCast(excludes.len));
    for (excludes) |e| {
        std.log.info("Excluding {s}", .{e});
        self.excludes.putAssumeCapacity(e, 1);
    }
}

const ProcessFile = struct {
    path: []u8,
    lang: *const Languages.Language,
};

/// Gets the list of files to process
pub fn get_files(self: *Self) !void {
    std.debug.print("Getting list of files\n", .{});
    const dir = try std.fs.openDirAbsolute(self.base_path, .{
        .access_sub_paths = true,
        .iterate = true,
    });

    var walker = try dir.walk(self.alloc);
    defer walker.deinit();

    outer: while (try walker.next()) |entry| {
        {
            var iter = try std.fs.path.componentIterator(entry.path);
            while (iter.next()) |comp|
                if (self.excludes.contains(comp.name))
                    continue :outer;
        }
        switch (entry.kind) {
            .directory => {},
            .sym_link => {},
            .file => {
                const ext = std.fs.path.extension(entry.basename);
                if (ext.len < 1) continue;
                self.files_total += 1;

                if (Languages.ExtensionMap.get(ext[1..])) |lang| {
                    const fullpath = try std.mem.concat(self.alloc, u8, &[_][]const u8{ self.base_path, "/", entry.path });

                    const result = try self.stats.getOrPut(lang.display_name);
                    if (!result.found_existing) {
                        result.value_ptr.* = LanguageStat{
                            .lang_name = @ptrCast(lang.display_name.ptr),
                        };
                    }
                    try self.file_queue.append(.{ .path = fullpath, .lang = lang });
                } else {
                    self.files_skipped += 1;
                }
            },
            else => {},
        }
    }

    std.debug.print("Files to consider: {}\n", .{self.file_queue.items.len});
    try self.process();
}

/// Processes the list of files
pub fn process(self: *Self) !void {
    self.files_total = self.file_queue.items.len;
    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = self.alloc });
    defer pool.deinit();

    const cpus = try std.Thread.getCpuCount();
    const queue_size = self.file_queue.items.len / cpus;

    for (0..cpus) |ci| {
        const from = ci * queue_size;
        const to = @min((ci + 1) * queue_size, self.file_queue.items.len);
        // std.debug.print("spawning worker for {} to {}\n", .{ from, to });
        try pool.spawn(worker, .{
            self,
            self.file_queue.items[from..to],
        });
    }
    // while (pool.is_running and self.files_processed < self.file_queue.items.len) {
    //     if (self.files_processed % 100 == 0)
    //         std.debug.print("{}\r", .{self.files_processed});
    // }
}

/// The worker function that processes files per thread
fn worker(processor: *Self, queue: []ProcessFile) void {
    for (queue) |*file| {
        // std.log.debug("Processing: {s}\n", .{file.path});
        process_file(processor, file) catch |err| {
            std.debug.print("Error: {s}\n", .{@errorName(err)});
        };
    }
    // std.debug.print("Worker done\n", .{});
}

/// Prints the stats to the given writer
pub fn print_stats(self: *Self, writer: anytype) !void {
    var iter = self.stats.iterator();
    try writer.print("Ignored files: {}\n", .{self.files_skipped});
    try writer.writeAll("Language\tFiles\t\tBlank\t\tComment\t\tCode\n\n");
    while (iter.next()) |f| {
        try f.value_ptr.*.print(writer);
    }

    try writer.writeAll("\n");
    try self.sums.print(writer);
}

/// Processes a single file
fn process_file(self: *Self, file: *ProcessFile) !void {
    // std.debug.print("Processing {s} file: {s}\n", .{ file.lang.display_name, file.path });
    var handle = try std.fs.openFileAbsolute(file.path, .{ .mode = .read_only });
    defer handle.close();

    var local_stat = LanguageStat{
        .lang_name = @ptrCast(file.lang.display_name.ptr),
        .files_total = 1,
    };

    var reader = handle.reader();
    const buffer = try self.alloc.alloc(u8, 1024 * 1024);
    defer self.alloc.free(buffer);

    while (try reader.readUntilDelimiterOrEof(buffer, '\n')) |line| {
        local_stat.lines_total += 1;
        if (line.len == 0)
            local_stat.lines_blank += 1
        else if (std.mem.startsWith(u8, std.mem.trimLeft(u8, line, " \t"), file.lang.comment_prefix.?))
            local_stat.lines_comment += 1
        else
            local_stat.lines_code += 1;
    }

    self.lock.lock();
    const stat: *LanguageStat = self.stats.getPtr(file.lang.display_name) orelse unreachable;
    stat.*.add(local_stat);
    self.sums.add(local_stat);
    self.files_processed += 1;
    self.lock.unlock();
}

test "file list" {
    _ = try get_files("/Users/bcraton/code/zig/zcloc", testing.allocator);
}
