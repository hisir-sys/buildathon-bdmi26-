shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded, alpha_to_coverage;

// Floor stain mask. `scrub_progress` is driven every frame by
// scripts/tasks/spill_cleaner.gd (and permanent_stain.gd, which caps it at
// 0.99). Alpha lerps from fully visible at 0.0 to fully transparent at 1.0,
// with an irregular edge (via noise) so the stain doesn't look like it's
// fading as a perfect disc.

uniform vec4 stain_color : source_color = vec4(0.05, 0.04, 0.03, 1.0);
uniform float scrub_progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.18;
uniform float noise_scale : hint_range(1.0, 40.0) = 12.0;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.35;

// Cheap value-noise so the shader has no texture dependency.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	// Distance from the stain's edge (UV 0.5,0.5 is the center of the
	// mesh/quad this material is applied to).
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 2.0;

	float n = value_noise(UV * noise_scale) * noise_strength;
	float ragged_dist = dist + n * (1.0 - scrub_progress);

	// Base disc falloff so the stain has a soft, irregular silhouette even
	// before scrubbing starts.
	float shape_alpha = 1.0 - smoothstep(1.0 - edge_softness, 1.0, ragged_dist);

	// scrub_progress erases the stain from the inside out with a soft,
	// noise-perturbed front, so it reads as being wiped away unevenly
	// rather than uniformly fading.
	float wipe_front = scrub_progress * 1.15;
	float wiped_alpha = smoothstep(wipe_front - edge_softness, wipe_front, dist + n * 0.4);

	float final_alpha = shape_alpha * wiped_alpha;

	ALBEDO = stain_color.rgb;
	ALPHA = clamp(final_alpha * stain_color.a, 0.0, 1.0);
}
