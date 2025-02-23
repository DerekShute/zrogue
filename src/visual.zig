//
// Generate visualization of common structures
//

// https://ziggit.dev/t/error-when-generating-struct-field-names-using-zig-comptime/6319/2

const std = @import("std");
const comptimePrint = std.fmt.comptimePrint;

pub fn genFields(comptime T: type) []const []const u8 {
    const typeInfo = @typeInfo(T);
    switch (typeInfo) {
        .Struct => |structInfo| {
            const field_count = structInfo.fields.len;
            var field_names: [field_count + 1][]const u8 = undefined;
            field_names[0] = comptimePrint("{s}:", .{@typeName(T)});
            for (structInfo.fields, 0..) |field, i| {
                field_names[i + 1] = comptimePrint("  {s}: \"{}\"", .{ field.name, field.type });
            }
            const frozen = field_names;
            return &frozen;
        },
        else => @compileError("Only structs are supported!"),
    }
}

// EOF
