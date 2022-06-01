#pragma once

float2 GetScreenUV(float4 positionCS)
{
    return positionCS.xy / _ScreenParams.xy;
}
