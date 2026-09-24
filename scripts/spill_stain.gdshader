shader_type spatial;
render_mode blend_mix, cull_back, unshaded;

// Assign this material to the floor-stain MeshInstance3D's surface.
// scrub_progress is what SpillCleaner.gd / PermanentStain.gd drive at
// runtime via set_shader_parameter("scrub_progress", value).

uniform sampler2D stain_texture : source_color;
uniform vec4 stain_tint : source_color = vec4(0.22, 0.16, 0.07, 1.0);
uniform float scrub_progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex_sample = texture(stain_texture, UV);
	ALBEDO = stain_tint.rgb * tex_sample.rgb;
	// Straight alpha lerp per spec: fully opaque at progress 0.0, fully
	// invisible at progress 1.0.
	ALPHA = tex_sample.a * (1.0 - scrub_progress);
}
