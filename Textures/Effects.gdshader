shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float infection_level : hint_range(0.0, 1.0) = 0.0;
uniform float blur_amount : hint_range(0.0, 0.02) = 0.008;
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.5;
uniform vec4 vignette_color : source_color = vec4(0.3, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;

	// blur increases with infection
	vec4 color = vec4(0.0);
	float blur = blur_amount * infection_level;
	color += texture(screen_tex, uv + vec2(-blur, -blur));
	color += texture(screen_tex, uv + vec2( blur, -blur));
	color += texture(screen_tex, uv + vec2(-blur,  blur));
	color += texture(screen_tex, uv + vec2( blur,  blur));
	color += texture(screen_tex, uv);
	color /= 5.0;

	// desaturate as infection rises
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(color.rgb, vec3(gray), infection_level * 0.6);

	// vignette darkens/reddens edges
	float dist = distance(uv, vec2(0.5));
	float vig = smoothstep(0.3, 0.8, dist) * infection_level * vignette_strength;
	color.rgb = mix(color.rgb, vignette_color.rgb, vig);

	COLOR = color;
}