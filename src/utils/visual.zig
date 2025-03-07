//
// Generate visualization of common structures
//

// https://ziggit.dev/t/error-when-generating-struct-field-names-using-zig-comptime/6319/2

const std = @import("std");
const comptimePrint = std.fmt.comptimePrint;

pub fn genFields(comptime T: type) []const []const u8 {
    const typeInfo = @typeInfo(T);
    switch (typeInfo) {
        .@"struct" => |structInfo| {
            const field_count = structInfo.fields.len;
            const decls_count = structInfo.decls.len;
            var names: [field_count + decls_count + 1][]const u8 = undefined;
            names[0] = comptimePrint("{s}:", .{@typeName(T)});
            for (structInfo.fields, 1..) |field, i| {
                names[i] = comptimePrint("  {s}: \"{}\"", .{ field.name, field.type });
            }
            for (structInfo.decls, field_count + 1..) |decl, i| {
                names[i] = comptimePrint("  {s}: \"(decl)\"", .{decl.name});
            }
            const frozen = names;
            return &frozen;
        },
        else => @compileError("Only structs are supported!"),
    }
}

// EOF
