shader_type spatial;

uniform vec3 color_a : source_color = vec3(0.9, 0.9, 0.9);
uniform vec3 color_b : source_color = vec3(0.1, 0.1, 0.1);
uniform float tiles = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex()
{
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment()
{
    vec3 p = world_pos - normalize(world_normal) * (0.01 / tiles);

    vec2 cell = floor(p.xz * tiles);
    float checker = mod(cell.x + cell.y, 2.0);

    ALBEDO = mix(color_a, color_b, checker);
}