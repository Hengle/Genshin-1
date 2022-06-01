Shader "XHH/Genshin"
{
    Properties
    {
        [Header(Base Color)]
        [MainTexture] _BaseMap ("MainTex", 2D) = "white" { }
        [HDR][MainColor]_BaseColor ("BaseColor", Color) = (1, 1, 1, 1)

        [Header(Alpha)]
        [Toggle(_UseAlphaClipping)]_UseAlphaClipping ("_UseAlphaClipping", Float) = 0
        _Cutoff ("_Cutoff (Alpha Cutoff)", Range(0.0, 1.0)) = 0.5


        [Header(Shadow)]
        _ShadowColor ("Shadow Color", Color) = (0, 0, 0, 1)
        _LightSmooth ("Light Smooth", range(0, 1)) = 0.1

        [Header(Rim)]//边缘光
        _RimColor ("Rim Color", Color) = (1, 1, 1, 1)
        _MinRange ("MinRange", Range(0, 1)) = 0
        _MaxRange ("MaxRange", Range(0, 1)) = 1

        [Header(Outline)]
        _OutlineWidth ("_OutlineWidth (World Space)", Range(0, 4)) = 1
        _OutlineColor ("_OutlineColor", Color) = (0.5, 0.5, 0.5, 1)
    }

    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    CBUFFER_START(UnityPerMaterial)
    // base color
    half4 _BaseMap_ST, _BaseMap_TexelSize;
    half3 _BaseColor;

    half3 _ShadowColor;
    half _LightSmooth;

    // rim
    half3 _RimColor;
    float _MinRange, _MaxRange;

    // outline
    float _OutlineWidth;
    half3 _OutlineColor;
    CBUFFER_END

    TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
    
    ENDHLSL

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            
            Cull Off
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            #include "./HLSLIncludes/ToonLightingEquation.hlsl"

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            

            struct Attributes
            {
                float4 positionOS: POSITION;
                float2 uv: TEXCOORD0;
                float3 normalOS: NORMAL;
            };


            struct Varyings
            {
                float4 positionCS: SV_POSITION;
                float3 positionWS: TEXCOORD2;
                float2 uv: TEXCOORD0;
                float3 normalWS: NORMAL;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);

                return output;
            }


            half4 frag(Varyings input): SV_Target
            {
                float2 uv = input.uv;

                half4 var_BaseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
                half3 albedo = var_BaseMap.rgb;// * _BaseColor;
                half alpha = var_BaseMap.a;
                ToonSurfaceData surfaceData = InitToonSurfaceData(albedo, alpha, 0, 1);
                ToonLightingData lightingData = InitToonLightingData(input.positionWS, input.normalWS);
                half3 finalRGB = ShadeAllLight(surfaceData, lightingData);

                float2 screenUV = (input.positionCS.xy / _ScreenParams.xy);

                half3 depthOffsetRim = DepthOffsetRim(input.positionCS, lightingData, _OutlineWidth, _MinRange, _MaxRange, _RimColor);
                finalRGB += depthOffsetRim;

                half3 edgeHighLight = EdgeHighLight(screenUV, lightingData, GetMainLight(), _RimColor, _OutlineWidth * 0.001);
                // finalRGB += edgeHighLight;


                return half4(finalRGB, 1);
            }
            
            ENDHLSL

        }

        Pass
        {
            Name "Outline"
            Tags {  }

            Cull Front

            HLSLPROGRAM

            #pragma vertex OutlineVert
            #pragma fragment OutlineFrag


            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS: POSITION;
                float2 uv: TEXCOORD0;
                float3 normalOS: NORMAL;
            };


            struct Varyings
            {
                float4 positionCS: SV_POSITION;
                float3 positionWS: TEXCOORD2;
                float2 uv: TEXCOORD0;
                float3 normalWS: NORMAL;
            };


            

            Varyings OutlineVert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.uv = input.uv;
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);

                return output;
            }

            half4 OutlineFrag(Varyings input): SV_Target
            {
                return 1;
                // return half4(_OutlineColor, 1);

            }


            ENDHLSL

        }


        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On // the only goal of this pass is to write depth!
            ZTest LEqual // early exit at Early-Z stage if possible
            ColorMask 0 // we don't care about color, we just want to write depth, ColorMask 0 will save some write bandwidth
            Cull Back // support Cull[_Cull] requires "flip vertex normal" using VFACE in fragment shader, which is maybe beyond the scope of a simple tutorial shader

            HLSLPROGRAM

            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // #include "./HMK_Lit_Input.hlsl"
            #include "./ShadowCasterPass.hlsl"

            ENDHLSL

        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask 0
            Cull Off

            HLSLPROGRAM

            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // #include "./HMK_Lit_Input.hlsl"
            #include "./DepthOnlyPass.hlsl"

            ENDHLSL

        }
    }
    FallBack "Diffuse"
}
