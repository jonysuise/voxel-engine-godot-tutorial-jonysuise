shader_type spatial;

uniform sampler2D atlas_tex : source_color, filter_nearest;

uniform int tiles_per_row = 3;   // 3x3 atlas
uniform int tile_index = 0;      // 0..8 (top row: 0,1,2)
uniform vec3 box_size = vec3(1.0, 1.0, 1.0); // MUST match your BoxMesh size

varying vec2 v_face_uv;

void vertex() {
	// Normalize local vertex position into 0..1 across the box
	// BoxMesh(size=1) => VERTEX is typically -0.5..+0.5
	vec3 p = VERTEX / box_size + vec3(0.5);

	vec3 n = normalize(NORMAL);
	vec3 an = abs(n);

	// Pick a projection plane per face (no blending)
	if (an.y >= an.x && an.y >= an.z) {
		v_face_uv = p.xz;      // top/bottom
	} else if (an.x >= an.y && an.x >= an.z) {
		v_face_uv = p.zy;      // +/-X faces
	} else {
		v_face_uv = p.xy;      // +/-Z faces
	}

	// Keep within 0..1
	v_face_uv = clamp(v_face_uv, vec2(0.0), vec2(1.0));
}

void fragment() {
	int col = tile_index % tiles_per_row;
	int row = tile_index / tiles_per_row;

	vec2 tile_size = vec2(1.0 / float(tiles_per_row));
	int row_flipped = (tiles_per_row - 1) - row; // make 0,1,2 be the TOP row

	vec2 tile_offset = vec2(float(col), float(row_flipped)) * tile_size;
	vec2 uv = tile_offset + v_face_uv * tile_size;

	ALBEDO = texture(atlas_tex, uv).rgb;
}
