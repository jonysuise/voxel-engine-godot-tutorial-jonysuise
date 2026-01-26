shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float speed = 4.0;        // blink speed
uniform float min_alpha = 0.15;
uniform float max_alpha = 0.6;

void fragment() {
	// time-based pulse (0..1)
	float t = 0.5 + 0.5 * sin(TIME * speed);

	// alpha pulse
	float a = mix(min_alpha, max_alpha, t);

	ALBEDO = color.rgb;
	ALPHA = a;
}
