struct MATERIAL
{
	float4					m_cAmbient;
	float4					m_cDiffuse;
	float4					m_cSpecular; //a = power
	float4					m_cEmissive;
};

cbuffer cbCameraInfo : register(b1)
{
	matrix					gmtxView : packoffset(c0);
	matrix					gmtxProjection : packoffset(c4);
	float3					gvCameraPosition : packoffset(c8);
};

cbuffer cbGameObjectInfo : register(b2)
{
	matrix					gmtxGameObject : packoffset(c0);
	MATERIAL				gMaterial : packoffset(c4);
};

cbuffer cbWaterWave : register(b5)
{
	float					gfWaterWave : packoffset(c0);
};

cbuffer cbTessFactor : register(b6)
{
	float2					gfTessFactor : packoffset(c0); //x : tessfactor , y : tessinsidefactor
};


cbuffer cbBlurFactor : register(b7)
{
	int					giBlurFactor : packoffset(c0); 
};


Texture2D gtxtTexture : register(t0);
SamplerState gSamplerState : register(s0);
SamplerState gClampSamplerState : register(s1);

#include "Light.hlsl"


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
struct VS_DIFFUSED_INPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
};

struct VS_DIFFUSED_OUTPUT
{
	float4 position : SV_POSITION;
	float4 color : COLOR;
};

VS_DIFFUSED_OUTPUT VSDiffused(VS_DIFFUSED_INPUT input)
{
	VS_DIFFUSED_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.color = input.color;

	return(output);
}

float4 PSDiffused(VS_DIFFUSED_OUTPUT input) : SV_TARGET
{
	return(input.color);
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//

//#define _WITH_VERTEX_LIGHTING

struct VS_LIGHTING_INPUT
{
	float3 position : POSITION;
	float3 normal : NORMAL;
	float2 uv : TEXCOORD;
};

struct VS_LIGHTING_OUTPUT
{
	float4 position : SV_POSITION;
	float3 positionW : POSITION;
	float3 normalW : NORMAL;
#ifdef _WITH_VERTEX_LIGHTING
	float4 color : COLOR;
#endif
	float2 uv : TEXCOORD;
};

VS_LIGHTING_OUTPUT VSLighting(VS_LIGHTING_INPUT input)
{
	VS_LIGHTING_OUTPUT output;

	output.normalW = mul(input.normal, (float3x3)gmtxGameObject);
	output.positionW = (float3)mul(float4(input.position, 1.0f), gmtxGameObject);
	output.position = mul(mul(float4(output.positionW, 1.0f), gmtxView), gmtxProjection);
#ifdef _WITH_VERTEX_LIGHTING
	output.normalW = normalize(output.normalW);
	output.color = Lighting(output.positionW, output.normalW);
#endif
	output.uv = input.uv;
	return(output);
}

float4 PSLighting(VS_LIGHTING_OUTPUT input) : SV_TARGET
{
#ifdef _WITH_VERTEX_LIGHTING
	return(input.color);
#else
	input.normalW = normalize(input.normalW);
	float4 color = Lighting(input.positionW, input.normalW);
	float4 cColorTex = gtxtTexture.Sample(gSamplerState, input.uv);
	color = lerp(color, cColorTex, 0.6f);
	return(color);
#endif
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
Texture2D gtxtTerrainBaseTexture : register(t1);
Texture2D gtxtTerrainDetailTexture : register(t2);

struct VS_TERRAIN_INPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

struct VS_TERRAIN_OUTPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

VS_TERRAIN_OUTPUT VSTerrain(VS_TERRAIN_INPUT input)
{
	VS_TERRAIN_OUTPUT output;

	output.color = input.color;
	if (input.position.y > 170) {
		float gradation = (input.position.y - 170) / 100.f;
		output.color += gradation * float4(1, 1, 1, 1);
	}
	output.position = input.position;
	output.uv0 = input.uv0;
	output.uv1 = input.uv1;

	return(output);
}

struct HS_TERRAIN_TESSELLATION_CONSTANT
{
	float fTessEdges[4] : SV_TessFactor;
	float fTessInsides[2] : SV_InsideTessFactor;
};

struct HS_TERRAIN_TESSELLATION_OUTPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

struct DS_TERRAIN_TESSELLATION_OUTPUT
{
	float4 position : SV_POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

void BernsteinCoeffcient5x5(float t, out float fBernstein[5])
{
	float tInv = 1.0f - t;
	fBernstein[0] = tInv * tInv * tInv * tInv;
	fBernstein[1] = 4.0f * t * tInv * tInv * tInv;
	fBernstein[2] = 6.0f * t * t * tInv * tInv;
	fBernstein[3] = 4.0f * t * t * t * tInv;
	fBernstein[4] = t * t * t * t;
}

float3 CubicBezierSum5x5(OutputPatch<HS_TERRAIN_TESSELLATION_OUTPUT, 25> patch, float uB[5], float vB[5])
{
	float3 f3Sum = float3(0.0f, 0.0f, 0.0f);
	f3Sum = vB[0] * (uB[0] * patch[0].position + uB[1] * patch[1].position + uB[2] * patch[2].position + uB[3] * patch[3].position + uB[4] * patch[4].position);
	f3Sum += vB[1] * (uB[0] * patch[5].position + uB[1] * patch[6].position + uB[2] * patch[7].position + uB[3] * patch[8].position + uB[4] * patch[9].position);
	f3Sum += vB[2] * (uB[0] * patch[10].position + uB[1] * patch[11].position + uB[2] * patch[12].position + uB[3] * patch[13].position + uB[4] * patch[14].position);
	f3Sum += vB[3] * (uB[0] * patch[15].position + uB[1] * patch[16].position + uB[2] * patch[17].position + uB[3] * patch[18].position + uB[4] * patch[19].position);
	f3Sum += vB[4] * (uB[0] * patch[20].position + uB[1] * patch[21].position + uB[2] * patch[22].position + uB[3] * patch[23].position + uB[4] * patch[24].position);
	return(f3Sum);
}

[domain("quad")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(25)]
[patchconstantfunc("VSTerrainTessellationConstant")]
[maxtessfactor(64.0f)]
HS_TERRAIN_TESSELLATION_OUTPUT HSTerrainTessellation(InputPatch<VS_TERRAIN_OUTPUT, 25> input, uint i : SV_OutputControlPointID)
{
	HS_TERRAIN_TESSELLATION_OUTPUT output;

	output.position = input[i].position;
	output.color = input[i].color;
	output.uv0 = input[i].uv0;
	output.uv1 = input[i].uv1;


	return(output);
}

HS_TERRAIN_TESSELLATION_CONSTANT VSTerrainTessellationConstant(InputPatch<VS_TERRAIN_OUTPUT, 25> input)
{

	float3 vCenter;
	for (int i = 0; i < 25; i++)
		vCenter += input[i].position;
	vCenter = vCenter / 25.f;

	float fDistanceToCamera = distance(vCenter, gvCameraPosition);

	float fTessFactor = (1.f/fDistanceToCamera)*100.f * gfTessFactor.x;
	HS_TERRAIN_TESSELLATION_CONSTANT output;

	output.fTessEdges[0] =fTessFactor;
	output.fTessEdges[1] =fTessFactor;
	output.fTessEdges[2] =fTessFactor;
	output.fTessEdges[3] =fTessFactor;
	output.fTessInsides[0] = fTessFactor;
	output.fTessInsides[1] = fTessFactor;

	return(output);
}

[domain("quad")]
[earlydepthstencil ]
DS_TERRAIN_TESSELLATION_OUTPUT DSTerrainTessellation(HS_TERRAIN_TESSELLATION_CONSTANT patchConstant, float2 uv : SV_DomainLocation, OutputPatch<HS_TERRAIN_TESSELLATION_OUTPUT, 25> patch)
{
	DS_TERRAIN_TESSELLATION_OUTPUT output = (DS_TERRAIN_TESSELLATION_OUTPUT)0;

	float uB[5], vB[5];
	BernsteinCoeffcient5x5(uv.x, uB);
	BernsteinCoeffcient5x5(uv.y, vB);

	output.color = lerp(lerp(patch[0].color, patch[4].color, uv.x), lerp(patch[20].color, patch[24].color, uv.x), uv.y);
	output.uv0 = lerp(lerp(patch[0].uv0, patch[4].uv0, uv.x), lerp(patch[20].uv0, patch[24].uv0, uv.x), uv.y);
	output.uv1 = lerp(lerp(patch[0].uv1, patch[4].uv1, uv.x), lerp(patch[20].uv1, patch[24].uv1, uv.x), uv.y);

	float3 position = CubicBezierSum5x5(patch, uB, vB);
	matrix mtxWorldViewProjection = mul(mul(gmtxGameObject, gmtxView), gmtxProjection);
	output.position = mul(float4(position, 1.0f), mtxWorldViewProjection);

	return(output);
}


float4 PSTerrain(DS_TERRAIN_TESSELLATION_OUTPUT input) : SV_TARGET
{
	//float4 cBaseTexColor = float4(0.2f,0.2f,0.2f,1.f);
	float4 cBaseTexColor = gtxtTerrainBaseTexture.Sample(gSamplerState, input.uv0);
	float4 cDetailTexColor = gtxtTerrainDetailTexture.Sample(gSamplerState, input.uv1);
	float4 cColor = input.color * saturate((cBaseTexColor * 0.5f) + (cDetailTexColor * 0.5f));
	return(cColor);
}


Texture2D gtxWaterTexture : register(t3);

struct VS_WATER_INPUT
{
	float3 position : POSITION;
	float2 uv0 : TEXCOORD0;
};

struct VS_WATER_OUTPUT
{
	float4 position : SV_POSITION;
	float3 positionW : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float3 normal : NORMAL;
};

VS_WATER_OUTPUT VSWater(VS_WATER_INPUT input)
{
	VS_WATER_OUTPUT output;
	output.color = float4(0, 0, 0, 0);
	output.positionW = (float3)mul(float4(input.position, 1.0f), gmtxGameObject);
	output.positionW.y += cos(output.positionW.x + gfWaterWave)*2;

	output.normal = normalize(float3(output.positionW.x, output.positionW.y, 0));
	output.normal = mul(output.normal, (float3x3)gmtxGameObject);
	
	float gradation = 0.1f * (35 - output.positionW.y);
	if (gradation < 0) gradation = 0;
	output.color.w += gradation;
	
	output.position = mul(mul(float4(output.positionW, 1.0f), gmtxView), gmtxProjection);
	
	output.uv0 = input.uv0;


	return(output);
}

float4 PSWater(VS_WATER_OUTPUT input) : SV_TARGET
{
	float4 cColor = gtxWaterTexture.Sample(gSamplerState, input.uv0) * 0.5f;
	cColor.a = 0.4f;
	cColor += input.color;

	//lighting
	//float4 cColor2 = Lighting(input.positionW, input.normal);
	//cColor2 = lerp(cColor, cColor2, 0.6f);

	return(cColor);
}

struct VS_TEXTURED_INPUT
{
	float3 position : POSITION;
	float2 uv : TEXCOORD;
};

struct VS_TEXTURED_OUTPUT
{
	float4 position : SV_POSITION;
	float2 uv : TEXCOORD;
};

VS_TEXTURED_OUTPUT VSTextured(VS_TEXTURED_INPUT input)
{
	VS_TEXTURED_OUTPUT output;
	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);

	output.uv = input.uv;

	return(output);
}

VS_TEXTURED_OUTPUT VSUI(VS_TEXTURED_INPUT input)  /// ��������
{
	VS_TEXTURED_OUTPUT output;
	output.position =float4(input.position, 1.0f);
	output.uv = input.uv;

	return(output);
}
///////////////////////////////////////////////////

Texture2D gtxtBillboardTexture : register(t5);

struct VS_BILLBOARD_INSTANCING_INPUT
{
	float3 instancePosition : INSTANCEPOSITION;
	float2 billboardInfo : BILLBOARDINFO; //(cx, cy, type, texture)
};

struct VS_BILLBOARD_INSTANCING_OUTPUT
{
	float3 position : POSITION;
	float2 billboardInfo : BILLBOARDINFO; //(cx, cy, type, texture)
};

struct GS_OUT {
	float4 posH : SV_POSITION;
	float3 posW : POSITION;
	float2 uv : TEXCOORD;
	uint primID : SV_PrimitiveID; 
};

VS_BILLBOARD_INSTANCING_OUTPUT VSBillboardInstancing(VS_BILLBOARD_INSTANCING_INPUT input)
{
	VS_BILLBOARD_INSTANCING_OUTPUT output;

	output.position = input.instancePosition;
	output.billboardInfo = input.billboardInfo;

	return(output);
}

[earlydepthstencil ]
[maxvertexcount(4)]
void GSBillboardInstancing(point VS_BILLBOARD_INSTANCING_OUTPUT input[1], uint primID : SV_PrimitiveID, inout TriangleStream <GS_OUT> outStream)
{
	float3 vLook = normalize(gvCameraPosition - input[0].position);
	float3 vUp = float3(0.0f, 1.0f, 0.0f);
	float3 vRight = normalize(cross(vUp, vLook));

	float fHalfW = input[0].billboardInfo.x ;
	float fHalfH = input[0].billboardInfo.y ;

	float4 pVertices[4];
	pVertices[0] = float4(input[0].position + fHalfW * vRight - fHalfH * vUp, 1.0f);
	pVertices[1] = float4(input[0].position + fHalfW * vRight + fHalfH * vUp, 1.0f);
	pVertices[2] = float4(input[0].position - fHalfW * vRight - fHalfH * vUp, 1.0f);
	pVertices[3] = float4(input[0].position - fHalfW * vRight + fHalfH * vUp, 1.0f);

	float2 pUVs[4] = { float2(0,1),float2(0,0),float2(1,1),float2(1,0) };

	GS_OUT output;
	for (int i = 0; i < 4; i++) {
		output.posW = pVertices[i];
		output.posH = mul(mul(pVertices[i], gmtxView),gmtxProjection);
		output.uv = pUVs[i];
		output.primID = primID;
		outStream.Append(output);
	}

}

float4 PSBillboardInstancing(GS_OUT input) : SV_TARGET
{
	float4 cColor = gtxtBillboardTexture.Sample(gClampSamplerState, input.uv);

	return(cColor);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
float4 PSTextured(VS_TEXTURED_OUTPUT input) : SV_TARGET
{
	//float4 cColor = gtxtTexture.SampleLevel(gSamplerState, input.uv, 0);
		float4 cColor = gtxtTexture.Sample(gSamplerState, input.uv);
		//clip(cColor.a - 0.3f);

		return(cColor);
}


float4 PSUI(VS_TEXTURED_OUTPUT input) : SV_TARGET
{
	float4 cColor = gtxtTexture.Sample(gSamplerState, input.uv);
		//float4 cColor = float4(1,1,1,1);

		return(cColor);
}
/////////////////////////////////////////////  SKYBOX
struct VS_SKYBOX_INPUT
{
	float3 position : POSITION;
};

struct VS_SKYBOX_OUTPUT
{
	float3	position : POSITION;
	float4	positionH : SV_POSITION;
};

VS_SKYBOX_OUTPUT VSSkyBox(VS_SKYBOX_INPUT input)
{
	VS_SKYBOX_OUTPUT output;

	output.positionH = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);

	output.position = input.position;

	return(output);
}


TextureCube gtxtSkyboxTexture : register(t4);
SamplerState gssClamp : register(s1);

float4 PSSkyBox(VS_SKYBOX_OUTPUT input) : SV_TARGET
{
	float4 cColor = gtxtSkyboxTexture.Sample(gClampSamplerState, input.position);

	return(cColor);
}


Texture2D<float4> gtxtScene : register(t6);

float4 VSPostProcessing(uint nVertexID : SV_VertexID) : SV_POSITION
{
	if (nVertexID == 0) return(float4(-1.0f, +1.0f, 0.0f, 1.0f));
	if (nVertexID == 1) return(float4(+1.0f, +1.0f, 0.0f, 1.0f));
	if (nVertexID == 2) return(float4(+1.0f, -1.0f, 0.0f, 1.0f));
	if (nVertexID == 3) return(float4(-1.0f, +1.0f, 0.0f, 1.0f));
	if (nVertexID == 4) return(float4(+1.0f, -1.0f, 0.0f, 1.0f));
	if (nVertexID == 5) return(float4(-1.0f, -1.0f, 0.0f, 1.0f));

	return(float4(0, 0, 0, 0));
}

float4 PSPostProcessing(float4 position : SV_POSITION) : SV_Target
{
	float4 cColor = float4(0,0,0,0);
	int nWidth, nHeight, nMipLevels;
	gtxtScene.GetDimensions(0, nWidth, nHeight, nMipLevels);
	int2 loc2 = int2(position.x, position.y );
	cColor = gtxtScene[loc2];
	cColor += (gtxtScene[int2(loc2.x + giBlurFactor, loc2.y)] + gtxtScene[int2(loc2.x - giBlurFactor, loc2.y)]);
	cColor += (gtxtScene[int2(loc2.x, loc2.y+ giBlurFactor)] + gtxtScene[int2(loc2.x, loc2.y - giBlurFactor)]);
	return (cColor*0.2f);
}

float4 PSPostProcessingByMonochrome(float4 position : SV_POSITION) : SV_Target
{
	float4 cColor = gtxtScene[int2(position.xy)];
	float fIntensity = cColor.r * 0.3f + cColor.g * 0.59f + cColor.b * 0.11f;
	cColor = float4(fIntensity, fIntensity, fIntensity, 1.0f);

	return(cColor);
}

