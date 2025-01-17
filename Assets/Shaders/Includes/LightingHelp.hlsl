void GetMainLight_float(float3 WorldPos, out float3 Color, out float3 Direction, out float DistanceAtten, out float ShadowAtten)
{
#ifdef SHADERGRAPH_PREVIEW
    Direction = normalize(float3(0.5, 0.5, 0));
    Color = 1;
    DistanceAtten = 1;
    ShadowAtten = 1;
#else
#if SHADOWS_SCREEN
        float4 clipPos = TransformWorldToClip(WorldPos);
        float4 shadowCoord = ComputeScreenPos(clipPos);
#else
    float4 shadowCoord = TransformWorldToShadowCoord(WorldPos);
#endif

    Light mainLight = GetMainLight(shadowCoord);
    Direction = mainLight.direction;
    Color = mainLight.color;
    DistanceAtten = mainLight.distanceAttenuation;
    ShadowAtten = mainLight.shadowAttenuation;
#endif
}

void ComputeAdditionalLighting_float(float3 WorldPosition, float3 WorldNormal,
    float2 Thresholds, float3 RampedDiffuseValues,
    out float3 Color, out float Diffuse)
{
    Color = float3(0, 0, 0);
    Diffuse = 0;

#ifndef SHADERGRAPH_PREVIEW

    int pixelLightCount = GetAdditionalLightsCount();

    for (int i = 0; i < pixelLightCount; ++i)
    {
        Light light = GetAdditionalLight(i, WorldPosition);
        float4 tmp = unity_LightIndices[i / 4];
        uint light_i = tmp[i % 4];

        half shadowAtten = light.shadowAttenuation * AdditionalLightRealtimeShadow(light_i, WorldPosition, light.direction);

        half NdotL = saturate(dot(WorldNormal, light.direction));
        half distanceAtten = light.distanceAttenuation;

        half thisDiffuse = distanceAtten * shadowAtten * NdotL;

        half rampedDiffuse = 0;

        if (thisDiffuse < Thresholds.x)
        {
            rampedDiffuse = RampedDiffuseValues.x;
        }
        else if (thisDiffuse < Thresholds.y)
        {
            rampedDiffuse = RampedDiffuseValues.y;
        }
        else
        {
            rampedDiffuse = RampedDiffuseValues.z;
        }


        if (shadowAtten * NdotL == 0)
        {
            rampedDiffuse = 0;

        }

        if (light.distanceAttenuation <= 0)
        {
            rampedDiffuse = 0.0;
        }

        Color += max(rampedDiffuse, 0) * light.color.rgb;
        Diffuse += rampedDiffuse;
    }
#endif
}

void ChooseColor_float(float3 Highlight, float3 Midtone, float3 Shadow, float Diffuse, float2 Thresholds, out float3 OUT)
{
    if (Diffuse < Thresholds.x)
    {
        OUT = Shadow;
    }
    else if (Diffuse < Thresholds.y)
    {
        OUT = Midtone;
    }
    else
    {
        OUT = Highlight;
    }
}

float3 LightingSpecular(float3 lightColor, float3 lightDir, float3 normal, float3 viewDir, float4 specular, float smoothness) {
    float3 halfVec = SafeNormalize(lightDir + viewDir);
    float NDotH = saturate(dot(normal, halfVec));
    float modifier = pow(NDotH, smoothness);
    float3 specularReflection = specular.rgb * modifier;
    return lightColor * specularReflection;
}

void DirectSpecular_float(float3 Specular, float Smoothness, float3 Direction, float3 Color, float3 WorldNormal,
    float3 WorldView, out float3 OUT) {
#if SHADERGRAPH_PREVIEW
	OUT = 0;
#else
    Smoothness = exp2(10.0f * Smoothness + 1.0f);
    WorldNormal = normalize(WorldNormal);
    WorldView = SafeNormalize(WorldView);
    OUT = LightingSpecular(Color, Direction, WorldNormal, WorldView, float4(Specular, 0.0f), Smoothness);
#endif
}

void AnimationColor_float(float time, out float3 color) {
    float t = (time / 10.0f);
    t -= floor(t);

    float val = 0.0f;
    if (t < 0.3) val = 0.0f;
    else if (t < 0.5) val = (t - 0.3) / 0.2;
    else if (t < 0.8) val = 1.0f;
    else val = lerp(1, 0, (t - 0.8) / 0.2);

    color = lerp(float3(1, 1, 1), float3(0.91, 0.11, 0.39), val);
}
