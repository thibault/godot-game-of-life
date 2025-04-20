#[compute]
#version 450

// Define the local group size.
// This is how many times in parallel this shader will run, for each work group.
// 8 seems a good default value.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

/*
  Uniform values are variables that are the same for every shader instance.
  I.e every shader will work on the same uniform.
  We use a sampler2D for the input value, and we write to a different texture
  for the output.
  In the Gdscript we wrote, each different buffer gets it's own `set` value,
  with a `0` binding for input, and `1` binding for output.
  The `set` and `binding` value
*/
layout(set = 0, binding = 0) uniform sampler2D cells_tex;
layout(set = 0, binding = 1, r32f) uniform restrict writeonly image2D cells_out;

// The push constant is an efficient way to pass small data to a shader.
layout(push_constant, std430) uniform Params {
    vec2 grid_size;
} params;

void main() {
    /*
      Here, we get the pixel coordinates at which the shader is called.
      This is equivalent to something like:
      for (x in work_group_x_)
        for (y in work_group_y)
          for (i in local_group_x)
            for (j in local_group_y)
              invocation_x = x * work_group_x + i
              invocation_y = y * work_group_y + j
              invoke_shader(invocation_x, invocation_y)
    */
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);

    /*
      Since we used an unnormalized sampler, the texture coordinates are the
      same as the sampler coordinates.
      E.g for a 100x100 texture, you can get the value of the center pixel at (50,50)
      by sampling at coordinates (50,50) (instead of (0.5,0.5) with a normalized sampler).
      But there's a catch.
      Sampler consider that a texel value is set at the center of the texel.
      Since a texel as a size of (1x1), you can access the value of pixel (50,50) with:

      float cellValue = texelFetch(cells_tex, ivec2(50, 50), 0).r;

      or
      float texelDelta = vec2(0.5);
      float cellValue = texture(cells_tex, vec2(50, 50) + texelDelta).r;

      If you try to sample the texture at (50, 50), you are actually sampling the top-left corner
      of the texel, so you will get an interpolated value between the four surrounding texels.
    */
    vec2 texel_pos = pos + vec2(0.5);

    // Let's make sure the shader is not working outside the buffer coordinates
    ivec2 size = ivec2(params.grid_size);
    if (pos.x >= size.x || pos.y >= size.y) {
       return;
    }

    // This is a very basic and straightforward game of life implementation here
    int neighbours = 0;
    for (int i = -1 ; i <= 1 ; i++) {
        for (int j = -1 ; j <= 1 ; j++) {
            if (i == 0 && j == 0) continue;

            // We could use `texelFetch` to get the pixel color here.
            // But by using `texture` we get a defined behaviour when we sample
            // outside the texture coordinates (like clamp or repeat).
            if (texture(cells_tex, texel_pos + vec2(i, j)).r >= 0.99) neighbours++;
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
