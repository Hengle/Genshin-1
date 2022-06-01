#pragma once

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

// Z buffer to linear 0..1 depth (0 at camera position, 1 at far plane).
// Does NOT work with orthographic projections.
// Does NOT correctly handle oblique view frustums.
// zBufferParam = { (f-n)/n, 1, (f-n)/n*f, 1/f }
float Linear01Depth(float depth)
{
    // return 1.0 / (zBufferParam.x * depth + zBufferParam.y);
    return Linear01Depth(depth, _ZBufferParams);
}

// Z buffer to linear depth.
// Does NOT correctly handle oblique view frustums.
// Does NOT work with orthographic projection.
// zBufferParam = { (f-n)/n, 1, (f-n)/n*f, 1/f }
float LinearEyeDepth(float depth)
{
    // return 1.0 / (zBufferParam.z * depth + zBufferParam.w);
    return LinearEyeDepth(depth, _ZBufferParams);
}
