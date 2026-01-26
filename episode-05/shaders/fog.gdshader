shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back;

uniform vec3 player_world_pos = vec3(0.0);
uniform float fog_start = 6.0;
uniform float fog_end   = 30.0;
uniform float lit_fog_start = 128.0;
uniform float lit_fog_end   = 256.0;
uniform float darken_max = 1.0;
const float LIT_FOG_MAX = 1.0; 
uniform float dark_luma_threshold = 0.25;
uniform int version = 1;
varying vec3 v_world_pos;
varying float v_luma;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_luma = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	float dist = length(v_world_pos - player_world_pos);

	float t_dark = smoothstep(fog_start, fog_end, dist);
	float t_lit  = smoothstep(lit_fog_start, lit_fog_end, dist);

	float is_dark = step(v_luma, dark_luma_threshold);
	float is_lit  = 1.0 - is_dark;

	vec3 sky_col = vec3(0.1707, 0.5457, 0.9387);
	vec3 blk_col = vec3(0.005);

	float a_dark = is_dark * t_dark * darken_max;
	float a_lit  = (version > 2) ? (is_lit * t_lit * LIT_FOG_MAX) : 0.0;

	bool lit_mode = (a_lit > 0.0001);

	ALBEDO = lit_mode ? sky_col : blk_col;
	ALPHA  = lit_mode ? a_lit   : a_dark;
}
