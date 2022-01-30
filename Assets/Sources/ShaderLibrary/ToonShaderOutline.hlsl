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

//几何描边结构体
struct a2v 
{
    float4 vertex : POSITION;    
    float3 color : COLOR0;
    float3 normal : NORMAL;
};

struct v2gf 
{
  float4 g_vertex : TEXCOORD0;
  float3 g_normal : TEXCOORD1;
  float3 v_color : TEXCOORD2;
  float4 pos : SV_POSITION;
};

//几何描边的顶点着色器
v2gf OutlinePassVertex(a2v v) 
{
  v2gf o;
  o.g_vertex = v.vertex;
  o.g_normal = v.normal;
  o.v_color = v.color;
  o.pos = TransformObjectToHClip(v.vertex);
  return o;
 }

 //几何描边的片元着色器的中间过度（计算专用）
v2gf Offset(v2gf o) 
{
  v2gf extruded = o;
  float3 vNormal = mul((float3x3)UNITY_MATRIX_IT_MV, o.g_normal.xyz);
  float2 vOffset = mul(UNITY_MATRIX_P, float4(vNormal.xy, 0, 1));
  vOffset.xy = normalize(vOffset.xy);
  extruded.pos = TransformObjectToHClip(o.g_vertex);
  //extruded.pos.xy += vOffset.xy  * _OutlineOffset * o.v_color.xy * 0.01;
  extruded.pos.xy += vOffset.xy  * _OutlineOffset * o.v_color.xy * 0.01 * extruded.pos.w;
  extruded.pos.z -= _OutlineBias * 0.002;
  return extruded;
}

//几何描边的顶点着色器
#define APPEND(o)\
 outputStream.Append(o);
 
[maxvertexcount(18)]
 void geom(triangle v2gf inputTriangle[3], inout TriangleStream<v2gf> outputStream) 
 {
  v2gf extrusionTriangle0 = Offset(inputTriangle[0]);
  v2gf extrusionTriangle1 = Offset(inputTriangle[1]);
  v2gf extrusionTriangle2 = Offset(inputTriangle[2]);
  
  APPEND(inputTriangle[0]);
  APPEND(extrusionTriangle0);
  APPEND(inputTriangle[1]);
  
  APPEND(extrusionTriangle0);
  APPEND(extrusionTriangle1);
  APPEND(inputTriangle[1]);
  
  APPEND(inputTriangle[1]);
  APPEND(extrusionTriangle1);
  APPEND(extrusionTriangle2);
  
  APPEND(inputTriangle[1]);
  APPEND(extrusionTriangle2);
  APPEND(inputTriangle[2]);
  
  APPEND(inputTriangle[2]);
  APPEND(extrusionTriangle2);
  APPEND(inputTriangle[0]);
  
  APPEND(extrusionTriangle2);
  APPEND(extrusionTriangle0);
  APPEND(inputTriangle[0]);
}

half4 OutlinePassFragment(v2gf input) : SV_Target
{
    Light mainLight = GetMainLight();
    half lambert = saturate(dot(mainLight.direction, mul(input.g_normal, UNITY_MATRIX_I_M)));
  	return half4(lambert * mainLight.color * mainLight.shadowAttenuation * mainLight.distanceAttenuation * _OutlineColor, 1);
}

#endif
