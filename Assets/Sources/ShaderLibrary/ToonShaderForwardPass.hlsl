#ifndef UNIVERSAL_FORWARD_LIT_PASS_INCLUDED
#define UNIVERSAL_FORWARD_LIT_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// GLES2 has limited amount of interpolators
#if defined(_PARALLAXMAP) && !defined(SHADER_API_GLES)
#define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#if (defined(_NORMALMAP) || (defined(_PARALLAXMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
#define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

// keep this file in sync with LitGBufferPass.hlsl

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 lightmapUV   : TEXCOORD1;
    float3 color : COLOR0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv                       : TEXCOORD0;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    float3 positionWS               : TEXCOORD2;
#endif

    float3 normalWS                 : TEXCOORD3;
//#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    float4 tangentWS                : TEXCOORD4;    // xyz: tangent, w: sign
//#endif
    float3 viewDirWS                : TEXCOORD5;

    half4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord              : TEXCOORD7;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    float3 viewDirTS                : TEXCOORD8;
#endif

    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};



void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    inputData.positionWS = input.positionWS;
#endif

    half3 viewDirWS = SafeNormalize(input.viewDirWS);
#if defined(_NORMALMAP) || defined(_DETAIL)
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
#else
    inputData.normalWS = input.normalWS;
#endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = input.shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif

    inputData.fogCoord = input.fogFactorAndVertexLight.x;
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
}

///////////////////////////////////////////////////////////////////////////////
//                              Toon functions                               //
///////////////////////////////////////////////////////////////////////////////

half4 Toon_Diffuse(Light mainlight, float ndotl, float4 albedo, float lightmap)
{

    //半兰伯特映射
    half halflambert = ndotl * 0.5 + 0.5;
    halflambert *= lightmap;
    half4 rampColor = SAMPLE_TEXTURE2D_LOD(_RampMap, sampler_RampMap, half2(halflambert, _RampRange), 0);
    
    //返回
    half4 diffuse = albedo * _DiffuseColor;
    #if !_SKIN
        diffuse *= rampColor;
    #endif
    diffuse.rgb *= mainlight.color;
    return diffuse;
}

half4 Toon_Face(Light mainlight, half ndotl, half4 albedo, half lightmap, Varyings input)
{

    //向量准备
    half3 front = mul(UNITY_MATRIX_M, half3(0,-1,0));
    half3 right = mul(UNITY_MATRIX_M, half3(1,0,0));
    half ldotx = dot(right, mainlight.direction);
    half ldotZ = dot(front, mainlight.direction);
    
    //采样方向判断
    half rightSample = SAMPLE_TEXTURE2D_LOD(_FaceShadowMap, sampler_FaceShadowMap, half2(1 - input.uv.x, input.uv.y), 0);
    half leftSample = SAMPLE_TEXTURE2D_LOD(_FaceShadowMap, sampler_FaceShadowMap, half2(input.uv.x, input.uv.y), 0);
    half rampColor = step(0, ldotx) ? rightSample : leftSample;
    
    //阴影判断，通过z向投影和rampColor比较
    half shadow = step(rampColor.r, ldotZ * 0.5 + 0.5);

    //阴影虚化，将突变转为渐变
    half soft = step(abs((ldotZ * 0.5 + 0.5) - rampColor.r), _LerpMax);
    shadow = step(1, soft) ? smoothstep(ldotZ * 0.5 + 0.5 + _LerpMax, ldotZ * 0.5 + 0.5 - _LerpMax, rampColor.r) : shadow;
    
    //阴影插值
    half4 diffuse = albedo * _DiffuseColor;
    diffuse = lerp(diffuse * _ShadowColor, diffuse, shadow); 

    //返回
    diffuse.rgb *= mainlight.color;
    return diffuse;
}

half4 Toon_Specular(Light mainlight, Varyings input, half specular, half gloss)
{
    //向量准备
    half3 rDir = reflect(-mainlight.direction, input.normalWS);
    half3 halfDir = SafeNormalize(rDir + normalize(-input.viewDirWS));
    //half3 halfDir = SafeNormalize(mainlight.direction + normalize(input.viewDirWS));
    half ndoth = saturate(dot(input.normalWS, halfDir));
    half ldoth = saturate(dot(mainlight.direction, halfDir));

    //Unity内置BRDF高光计算
    half roughness = gloss * _Gloss;
    half roughness2 = roughness * roughness;
    half roughness2MinusOne = 1 - roughness * roughness;
    half normalizationTerm = roughness * 4.0 + 2.0;

    float d = ndoth * ndoth * roughness2MinusOne + 1.00001f;
    half LoH2 = ldoth * ldoth;
    half specularTerm = roughness2 / ((d * d) * max(0.1h, LoH2) * normalizationTerm);

    //BlinnPhong计算
    //half specularTerm = pow(ndoth, gloss * _Gloss);

    //金属球计算
    #if _MATCAP
        float3 viewNormal = mul(UNITY_MATRIX_V, input.normalWS);
        float3 viewPos = -mul(UNITY_MATRIX_V, input.viewDirWS);
        float3 vTangent = normalize( cross(-viewPos,float3(0,1,0)));
        float3 vBinormal  = cross(viewPos, vTangent);
        float2 matCapUV = float2(dot(vTangent, viewNormal), dot(vBinormal, viewNormal)) * 0.495 + 0.5;
        half metal = SAMPLE_TEXTURE2D(_MetalMap, sampler_MetalMap, matCapUV);
    #else
        half metal = 0;
    #endif

    //NPR高光偷偷乘个albedo没问题吧
    half4 albedo = SAMPLE_TEXTURE2D(_DiffuseMap, sampler_DiffuseMap, input.uv.xy);

    return float4((specularTerm * _SpecularColor.rgb * (specular + metal) * mainlight.color) * albedo, 1);
}

half3 Toon_Anisotropy(Light mainlight, Varyings input, half specular)
{
    half3 T = input.tangentWS;
    half3 rDir = reflect(-mainlight.direction, input.normalWS);
    half3 H = SafeNormalize(rDir + input.viewDirWS);
    return D_KajiyaKay(T, H, specular);
}

half4 Toon_Outline(Attributes input, float4 positionCS)
{
    //模型中心坐标偏移
    //half sign = step(0, dot(input.normalOS, input.positionOS.xyz)) ? 1 : -1;
    //positionCS = mul(UNITY_MATRIX_MVP, half4(input.positionOS.xyz + sign * input.positionOS.xyz * _OutlineOffset * 0.01, 1));
    //positionCS.z -= _OutlineBias * 0.001;

    //模型法线偏移
    positionCS = mul(UNITY_MATRIX_MVP, half4(input.positionOS.xyz + input.normalOS * _OutlineOffset * 0.01 * input.color, 1));
    positionCS.z -= _OutlineBias * 0.001;
    return positionCS;
}

half4 Toon_Rim(Varyings input, Light mainlight)
{
    
    half3 screenOffset = mul(UNITY_MATRIX_V, -mainlight.direction);
    screenOffset.xy /= _ScreenParams.xy;
    screenOffset.xy = normalize(screenOffset.xy);
    half2 screenUV = input.positionCS.xy / _ScreenParams.xy;
    float depth0 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV - screenOffset.xy * 0.01 * _RimOffset);
    float depth1 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV);
    //float rim = step(depth0 + 0.01 * _RimThreshold, depth1);
    float rim = Smootherstep(depth1, 0, depth0 + 0.01 * _RimThreshold);

    return rim * _RimColor * half4(mainlight.color, 1) * mainlight.shadowAttenuation;
}

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////



// Used in Standard (Physically Based) shader
Varyings ToonHairPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    half3 viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);
    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
    output.viewDirWS = viewDirWS;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
#endif
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    output.tangentWS = tangentWS;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
    output.viewDirTS = viewDirTS;
#endif

    OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    output.positionWS = vertexInput.positionWS;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

// Used in Standard (Physically Based) shader
half4 ToonHairPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

#if defined(_PARALLAXMAP)
#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS = input.viewDirTS;
#else
    half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, input.viewDirWS);
#endif
    ApplyPerPixelDisplacement(viewDirTS, input.uv);
#endif

    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);
    //CXZ Begin
    #if defined(SHADOWS_SHADOWMASK) && defined(LIGHTMAP_ON)
        half4 shadowMask = inputData.shadowMask;
    #elif !defined (LIGHTMAP_ON)
        half4 shadowMask = unity_ProbesOcclusion;
    #else
        half4 shadowMask = half4(1, 1, 1, 1);
    #endif
    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, shadowMask);
    //CXZ End
    //向量准备
    half ndotl = saturate(dot(inputData.normalWS, mainLight.direction));

    half4 albedo = SAMPLE_TEXTURE2D(_DiffuseMap, sampler_DiffuseMap, input.uv.xy);
    half faceShadow = SAMPLE_TEXTURE2D(_FaceShadowMap, sampler_FaceShadowMap, input.uv.xy);
    half4 mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv.xy);

    #if _FACE
        half4 diffuse = Toon_Face(mainLight, ndotl, albedo, mask.b, input);
        half4 specular = 0;
    #else
        half4 diffuse = Toon_Diffuse(mainLight, ndotl, albedo, mask.b);
        half4 specular = Toon_Specular(mainLight, input, mask.g, mask.r);
    #endif
    #if _ANISOTROPY
        specular.rgb += Toon_Anisotropy(mainLight, input, mask.g);
    #endif

    half3 col = (diffuse + specular).rgb;
    #if _SCREENSPACERIM
        col += Toon_Rim(input, mainLight);
    #endif
    return half4(col, 1);

    half4 color = UniversalFragmentPBR(inputData, surfaceData);

    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(color.a, _Surface);

    return color;
}

Varyings ToonClothPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    half3 viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);
    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
    output.viewDirWS = viewDirWS;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
#endif
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    output.tangentWS = tangentWS;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
    output.viewDirTS = viewDirTS;
#endif

    OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    output.positionWS = vertexInput.positionWS;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

// Used in Standard (Physically Based) shader
half4 ToonClothPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

#if defined(_PARALLAXMAP)
#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS = input.viewDirTS;
#else
    half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, input.viewDirWS);
#endif
    ApplyPerPixelDisplacement(viewDirTS, input.uv);
#endif

    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);
    //CXZ Begin
    #if defined(SHADOWS_SHADOWMASK) && defined(LIGHTMAP_ON)
        half4 shadowMask = inputData.shadowMask;
    #elif !defined (LIGHTMAP_ON)
        half4 shadowMask = unity_ProbesOcclusion;
    #else
        half4 shadowMask = half4(1, 1, 1, 1);
    #endif
    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, shadowMask);
    //CXZ End
    //向量准备
    half ndotl = saturate(dot(inputData.normalWS, mainLight.direction));

    half4 albedo = SAMPLE_TEXTURE2D(_DiffuseMap, sampler_DiffuseMap, input.uv.xy);
    half metal = SAMPLE_TEXTURE2D(_MetalMap, sampler_MetalMap, input.uv.xy);
    half faceShadow = SAMPLE_TEXTURE2D(_FaceShadowMap, sampler_FaceShadowMap, input.uv.xy);
    half4 mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv.xy);

    half4 diffuse = Toon_Diffuse(mainLight, ndotl, albedo, mask.b);
    half4 specular = Toon_Specular(mainLight, input, mask.g, mask.r);

    half3 col = (diffuse + specular).rgb;
    #if _SCREENSPACERIM
        col += Toon_Rim(input, mainLight);
    #endif
    return half4(col, 1);

    
    half4 color = UniversalFragmentPBR(inputData, surfaceData);

    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(color.a, _Surface);

    return color;
}

//法线外扩和中心坐标外扩的顶点着色器
Varyings OutlinePassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    half3 viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);
    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
    output.viewDirWS = viewDirWS;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
#endif
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    output.tangentWS = tangentWS;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
    output.viewDirTS = viewDirTS;
#endif

    OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    output.positionWS = vertexInput.positionWS;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif
    
    
    output.positionCS = Toon_Outline(input, vertexInput.positionCS);
    return output;
}

//法线外扩和中心坐标外扩的片元着色器
half4 OutlinePassFragment(Varyings input) : SV_Target
{

    return 0;
}

#endif
