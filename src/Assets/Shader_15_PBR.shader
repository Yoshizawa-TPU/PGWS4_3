Shader "Custom/Shader_15_PBR"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        //[MainTexture] _BaseMap("Base Map", 2D) = "white"
         _AmbientRate("Ambient Rate",Range(0,1))=0.2
         _Emission("Emission",Color)=(0,0,0,0)
        _SpecularPower("Specular Power",Range(0.001,300)) = 80
        _SpecularColor("SpecularColor",Color)=(0,0,0,0)
        _SpecularIntensity("Specular Intensity",Range(0,1))=0.3
        _FresneIO("FresneIO",Range(0,0.99999))=0.8
        _Roughness("Roughness",Range(0.00001,1))=0.4
         _Metallic("Metallic",Range(0,1)) = 0.5
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
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normal : NORMAL;
                float3 position : TEXCOORDO;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _SpecularColor;
                half4 _Emission;
                float4 _BaseMap_ST;
                half _AmbientRate;
                half _SpecularPower;
                half _SpecularIntensity;
                half _FresneIO;
                half _Roughness;
                half _Metallic;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                OUT.position = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half Fresnel(half f0,half f90,half co)
            {
                return f0 + (f90-f0)* pow(1-co,5);
            }

            half3 Fr_DisneyDiffuse(half3 albedo,half LdotN,half VdotN, half LdotH, half LinearRoughness)
            {
                half energyBias = lerp(0.0,0.5,LinearRoughness);
                half energyFactor = lerp(1.0,1.0/1.51,LinearRoughness);
                half Fd90 = energyBias +2.0*LdotH*LdotH*LinearRoughness;
                half FL = Fresnel(1,Fd90,LdotN);
                half FV = Fresnel(1,Fd90,VdotN);
                return (albedo *FL*FV*energyFactor);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();              
                half3 normal = normalize(IN.normal);
                half3 view_direction = normalize(TransformObjectToWorld(float3(0,0,0))-IN.normal);
                float3 half_vector = normalize(view_direction + light.direction);

                half VdotN = max(0.00001,dot(view_direction,normal));
                half LdotN = max(0.00001,dot(light.direction,normal));
                half HdotN = max(0.00001,dot(half_vector,normal));
                 half LdotH = max(0,dot(half_vector,light.direction));
                half VdotH = max(0,dot(half_vector,view_direction));

                half alpha2 = _Roughness *_Roughness*_Roughness*_Roughness;
                float denom = HdotN* HdotN*(alpha2 - 1.0)+1.0;
                float D = alpha2 /(PI *denom*denom);
                half G = min(1,1/(VdotN+sqrt(alpha2 + (1.0-alpha2)* VdotN*VdotN)) / LdotN+sqrt(alpha2 + (1.0-alpha2)*LdotN*LdotN));
                half F = _FresneIO + (1-_FresneIO) * pow(1-VdotH,5);
                half3 brdf = _BaseColor * D*G*F/(4*LdotN*VdotN);


                half3 color = light.color *LdotN*Fr_DisneyDiffuse(_BaseColor,LdotN,VdotN,LdotH,_Roughness*_Roughness) / PI;
                return half4(color,1);
            }
            ENDHLSL
        }
    }
}
