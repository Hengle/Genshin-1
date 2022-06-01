#pragma once

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

///////////////////////////////////////////////////////////////////////////////
//                         Shade Struct                                      //
///////////////////////////////////////////////////////////////////////////////
struct ToonSurfaceData
{
    half3 albedo;//颜色
    half alpha;//透明度
    half3 emission;//自发光
    half occlusion;//AO

};

struct ToonLightingData
{
    half3 normalWS;
    float3 positionWS;
    half3 viewDirectionWS;
    float4 shadowCoord;
};

ToonSurfaceData InitToonSurfaceData(half3 albedo, half alpha, half3 emission, half occlusion)
{
    ToonSurfaceData surfaceData;
    surfaceData.albedo = albedo;
    surfaceData.alpha = alpha;
    surfaceData.emission = emission;
    surfaceData.occlusion = occlusion;
    return surfaceData;
}

ToonLightingData InitToonLightingData(float3 positionWS, half3 normalWS)
{
    ToonLightingData lightingData;
    lightingData.positionWS = positionWS;
    lightingData.viewDirectionWS = SafeNormalize(GetCameraPositionWS() - lightingData.positionWS);
    lightingData.normalWS = normalize(normalWS);
    return lightingData;
}


///////////////////////////////////////////////////////////////////////////////
//                        Shade Light                                        //
///////////////////////////////////////////////////////////////////////////////
half3 ShadeSingleLight(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light)
{
    return surfaceData.albedo;
    float NdotL = saturate(dot(lightingData.normalWS, light.direction));

    float lightSmooth = smoothstep(_LightSmooth - 0.05, _LightSmooth + 0.05, NdotL);
    // return lightSmooth;
    return lerp(_ShadowColor, surfaceData.albedo, lightSmooth);




    // return surfaceData.albedo * NdotL;

}

half3 ShadeAllLight(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    Light mainLight = GetMainLight();
    half3 mainLightResult = ShadeSingleLight(surfaceData, lightingData, mainLight);

    half3 finalResult = mainLightResult;
    return finalResult;
}
