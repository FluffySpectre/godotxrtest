shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.7, 0.7, 0.9, 0.5);
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// Outline properties
uniform vec4 outline_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float outline_thickness : hint_range(0.0, 0.1) = 0.005;
uniform float outline_intensity : hint_range(0.0, 5.0) = 3.0;

// Fade properties
uniform vec3 fade_direction = vec3(0.0, -1.0, 0.0); // Default: fade along negative Y (assuming hand points up)
uniform float fade_start = 0.3;  // Position to start fading (0.0 to 1.0)
uniform float fade_end = 0.8;    // Position to end fading (fully transparent, 0.0 to 1.0)
uniform bool enable_fade = true; // Toggle for the fade effect

varying vec3 vertex_position;

void vertex() {
    // Store the model-space position for use in fragment shader
    vertex_position = VERTEX;
}

void fragment() {
    // Main material properties
    ALBEDO = albedo.rgb;
    ALPHA = albedo.a;
    METALLIC = metallic;
    ROUGHNESS = roughness;

    // Fresnel effect for outline
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), outline_intensity);

    // Apply outline based on fresnel effect
    vec3 final_color = mix(ALBEDO, outline_color.rgb, fresnel * outline_thickness * 100.0);
    ALBEDO = final_color;

    // Calculate alpha with outline
    float alpha_with_outline = mix(albedo.a, outline_color.a, fresnel * outline_thickness * 100.0);

    // Apply fade effect if enabled
    if (enable_fade) {
        // Normalize the position to 0-1 range (assuming model is normalized or you know its bounds)
        // This is an approximation - adjust based on your model's actual dimensions
        vec3 norm_pos = vertex_position * 0.5 + 0.5;

        // Calculate dot product to determine position along fade axis
        float fade_pos = dot(normalize(fade_direction), vertex_position);

        // Remap fade_pos to 0-1 range for easier control
        fade_pos = (fade_pos + 1.0) * 0.5;

        // Calculate fade factor (0 = fully transparent, 1 = original alpha)
        float fade_factor = 1.0 - smoothstep(fade_start, fade_end, fade_pos);

        // Apply fade factor to alpha
        alpha_with_outline *= fade_factor;
    }

    ALPHA = alpha_with_outline;
}