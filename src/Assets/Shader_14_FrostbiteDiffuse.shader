Shader "Custom/Shader_14_FrostbiteDiffuse"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        //[MainTexture] _BaseMap("Base Map", 2D) = "white"
         _AmbientRate("Ambient Rate",Range(0,1))=0.2
        _SpecularPower("Specular Power",Range(0.001,300)) = 80
        _SpecularIntensity("Specular Intensity",Range(0,1))=0.3
        _FresneIO("FresneIO",Range(0,0.99999))=0.8
        _Roughness("Roughness",Range(0.00001,1))=0.4
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

         Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal:NORMAL;
                float4 tangent:TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normal:NORMAL;
                float4 tangent:TANGENT;
                float3 position:TEXCOORDO;
            };

            CBUFFER_START(UnityPerMaterial)
               half4 _BaseColor;
               half _Fresnel0;
                half _Roughness;
            CBUFFER_END

           
            Varyings vert(Attributes IN)
            {
               Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normal=TransformObjectToWorldNormal(IN.normal);
                OUT.tangent=float4(TransformObjectToWorldNormal(float3(IN.tangent.xyz)).xyz,IN.tangent.w);
                OUT.position=TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half Fresnel(half f0,half f90,float co)
            {
                return f0+(f90-f0)*pow(1-co,5);
            }

            half3 Fr_DisneyDiffuse(half3 albedo,half LdotN,half VdotN,half LdotH,half linearRoughness)
            {
                half energyBias=lerp(0.0,0.5,linearRoughness);
                half energyFactor=lerp(1.0,1.0/1.51,linearRoughness);
                half Fd90=energyBias+2.0*LdotH*LdotH*linearRoughness;
                half FL=Fresnel(1,Fd90,LdotN);
                half FV=Fresnel(1,Fd90,VdotN);
                return (albedo*FL*FV*energyFactor);
            }


            half4 frag(Varyings IN) : SV_Target
            {
                Light light=GetMainLight();
                half3 normal=normalize(IN.normal);
                half3 view_direction=normalize(TransformViewToWorld(float3(0,0,0))-IN.position);
                float3 half_vector=normalize(light.direction+view_direction);

                half VdotN=max(0.00001,dot(view_direction,normal));
                half LdotN=max(0.0,dot(light.direction,normal));
                half HdotN=max(0.0,dot(half_vector,normal));
                half LdotH=max(0.0,dot(half_vector,light.direction));

                

                half3 color=light.color*LdotN
                *Fr_DisneyDiffuse(_BaseColor,LdotN,VdotN,LdotH,_Roughness*_Roughness)/PI;

                return half4(color,1);
            }
            ENDHLSL
        }
    }
}
