shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_back;

uniform sampler2D atlas_tex : filter_nearest;

varying vec4 v_inst;
varying float v_light;

void vertex() {
    v_inst = INSTANCE_CUSTOM;
	v_light = COLOR.r;
	
    float sx = length(MODEL_MATRIX[0].xyz);
    float sy = length(MODEL_MATRIX[1].xyz);
    float sz = length(MODEL_MATRIX[2].xyz);

    mat4 billboard_model = mat4(
        vec4(normalize(INV_VIEW_MATRIX[0].xyz) * sx, 0.0), // right
        vec4(normalize(INV_VIEW_MATRIX[1].xyz) * sy, 0.0), // up
        vec4(normalize(INV_VIEW_MATRIX[2].xyz) * sz, 0.0), // forward
        MODEL_MATRIX[3]                                    // translation
    );

    MODELVIEW_MATRIX = VIEW_MATRIX * billboard_model;
}


void fragment() {
	vec2 origin = v_inst.xy;
	vec2 size   = v_inst.zw;

	vec2 uv = origin + UV * size;
	vec4 col = texture(atlas_tex, uv);

	if (col.a < 0.01) discard;

	vec3 c = pow(col.rgb, vec3(2.2)); // sRGB -> linear
	c *= v_light;
	
	ALBEDO = c;
	ALPHA  = 1.0;
}
