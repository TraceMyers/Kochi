pub const Vertex = struct {
    position: fVec2 = undefined,
    color: fVec3 = undefined,
    tex_coords: fVec2 = undefined,

    pub inline fn getBindingDescription() c.VkVertexInputBindingDescription {
        return c.VkVertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .inputRate  = c.VK_VERTEX_INPUT_RATE_VERTEX,
        };
    }

    pub inline fn getAttributeDesriptions() [3]c.VkVertexInputAttributeDescription {
        var desc: [3]c.VkVertexInputAttributeDescription = undefined;
        desc[0] = c.VkVertexInputAttributeDescription{
            .location = 0,
            .binding = 0,
            .format = c.VK_FORMAT_R32G32_SFLOAT,
            .offset = @offsetOf(Vertex, "position")
        };
        desc[1] = c.VkVertexInputAttributeDescription{
            .location = 1,
            .binding = 0,
            .format = c.VK_FORMAT_R32G32B32_SFLOAT,
            .offset = @offsetOf(Vertex, "color")
        };
        desc[2] = c.VkVertexInputAttributeDescription{
            .location = 2,
            .binding = 0,
            .format = c.VK_FORMAT_R32G32_SFLOAT,
            .offset = @offsetOf(Vertex, "tex_coords")
        };
        return desc;
    }
};

// --- Image pixel types ---



pub const fMVP = struct {
    model: fMat4x4 align(16) = undefined,
    view: fMat4x4 align(16) = undefined,
    projection: fMat4x4 align(16) = undefined,
};

const kmath = @import("math.zig");
const fMat4x4 = kmath.fMat4x4;
const fVec2 = kmath.fVec2;
const fVec3 = kmath.fVec3;
const LocalArray = @import("array.zig").LocalArray;
const c = @import("ext.zig").c;
const std = @import("std");
