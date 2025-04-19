#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer SplatBuffer {
    vec2 splat_pos;
} splat_buffer;

layout(set = 1, binding = 0) uniform sampler2D cells_tex;
layout(set = 1, binding = 1, r32f) uniform restrict writeonly image2D cells_out;

layout(push_constant, std430) uniform Params {
    vec2 grid_size;
} params;

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = ivec2(params.grid_size);

    if (pos.x >= size.x || pos.y >= size.y) {
        return;
    }

    float cell = texelFetch(cells_tex, pos, 0).r;
    if (distance(splat_buffer.splat_pos, pos) < 2.0) cell = 1.0;

    imageStore(cells_out, pos, vec4(cell, 0.0, 0.0, 0.0));
}
