using System;
using UnityEngine;
using UnityEngine.Rendering;

#if UNITY_EDITOR
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
        MaterialProperty _OutlineOffset = null;
        MaterialProperty _OutlineBias = null;
        MaterialProperty _OutlineColor = null; 
        MaterialProperty _RimColor = null; 
        MaterialProperty _RimOffset = null; 
        MaterialProperty _RimThreshold = null; 

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
            _OutlineOffset = FindProperty("_OutlineOffset", properties);
            _OutlineBias = FindProperty("_OutlineBias", properties);
            _OutlineColor = FindProperty("_OutlineColor", properties);
            _RimColor = FindProperty("_RimColor", properties);
            _RimOffset = FindProperty("_RimOffset", properties);
            _RimThreshold = FindProperty("_RimThreshold", properties);

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
            _FACE = EditorGUILayout.Toggle("脸部", _FACE);
            if (_FACE)
            {
                EditorGUI.indentLevel++;
                materialEditor.TexturePropertySingleLine(new GUIContent("FaceShadow Map"), _FaceShadowMap);
                materialEditor.ShaderProperty(_LerpMax, "阴影虚实");
                EditorGUI.indentLevel--;
            }
            bool _MATCAP = material.IsKeywordEnabled("_MATCAP");
            _MATCAP = EditorGUILayout.Toggle("matcap", _MATCAP); 
            if (_MATCAP)
            {
                EditorGUI.indentLevel++;
                materialEditor.TexturePropertySingleLine(new GUIContent("matcap贴图"), _MetalMap);
                EditorGUI.indentLevel--;
            }
            bool _ANISOTROPY = material.IsKeywordEnabled("_ANISOTROPY");
            _ANISOTROPY = EditorGUILayout.Toggle("各向异性", _ANISOTROPY);
            bool _SCREENSPACERIM = material.IsKeywordEnabled("_SCREENSPACERIM");
            _SCREENSPACERIM = EditorGUILayout.Toggle("屏幕边缘光", _SCREENSPACERIM);
            if (_SCREENSPACERIM)
            {
                EditorGUI.indentLevel++;
                materialEditor.ShaderProperty(_RimColor, "边缘颜色");
                materialEditor.ShaderProperty(_RimOffset, "边缘偏移");
                materialEditor.ShaderProperty(_RimThreshold, "边缘深度阈值");
                EditorGUI.indentLevel--;
            }
            materialEditor.TexturePropertySingleLine(new GUIContent("漫反射贴图"), _DiffuseMap, _DiffuseColor);
            materialEditor.ShaderProperty(_SpecularColor, "高光颜色"); 
            EditorGUILayout.LabelField("遮罩详情:(R:光滑度 G:高光  B:漫反射 A:渐变)");
            materialEditor.TexturePropertySingleLine(new GUIContent("遮罩图"), _MaskMap);
            materialEditor.ShaderProperty(_Gloss, "光滑度");
            materialEditor.TexturePropertySingleLine(new GUIContent("渐变贴图"), _RampMap);
            materialEditor.ShaderProperty(_RampRange, "渐变范围");
            materialEditor.ShaderProperty(_ShadowColor, "阴影颜色");
            materialEditor.ShaderProperty(_OutlineOffset, "描边宽度");
            materialEditor.ShaderProperty(_OutlineBias, "描边深度");
            materialEditor.ShaderProperty(_OutlineColor, "描边颜色");
            DrawEmissionProperties(material, true);
            DrawTileOffset(materialEditor, baseMapProp);
            if (EditorGUI.EndChangeCheck())
            {
                CoreUtils.SetKeyword(material, "_FACE", _FACE);
                CoreUtils.SetKeyword(material, "_MATCAP", _MATCAP);
                CoreUtils.SetKeyword(material, "_ANISOTROPY", _ANISOTROPY);
                CoreUtils.SetKeyword(material, "_SCREENSPACERIM", _SCREENSPACERIM);
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
                if (EditorGUI.EndChangeCheck())
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
#endif