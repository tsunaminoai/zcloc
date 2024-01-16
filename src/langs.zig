const std = @import("std");
const testing = std.testing;

/// A map from file extensions to languages.
pub const ExtensionMap = blk: {
    @setEvalBranchQuota(50_000);
    const map = std.ComptimeStringMap(*const Language, Langs);
    break :blk map;
};

/// Language information
pub const Language = struct {
    display_name: []const u8,
    otherNames: ?[]const []const u8 = null,
    extensions: []const []const u8,
    comment_prefix: ?[]const u8 = "//",
};

/// Definitions of languages
const Defs = &[_]Language{
    .{
        .display_name = "ADSO",
        .otherNames = &.{"IDSM"},
        .extensions = &.{"adso"},
        .comment_prefix = null,
    },
    .{
        .display_name = "zig",
        .extensions = &.{ "zig", "zon" },
        .comment_prefix = "//",
    },
    .{
        .display_name = "C",
        .extensions = &.{ "c", "idc", "cats" },
    },
    .{
        .display_name = "Perl",
        .extensions = &.{ "pl", "plh", "PL", "p6", "plx", "pm" },
        .comment_prefix = "#",
        .otherNames = &.{ "Prolog", "Raku" },
    },
    .{
        .display_name = "Python",
        .extensions = &.{
            "pyt",
            "pyp",
            "pyi",
            "pyde",
            "py3",
            "lmi",
            "gypi",
            "gyp",
            "build.bazel",
            "buck",
            "gclient",
            "py",
            "pyw",
        },
        .comment_prefix = "#",
    },
    .{
        .display_name = "C++",
        .extensions = &.{
            "c++",
            "C",
            "cc",
            "ccm",
            "c++m",
            "cppm",
            "cxxm",
            "h++",
            "inl",
            "ipp",
            "ixx",
            "tcc",
            "tpp",
        },
    },
    .{
        .display_name = "ABAP",
        .extensions = &.{"abap"},
    },
    .{
        .display_name = "m4",
        .extensions = &.{"ac"},
        .comment_prefix = "#",
    },
    .{
        .display_name = "Ada",
        .extensions = &.{ "ada", "adb", "ads" },
    },
    .{
        .display_name = "Agda",
        .extensions = &.{ "agda", "lagda" },
    },
    .{
        .display_name = "AspectJ",
        .extensions = &.{"aj"},
    },
    .{
        .display_name = "make",
        .extensions = &.{"am"},
    },
    .{
        .display_name = "AMPLE",
        .extensions = &.{ "ample", "dofile", "startup" },
    },
    .{
        .display_name = "APL",
        .extensions = &.{
            "apl",
            "apla",
            "aplf",
            "aplo",
            "apln",
            "aplc",
            "apli",
            "dyalog",
            "dyapp",
            "mipage",
        },
    },
    .{
        .display_name = "AppleScript",
        .extensions = &.{"applescript"},
    },
    .{
        .display_name = "ActionScript",
        .extensions = &.{"as"},
    },
    .{
        .display_name = "AsciiDoc",
        .extensions = &.{ "adoc", "asciidoc" },
    },
    .{
        .display_name = "Shell",
        .extensions = &.{"sh"},
        .comment_prefix = "#",
    },
    .{
        .display_name = "XML",
        .extensions = &.{
            "xml",         "xlsx",               "osm",
            "odd",         "nuspec",             "nuget.config",
            "nproj",       "ndproj",             "natvis",
            "mjml",        "mdpolicy",           "launch",
            "kml",         "jsproj",             "jelly",
            "ivy",         "iml",                "grxml",
            "gmx",         "fsproj",             "filters",
            "dotsettings", "dll.config",         "ditaval",
            "ditamap",     "depproj",            "ct",
            "csl",         "csdef",              "cscfg",
            "cproject",    "clixml",             "ccxml",
            "ccproj",      "builds",             "axml",
            "app.config",  "ant",                "admx",
            "adml",        "project",            "classpath",
            "xml",         "XML",                "vxml",
            "vstemplate",  "vssettings",         "vsixmanifest",
            "vcxproj",     "ux",                 "urdf",
            "tmtheme",     "tmsnippet",          "tmpreferences",
            "tmlanguage",  "tml",                "tmcommand",
            "targets",     "sublime-snippet",    "sttheme",
            "storyboard",  "srdf",               "shproj",
            "sfproj",      "settings.stylecop",  "scxml",
            "rss",         "resx",               "rdf",
            "pt",          "psc1",               "ps1xml",
            "props",       "proj",               "plist",
            "pkgproj",     "packages.config",    "zcml",
            "xul",         "xspec",              "xproj",
            "xml.dist",    "xliff",              "xlf",
            "xib",         "xacro",              "x3d",
            "wsf",         "web.release.config", "web.debug.config",
            "web.config",
        },
        .comment_prefix = "<!--",
    },
};

const Tup = std.meta.Tuple(&[_]type{ []const u8, *const Language });
/// A list of all languages by their extensions.
const Langs = init_langs: {
    var num_extensions = 0;
    for (Defs) |d|
        num_extensions += d.extensions.len;

    var array: [num_extensions]Tup = undefined;
    var ext_id = 0;

    for (Defs) |*d| {
        for (d.extensions) |e| {
            array[ext_id] = .{ e, d };
            ext_id += 1;
        }
    }

    break :init_langs &array;
};

test "ext map" {
    try testing.expectEqual(ExtensionMap.has("zig"), true);
    try testing.expectEqual(ExtensionMap.has("adso"), true);
    try testing.expectEqual(ExtensionMap.get("adso").?.extensions.len, 1);
}
