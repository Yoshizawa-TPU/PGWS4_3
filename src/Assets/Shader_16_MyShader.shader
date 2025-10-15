Shader "Custom/Shader_15_PBR"
{
    Properties
   {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _SpecularColor("Specular Color",Color)=(1,1,1,1)
        _Emission("Emission",Color)=(0,0,0,0)
        _Fresnel0("Fresnel0",Range(0,0.99999))=0.8
        _Roughness("Roughness",Range(0.0001,1))=0.4
        _Metallic("Metallic",Range(0,1))=0.6
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
               half4 _SpecularColor;
               half4 _Emission;
               half _Fresnel0;
               half _Roughness;
               half _Metallic;
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

            half FresnelReflectanceAverageDielectric(float co,float f0,float f90)
            {
                co=min(0.9999,max(0.000001,co));

                float root_f0=sqrt(f0);
                float root_f90=sqrt(f90);
                float n=(root_f90+root_f0)/(root_f90-root_f0);
                float n2=n*n;

                float si2=1-co*co;
                float nb=sqrt(n2-si2);
                float bn=nb/n2;

                float r_s=(co-nb)/(co+nb);
                float r_p=(co-bn)/(co+bn);
                return 0.5*f90*(r_s*r_s+r_p*r_p);
            }

            half Fresnel(half f0,half f90,float co)
            {
                return f0+(f90-f0)*pow(1-co,5);
            }

            half3 OrenNayarDiffuse(half3 albedo, half3 normal, half3 lightDir, half3 viewDir, half roughness)
            {
            float sigma = roughness * 1.57;
            float sigma2 = sigma * sigma;

            float A = 1.0 - (0.5 * sigma2 / (sigma2 + 0.33));
            float B = 0.45 * sigma2 / (sigma2 + 0.09);

            float NdotL = max(0.0, dot(normal, lightDir));
            float NdotV = max(0.0, dot(normal, viewDir));

            float3 lightProj = normalize(lightDir - normal * NdotL);
            float3 viewProj = normalize(viewDir - normal * NdotV);

            float cosPhiDiff = max(0.0, dot(lightProj, viewProj));

            float alpha = max(acos(NdotL), acos(NdotV));
            float beta  = min(acos(NdotL), acos(NdotV));

            float C = sin(alpha) * tan(beta);

            float orenNayar = NdotL * (A + B * cosPhiDiff * C);
            return albedo * orenNayar / PI;
            }

            float V_SmithGGXCorrelated(float NdotL,float NdotV,float alphaG2)
            {

                float Lambda_GGXV=NdotL*sqrt((-NdotV*alphaG2+NdotV)*NdotV+alphaG2);
                float Lambda_GGXL=NdotV*sqrt((-NdotV*alphaG2+NdotL)*NdotL+alphaG2);
                return 0.5f/(Lambda_GGXV+Lambda_GGXL);
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
                half VdotH=max(0.0,dot(half_vector,view_direction));

                half alpha=_Roughness*_Roughness;
                half3 diffuse = OrenNayarDiffuse(_BaseColor, normal, light.direction, view_direction, _Roughness);

                half alpha2 = _Roughness * _Roughness;
                float D = alpha2 / (PI * pow(HdotN * HdotN * (alpha2 - 1.0) + 1.0, 2.0));
                half G = V_SmithGGXCorrelated(LdotN, VdotN, alpha2);
                half F = Fresnel(_Fresnel0, 1, VdotH);

                half3 specular = saturate(_SpecularColor * D * G * F / (4 * LdotN * VdotN));
                half3 color = light.color * LdotN * (diffuse + specular * _Metallic);
 
                color += _Emission;
                return half4(color,1);
            }
            ENDHLSL
        }
   }
}