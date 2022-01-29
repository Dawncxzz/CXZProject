Shader "Custom/Unlit/CustomSilhouette0"
{
    Properties
    {
        [HDR]_OutlineColor ("TintColor", Color) = (1,1,1,1)//
        _OutlineWidth ("OutlineWidth", Range(0.001, 0.01)) = 0.001
    }

    HLSLINCLUDE
    
    #pragma target 4.0
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    
    half4 _OutlineColor;
    float _OutlineWidth;

    struct a2v 
    {
  	    float4 vertex : POSITION;
        float3 normal : NORMAL;
    };
    struct v2gf 
    {
        float4 g_vertex : TEXCOORD0;
        float3 g_normal : TEXCOORD1;
        float4 pos : SV_POSITION;
    };
 
    v2gf vert(a2v v) {
  	    v2gf o;
 	    o.g_vertex = v.vertex;
  	    o.g_normal = v.normal;
  	    o.pos = TransformObjectToHClip(v.vertex);
  	    return o;
    }
     
    half4 Null(v2gf o) : SV_Target
    {
  	    return float4(1.0, 0.0, 0.0, 1.0);
    }
    ENDHLSL
      
    SubShader
    {
  	    Tags{"RenderType" = "Opaque"}
  	
  	    Pass
  	    {
            name "Forward"
   	        Tags { "LightMode" = "UniversalForward" }
   	   
   	        //ColorMask 0//不输出颜色
   	        Cull Off
   	        ZWrite Off//不进行深度写入。
   	        Stencil//模板测试总是通过，并且写入参考值1
   	        {
    	        Ref 1
    	        Comp always
                Pass replace
            }
           
            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment Null
   	        ENDHLSL
        }
    }
}
