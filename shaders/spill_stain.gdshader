shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded, alpha_to_coverage;

// Floor stain mask. `scrub_progress` is driven every frame by
// scripts/tasks/spill_cleaner.gd (and permanent_stain.gd, which caps it at
// 0.99). Alpha lerps from fully visible at 0.0 to fully transparent at 1.0,
// with an irregular edge (via noise) so the stain doesn't look like it's
// fading as a perfect disc.

uniform vec4 stain_color : source_color = vec4(0.05, 0.04, 0.03, 1.0);
uniform float scrub_progress : hint_range(0.0, 1.0) = 0.0;
uniform float stain_age : hint_range(0.0, 1.0) = 0.0;
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
	vec2 centered = UV - vec2(0.5);
	float radial = length(centered * vec2(1.9, 1.6));
	float angle = atan(centered.y, centered.x);
	float broad_noise = value_noise(UV * noise_scale);
	float fine_noise = value_noise(UV * (noise_scale * 2.4));
	float edge_wave = 0.055 * sin(angle * 3.0 + 1.2) + 0.035 * sin(angle * 7.0 - 0.5);
	edge_wave += (broad_noise - 0.5) * noise_strength * 0.2;
	float boundary = 0.82 + edge_wave;
	float pool = 1.0 - smoothstep(boundary - edge_softness, boundary + edge_softness, radial);

	// Scattered droplets break up the smooth pool edge into an uneven spill.
	vec2 splash_grid = UV * vec2(6.0, 4.0);
	vec2 splash_local = fract(splash_grid) - vec2(0.5);
	vec2 splash_cell = floor(splash_grid);
	float splash_random = hash12(splash_cell + vec2(12.4, 5.7));
	float splash_radius = mix(0.07, 0.17, splash_random);
	float droplet = 1.0 - smoothstep(splash_radius, splash_radius + 0.035, length(splash_local));
	float droplet_gate = step(0.58, hash12(splash_cell + vec2(7.1, 19.2)));
	float splatter = droplet * droplet_gate * (1.0 - smoothstep(0.6, 1.05, radial));
	float shape_alpha = max(pool, splatter * 0.64);

	// Subtle pigment variation gives fresh liquid a wet sheen and old residue
	// a dry, mottled surface instead of a flat, uniform decal.
	float pigment_variation = mix(0.72, 1.12, fine_noise);
	vec3 pigment = stain_color.rgb * pigment_variation;
	float rim = smoothstep(boundary - 0.17, boundary - 0.025, radial) * shape_alpha;
	vec3 rim_tint = pigment * mix(1.2, 0.72, stain_age);
	ALBEDO = mix(pigment, rim_tint, rim * 0.65);
	ROUGHNESS = mix(0.24, 0.98, stain_age);
	SPECULAR = mix(0.72, 0.18, stain_age);

	// Progress wipes fresh liquid away from the middle. A stubborn aged
	// residue remains visible even after the player finishes the old-stain task.
	float wipe_front = scrub_progress * 1.15;
	float wipe_dist = radial + (broad_noise - 0.5) * 0.1;
	float wiped_alpha = smoothstep(wipe_front - edge_softness, wipe_front, wipe_dist);
	float persistent_residue = shape_alpha * stain_age * 0.34;
	float final_alpha = max(shape_alpha * wiped_alpha, persistent_residue);
	ALPHA = clamp(final_alpha * stain_color.a, 0.0, 1.0);
}
