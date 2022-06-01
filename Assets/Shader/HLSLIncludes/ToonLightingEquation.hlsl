#pragma once

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#include "./Depth.hlsl"
#include "./Common.hlsl"

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
//                       Edge HighLight                                      //
///////////////////////////////////////////////////////////////////////////////

half3 DepthOffsetRim(float4 positionCS, ToonLightingData lightingData, half rimWidth, half minRange, half maxRange, half3 rimColor)
{
    float2 screenUV = GetScreenUV(positionCS);
    float3 normalVS = mul(UNITY_MATRIX_V, float4(lightingData.normalWS, 0)).xyz;
    screenUV += normalVS.xy * rimWidth * 0.001;
    float depthTex = SampleSceneDepth(screenUV);
    float depth = LinearEyeDepth(depthTex);//view space depth
    float rim = saturate((depth - positionCS.w));// / max(0.001, _Spread * 0.01));//稍作缩放, 可以不要
    rim = smoothstep(min(minRange, 0.99), maxRange, rim);
    return rim * rimColor;
}
/////////////

static float2 sobelSamplePoints[9] = {
    float2(-1, 1), float2(0, 1), float2(1, 1),
    float2(-1, 0), float2(0, 0), float2(1, 0),
    float2(-1, -1), float2(0, -1), float2(1, -1)
};

static float sobelXMatrix[9] = {
    - 1, 0, 1,
    - 2, 0, 2,
    - 1, 0, 1
};

half3 SobelEdgeHighLight(float2 screenUV, ToonLightingData lightingData, Light light, half3 edgeColor, half edgeWidth)
{
    float2 sobel = 0;
    for (int i = 0; i < 9; i++)
    {
        float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV + sobelSamplePoints[i] * edgeWidth);
        depth = LinearEyeDepth(depth);
        // float depth = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, screenUV + sobelSamplePoints[i] * _OutlineWidth);
        // float depth = tex2D(_CameraOpaqueTexture, screenUV + sobelSamplePoints[i] * _OutlineWidth);
        sobel += depth * float2(sobelXMatrix[i], sobelXMatrix[i]);
    }

    float NdotL = max(0, dot(lightingData.normalWS, light.direction));

    float edgeHeight = saturate(pow(length(sobel), 4));
    half3 edgeHighLight = edgeColor * edgeHeight * NdotL;
    return edgeHighLight;
}

half3 EdgeHighLight(float2 screenUV, ToonLightingData lightingData, Light light, half3 edgeColor, half edgeWidth)
{
    return SobelEdgeHighLight(screenUV, lightingData, light, edgeColor, edgeWidth);
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
