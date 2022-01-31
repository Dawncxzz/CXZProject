Shader "Custom/Unlit/CustomSilhouette1"
{
    Properties
    {
        [HDR]_OutlineColor ("TintColor", Color) = (1,1,1,1)//
        _OutlineWidth ("OutlineWidth", Range(0.001, 0.1)) = 0.001
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

    v2gf Offset(v2gf o) {
  	    v2gf extruded = o;
  	    float3 vNormal = mul((float3x3)UNITY_MATRIX_IT_MV, o.g_normal.xyz);
  	    float2 vOffset = mul(UNITY_MATRIX_P, float4(vNormal.xy, 0, 1));
  	    vOffset.xy = normalize(vOffset.xy);
  	    extruded.pos = TransformObjectToHClip(o.g_vertex);
  	    extruded.pos.xy += vOffset.xy * extruded.pos.w * _OutlineWidth;
  	    //extruded.pos.xy += vOffset.xy * _OutlineWidth;
  	    return extruded;
    }
      
    #define APPEND(o) outputStream.Append(o);
    [maxvertexcount(18)]
    void geom(triangle v2gf inputTriangle[3], inout TriangleStream<v2gf> outputStream) {
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
     
    half4 frag(v2gf o) : SV_Target{
        Light mainLight = GetMainLight();
  	    return _OutlineColor * half4(mainLight.color, 1);
    }
    ENDHLSL
      
    SubShader
    {
  	    Tags{"RenderType" = "Opaque"}
       
        Pass
        {

            Name "Outline"
               
   	        Cull Off
            ZWrite On

            Stencil//模板测试中参考值不等于1的像素将会通过，进行外轮廓描边。
            {
   	            Ref 1 
    	        Comp NotEqual
   	        }
   	   
   	        HLSLPROGRAM
    	        #pragma vertex vert
    	        #pragma geometry geom
                #pragma fragment frag
   	        ENDHLSL
   	    }
    }

}
