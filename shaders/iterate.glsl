#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D cells_tex;
layout(set = 0, binding = 1, r32f) uniform restrict writeonly image2D cells_out;

layout(push_constant, std430) uniform Params {
    vec2 grid_size;
} params;

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = ivec2(params.grid_size);

    if (pos.x >= size.x || pos.y >= size.y) {
        return;
    }

    int neighbours = 0;
    for (int i = -1 ; i <= 1 ; i++) {
        for (int j = -1 ; j <= 1 ; j++) {
            if (i == 0 && j == 0) continue;
            if (texelFetch(cells_tex, pos + ivec2(i, j), 0).r == 1.0) neighbours++;
        }
    }

    float new_state;
    switch (neighbours) {
        case 2: new_state = texelFetch(cells_tex, pos, 0).r; break;
        case 3: new_state = 1.0; break;
        default: new_state = 0.0;
    }

    imageStore(cells_out, pos, vec4(new_state, 0.0, 0.0, 0.0));
}

