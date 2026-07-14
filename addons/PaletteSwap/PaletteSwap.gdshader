shader_type canvas_item;

uniform sampler2D palette;
uniform bool skip_first_row = true;
uniform bool use_palette_alpha = false;
uniform float fps = 6;
uniform float palette_columns = 16.0;
uniform float palette_rows = 16.0;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	ivec3 colori = ivec3(floor(original_color.rgb * 255.0 + vec3(0.5)));
	
	float columns = max(palette_columns, 1.0);
	float rows_total = max(palette_rows, 1.0);
	
	float idx = -1.0;
	// ANGLE/UWP requires a compile-time loop bound. Palette textures in this
	// project are much smaller than 256 columns.
	for (int i = 0; i < 256; i++) {
		if (float(i) >= columns) {
			break;
		}
		vec3 color2 = texture(palette, vec2(float(i) / max(columns - 1.0, 1.0), 0.0)).rgb;
		ivec3 colori2 = ivec3(floor(color2 * 255.0 + vec3(0.5)));
		
		if (colori == colori2) {
			idx = float(i);
			break;
		}
	}
	
	if (idx >= 0.0) {
		vec2 uv;
		float first_row = float(skip_first_row);
		float animated_rows = max((rows_total - 1.0) - first_row, 1.0);
		uv.x = idx / max(columns - 1.0, 1.0);
		uv.y = (mod(TIME * fps, animated_rows) + first_row) / max(rows_total - 1.0, 1.0);
		
		vec4 palette_color = texture(palette, uv);
		COLOR = vec4(palette_color.rgb, mix(original_color.a, palette_color.a, float(use_palette_alpha)));
	} else {
		COLOR = original_color;
	}
}
