using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace UnityEditor.Rendering.Universal.ShaderGUI
{
    internal class ToonHairShader : BaseShaderGUI
    {
        private LitGUI.LitProperties litProperties;
        private LitDetailGUI.LitProperties litDetailProperties;
        private SavedBool m_DetailInputsFoldout;

        //CXZ
        MaterialProperty _DiffuseMap = null;
        MaterialProperty _DiffuseColor = null;
        MaterialProperty _SpecularColor = null;
        MaterialProperty _Gloss = null;
        MaterialProperty _MaskMap = null;
        MaterialProperty _MetalMap = null;
        MaterialProperty _FaceShadowMap = null;
        MaterialProperty _RampMap = null;
        MaterialProperty _RampRange = null;
        MaterialProperty _ShadowColor = null;
        MaterialProperty _LerpMax = null;

        public override void OnOpenGUI(Material material, MaterialEditor materialEditor)
        {
            base.OnOpenGUI(material, materialEditor);
            m_DetailInputsFoldout = new SavedBool($"{headerStateKey}.DetailInputsFoldout", true);
        }

        public override void DrawAdditionalFoldouts(Material material)
        {
            m_DetailInputsFoldout.value = EditorGUILayout.BeginFoldoutHeaderGroup(m_DetailInputsFoldout.value, LitDetailGUI.Styles.detailInputs);
            if (m_DetailInputsFoldout.value)
            {
                LitDetailGUI.DoDetailArea(litDetailProperties, materialEditor);
                EditorGUILayout.Space();
            }
            EditorGUILayout.EndFoldoutHeaderGroup();
        }

        // collect properties from the material properties
        public override void FindProperties(MaterialProperty[] properties)
        {
            base.FindProperties(properties);
            litProperties = new LitGUI.LitProperties(properties);
            litDetailProperties = new LitDetailGUI.LitProperties(properties);

            _DiffuseMap = FindProperty("_DiffuseMap", properties);
            _DiffuseColor = FindProperty("_DiffuseColor", properties);
            _SpecularColor = FindProperty("_SpecularColor", properties);
            _Gloss = FindProperty("_Gloss", properties);
            _MaskMap = FindProperty("_MaskMap", properties);
            _MetalMap = FindProperty("_MetalMap", properties);
            _FaceShadowMap = FindProperty("_FaceShadowMap", properties);
            _RampMap = FindProperty("_RampMap", properties);
            _RampRange = FindProperty("_RampRange", properties);
            _ShadowColor = FindProperty("_ShadowColor", properties);
            _LerpMax = FindProperty("_LerpMax", properties);

        }

        // material changed check
        public override void MaterialChanged(Material material)
        {
            if (material == null)
                throw new ArgumentNullException("material");

            SetMaterialKeywords(material, LitGUI.SetMaterialKeywords, LitDetailGUI.SetMaterialKeywords);
        }

        // material main surface options
        public override void DrawSurfaceOptions(Material material)
        {
            if (material == null)
                throw new ArgumentNullException("material");

            // Use default labelWidth
            EditorGUIUtility.labelWidth = 0f;

            // Detect any changes to the material
            EditorGUI.BeginChangeCheck();
            if (litProperties.workflowMode != null)
            {
                DoPopup(LitGUI.Styles.workflowModeText, litProperties.workflowMode, Enum.GetNames(typeof(LitGUI.WorkflowMode)));
            }
            if (EditorGUI.EndChangeCheck())
            {
                foreach (var obj in blendModeProp.targets)
                    MaterialChanged((Material)obj);
            }
            base.DrawSurfaceOptions(material);
        }

        // material main surface inputs
        public override void DrawSurfaceInputs(Material material)
        {
            //base.DrawSurfaceInputs(material);
            //LitGUI.Inputs(litProperties, materialEditor, material);
            bool _FACE = material.IsKeywordEnabled("_FACE");
            EditorGUI.BeginChangeCheck();
            _FACE = EditorGUILayout.Toggle("����", _FACE);
            if (_FACE)
            {
                EditorGUI.indentLevel++;
                materialEditor.TexturePropertySingleLine(new GUIContent("FaceShadow Map"), _FaceShadowMap);
                materialEditor.ShaderProperty(_LerpMax, "��Ӱ��ʵ");
                EditorGUI.indentLevel--;
            }
            materialEditor.TexturePropertySingleLine(new GUIContent("��������ͼ"), _DiffuseMap, _DiffuseColor);
            materialEditor.ShaderProperty(_SpecularColor, "�߹���ɫ");
            EditorGUILayout.LabelField("��������:(R:�⻬�� G:�߹�  B:������ A:����)");
            materialEditor.TexturePropertySingleLine(new GUIContent("����ͼ"), _MaskMap);
            materialEditor.ShaderProperty(_Gloss, "�⻬��");
            materialEditor.TexturePropertySingleLine(new GUIContent("������ͼ"), _MetalMap);
            materialEditor.TexturePropertySingleLine(new GUIContent("������ͼ"), _RampMap);
            materialEditor.ShaderProperty(_RampRange, "���䷶Χ");
            materialEditor.ShaderProperty(_ShadowColor, "��Ӱ��ɫ");
            DrawEmissionProperties(material, true);
            DrawTileOffset(materialEditor, baseMapProp);
            if (EditorGUI.EndChangeCheck())
            {
                CoreUtils.SetKeyword(material, "_FACE", _FACE);
            }
        } 

        // material main advanced options
        public override void DrawAdvancedOptions(Material material)
        {
            if (litProperties.reflections != null && litProperties.highlights != null)
            {
                EditorGUI.BeginChangeCheck();
                materialEditor.ShaderProperty(litProperties.highlights, LitGUI.Styles.highlightsText);
                materialEditor.ShaderProperty(litProperties.reflections, LitGUI.Styles.reflectionsText);
                if(EditorGUI.EndChangeCheck())
                {
                    MaterialChanged(material);
                }
            }

            base.DrawAdvancedOptions(material);
        }

        public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
        {
            if (material == null)
                throw new ArgumentNullException("material");

            // _Emission property is lost after assigning Standard shader to the material
            // thus transfer it before assigning the new shader
            if (material.HasProperty("_Emission"))
            {
                material.SetColor("_EmissionColor", material.GetColor("_Emission"));
            }

            base.AssignNewShaderToMaterial(material, oldShader, newShader);

            if (oldShader == null || !oldShader.name.Contains("Legacy Shaders/"))
            {
                SetupMaterialBlendMode(material);
                return;
            }

            SurfaceType surfaceType = SurfaceType.Opaque;
            BlendMode blendMode = BlendMode.Alpha;
            if (oldShader.name.Contains("/Transparent/Cutout/"))
            {
                surfaceType = SurfaceType.Opaque;
                material.SetFloat("_AlphaClip", 1);
            }
            else if (oldShader.name.Contains("/Transparent/"))
            {
                // NOTE: legacy shaders did not provide physically based transparency
                // therefore Fade mode
                surfaceType = SurfaceType.Transparent;
                blendMode = BlendMode.Alpha;
            }
            material.SetFloat("_Surface", (float)surfaceType);
            material.SetFloat("_Blend", (float)blendMode);

            if (oldShader.name.Equals("Standard (Specular setup)"))
            {
                material.SetFloat("_WorkflowMode", (float)LitGUI.WorkflowMode.Specular);
                Texture texture = material.GetTexture("_SpecGlossMap");
                if (texture != null)
                    material.SetTexture("_MetallicSpecGlossMap", texture);
            }
            else
            {
                material.SetFloat("_WorkflowMode", (float)LitGUI.WorkflowMode.Metallic);
                Texture texture = material.GetTexture("_MetallicGlossMap");
                if (texture != null)
                    material.SetTexture("_MetallicSpecGlossMap", texture);
            }

            MaterialChanged(material);
        }
    }
}
