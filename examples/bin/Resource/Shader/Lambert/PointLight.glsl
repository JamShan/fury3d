#version 330

#ifdef VERTEX_SHADER

in vec3 vertex_position;

out vec3 vs_pos;
out vec4 ss_pos;

uniform mat4 projection_matrix;
uniform mat4 invert_view_matrix;
uniform mat4 world_matrix;

void main()
{
	vs_pos = (invert_view_matrix * world_matrix * vec4(vertex_position, 1.0)).xyz;
	ss_pos = projection_matrix * vec4(vs_pos, 1);
	gl_Position = ss_pos;
}

#endif

#ifdef FRAGMENT_SHADER

out vec4 fragment_output;

in vec3 vs_pos;
in vec4 ss_pos;

uniform float camera_far = 10000;

uniform mat4 invert_view_matrix;

uniform vec3 light_pos;
uniform vec3 light_color;
uniform float light_falloff;
uniform float light_radius;
uniform float light_intensity;

// linear depth
uniform sampler2D gbuffer_depth;
// normal, shniness
uniform sampler2D gbuffer_normal;

#ifdef SHADOW
uniform mat4 shadow_proj;
uniform mat4 shadow_matrix;
uniform samplerCube shadow_buffer;
#endif

vec3 pos_from_depth(const in vec2 screenUV)
{
 	float depth = texture(gbuffer_depth, screenUV).r;
	vec3 view_ray = vec3(vs_pos.xy * (camera_far / vs_pos.z), camera_far);
	return -view_ray * depth;
}

vec4 apply_lighting(const in vec3 normal, const in vec3 surface_pos)
{
	vec3 vs_light_pos = (invert_view_matrix * vec4(light_pos, 1)).xyz;

	vec3 L = vs_light_pos - surface_pos;
	
	float dist = length(L);
	float attenuation = pow(max(0.0, 1.0 - dist / light_radius), light_falloff + 1.0);

	L = normalize(L);
	vec3 N = normalize(normal);

	float NdotL = max(0.0, dot(N, L));

	return vec4(
		vec3(1) * light_color * NdotL * attenuation * light_intensity, 1.0
	);
}

void main()
{
	vec2 screenUV = (ss_pos.xy / ss_pos.w) * 0.5 + 0.5;
	vec3 vs_surface_pos = pos_from_depth(screenUV);

	vec4 raw_normal = texture(gbuffer_normal, screenUV);
	vec3 vs_normal = raw_normal.xyz * 2.0 - 1.0;

	fragment_output = apply_lighting(vs_normal, vs_surface_pos);

#ifdef SHADOW
	// world space pos
	vec4 pos = shadow_matrix * vec4(vs_surface_pos, 1.0);
	vec3 dir = pos.xyz - light_pos;

	float closest = texture(shadow_buffer, dir).x * light_radius;
	float current = length(dir);

	fragment_output *= float(current - 0.002 < closest);
#endif
}

#endif