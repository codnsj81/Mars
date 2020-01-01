//-----------------------------------------------------------------------------
// File: Scene.h
//-----------------------------------------------------------------------------

#pragma once

#include "Shader.h"
#include "Player.h"
#include <list>

#define MAX_LIGHTS			16 

#define POINT_LIGHT			1
#define SPOT_LIGHT			2
#define DIRECTIONAL_LIGHT	3

struct LIGHT
{
	XMFLOAT4				m_xmf4Ambient;
	XMFLOAT4				m_xmf4Diffuse;
	XMFLOAT4				m_xmf4Specular;
	XMFLOAT3				m_xmf3Position;
	float 					m_fFalloff;
	XMFLOAT3				m_xmf3Direction;
	float 					m_fTheta; //cos(m_fTheta)
	XMFLOAT3				m_xmf3Attenuation;
	float					m_fPhi; //cos(m_fPhi)
	bool					m_bEnable;
	int						m_nType;
	float					m_fRange;
	float					padding;
};

struct LIGHTS
{
	LIGHT					m_pLights[MAX_LIGHTS];
	XMFLOAT4				m_xmf4GlobalAmbient;
	int						m_nLights;
};

class CScene
{
public:
	CScene() {}
	~CScene() {}

	virtual void BuildObjects(ID3D12Device* pd3dDevice, ID3D12GraphicsCommandList* pd3dCommandList) {}
	virtual void ReleaseObjects() {}

	virtual bool OnProcessingMouseMessage(HWND hWnd, UINT nMessageID, WPARAM wParam, LPARAM lParam) { return true; }
	virtual bool OnProcessingKeyboardMessage(HWND hWnd, UINT nMessageID, WPARAM wParam, LPARAM lParam) { return true; }

	virtual void CreateShaderVariables(ID3D12Device* pd3dDevice, ID3D12GraphicsCommandList* pd3dCommandList) {}
	virtual void UpdateShaderVariables(ID3D12GraphicsCommandList* pd3dCommandList) {}
	virtual void ReleaseShaderVariables() {}

	virtual ID3D12RootSignature* CreateGraphicsRootSignature(ID3D12Device* pd3dDevice) { return NULL; }
	ID3D12RootSignature* GetGraphicsRootSignature() { return(m_pd3dGraphicsRootSignature);}

	virtual bool ProcessInput(UCHAR* pKeysBuffer) { return false; }
	virtual void AnimateObjects(float fTimeElapsed, ID3D12GraphicsCommandList* pd3dCommandList) {}
	virtual void Render(ID3D12GraphicsCommandList* pd3dCommandList, D3D12_CPU_DESCRIPTOR_HANDLE dsvHandle, CCamera* pCamera = NULL) {}
	virtual void ReleaseUploadBuffers() {}
protected:

	ID3D12RootSignature* m_pd3dGraphicsRootSignature = NULL;

};


class CLobbyScene: public CScene
{
public:
	CLobbyScene() {}
	~CLobbyScene() {}

	virtual void ReleaseObjects();
	virtual void BuildObjects(ID3D12Device* pd3dDevice, ID3D12GraphicsCommandList* pd3dCommandList);
	virtual ID3D12RootSignature* CreateGraphicsRootSignature(ID3D12Device* pd3dDevice);

	virtual bool ProcessInput(UCHAR* pKeysBuffer) { return false; }
	virtual void Render(ID3D12GraphicsCommandList* pd3dCommandList, D3D12_CPU_DESCRIPTOR_HANDLE dsvHandle, CCamera* pCamera = NULL);
	virtual void ReleaseUploadBuffers() {}

private:
	CUI* m_pTitle = NULL;

};


class CGameScene :  public CScene
{
public:
	CGameScene();
	~CGameScene();

	virtual void BuildObjects(ID3D12Device *pd3dDevice, ID3D12GraphicsCommandList *pd3dCommandList);
	
	virtual bool OnProcessingMouseMessage(HWND hWnd, UINT nMessageID, WPARAM wParam, LPARAM lParam);
	virtual bool OnProcessingKeyboardMessage(HWND hWnd, UINT nMessageID, WPARAM wParam, LPARAM lParam);

	void BuildDefaultLightsAndMaterials();
	virtual void ReleaseObjects();

	bool BulletCollision(CBullet* pBullet);
	virtual void AnimateObjects(float fTimeElapsed, ID3D12GraphicsCommandList* pd3dCommandList);

	virtual bool ProcessInput(UCHAR* pKeysBuffer);
	virtual void Render(ID3D12GraphicsCommandList* pd3dCommandList, D3D12_CPU_DESCRIPTOR_HANDLE dsvHandle, CCamera* pCamera = NULL);

	virtual void CreateShaderVariables(ID3D12Device* pd3dDevice, ID3D12GraphicsCommandList* pd3dCommandList);
	virtual void UpdateShaderVariables(ID3D12GraphicsCommandList* pd3dCommandList);
	virtual void ReleaseShaderVariables();

	virtual ID3D12RootSignature* CreateGraphicsRootSignature(ID3D12Device* pd3dDevice);
	
	void SetTessellationMode(ID3D12GraphicsCommandList* pd3dCommandList);
	void CreateBullet();
	CPlayer* GetPlayer() { return m_pPlayer; }
	CHeightMapTerrain* GetTerrain() { return  m_pTerrain; }
	void ReleaseUploadBuffers();
	void SetShowBillboards() { m_bShowBillboards = (!m_bShowBillboards); }

	CPlayer						*m_pPlayer = NULL;

public:
	bool						m_bShowBillboards = true;
	CSkyBox*					m_pSkyBox = NULL;
	CGameObject*				 m_pBulletModel = NULL;
	CVillainObject					**m_ppVillains = NULL;
	list<CBullet*>			 *m_pBulletList = NULL;
	int							m_nGameObjects = 0;

	LIGHT						*m_pLights = NULL;
	int							m_nLights = 0;

	CBillboardObjectsShader* m_pBillboardShader = NULL;
	CHeightMapTerrain* m_pTerrain = NULL;
	CWater*			 m_pWater = NULL;

	XMFLOAT4					m_xmf4GlobalAmbient;

	ID3D12Resource				*m_pd3dcbLights = NULL;
	LIGHTS						*m_pcbMappedLights = NULL;

	float						m_fElapsedTime = 0.0f;
	
};
