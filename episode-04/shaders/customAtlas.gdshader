shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;
uniform float tile_size = 0.5;

void fragment() {
	vec2 tile_uv  = fract(UV);
	vec2 atlas_uv = UV2 + tile_uv * tile_size;

	vec4 albedo = texture(atlas_texture, atlas_uv);

	// Alpha test (cutout)
	if (albedo.a < 0.5) {
		discard;
	}

	ALBEDO = albedo.rgb * COLOR.rgb;
}