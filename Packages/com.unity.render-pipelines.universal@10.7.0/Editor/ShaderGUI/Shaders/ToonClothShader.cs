using System;
using UnityEngine;
using UnityEngine.Rendering;

#if UNITY_EDITOR
namespace UnityEditor.Rendering.Universal.ShaderGUI
{
    internal class ToonClothShader : BaseShaderGUI
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
        MaterialProperty _RampMap = null;
        MaterialProperty _RampRange = null;
        MaterialProperty _ShadowColor = null;
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
            _RampMap = FindProperty("_RampMap", properties);
            _RampRange = FindProperty("_RampRange", properties);
            _ShadowColor = FindProperty("_ShadowColor", properties);
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
            bool _SKIN = material.IsKeywordEnabled("_SKIN");

            EditorGUI.BeginChangeCheck();
            _SKIN = EditorGUILayout.Toggle("∆§∑Ù", _SKIN);
            bool _MATCAP = material.IsKeywordEnabled("_MATCAP");
            _MATCAP = EditorGUILayout.Toggle("matcap", _MATCAP);
            if (_MATCAP)
            {
                EditorGUI.indentLevel++;
                materialEditor.TexturePropertySingleLine(new GUIContent("matcapÃ˘Õº"), _MetalMap);
                EditorGUI.indentLevel--;
            }
            bool _SCREENSPACERIM = material.IsKeywordEnabled("_SCREENSPACERIM");
            _SCREENSPACERIM = EditorGUILayout.Toggle("∆¡ƒª±ﬂ‘µπ‚", _SCREENSPACERIM);
            if (_SCREENSPACERIM)
            {
                EditorGUI.indentLevel++;
                materialEditor.ShaderProperty(_RimColor, "±ﬂ‘µ—’…´");
                materialEditor.ShaderProperty(_RimOffset, "±ﬂ‘µ∆´“∆");
                materialEditor.ShaderProperty(_RimThreshold, "±ﬂ‘µ…Ó∂»„–÷µ");
                EditorGUI.indentLevel--;
            }
            materialEditor.TexturePropertySingleLine(new GUIContent("¬˛∑¥…‰Ã˘Õº"), _DiffuseMap, _DiffuseColor);
            materialEditor.ShaderProperty(_SpecularColor, "∏ﬂπ‚—’…´");
            EditorGUILayout.LabelField("’⁄’÷œÍ«È:(R:π‚ª¨∂» G:∏ﬂπ‚  B:¬˛∑¥…‰ A:Ω•±‰)");
            materialEditor.TexturePropertySingleLine(new GUIContent("’⁄’÷Õº"), _MaskMap);
            materialEditor.ShaderProperty(_Gloss, "π‚ª¨∂»");
            materialEditor.TexturePropertySingleLine(new GUIContent("Ω•±‰Ã˘Õº"), _RampMap);
            materialEditor.ShaderProperty(_RampRange, "Ω•±‰∑∂Œß");
            materialEditor.ShaderProperty(_ShadowColor, "“ı”∞—’…´");
            materialEditor.ShaderProperty(_OutlineOffset, "√Ë±ﬂøÌ∂»");
            materialEditor.ShaderProperty(_OutlineBias, "√Ë±ﬂ…Ó∂»");
            materialEditor.ShaderProperty(_OutlineColor, "√Ë±ﬂ—’…´");

            if (EditorGUI.EndChangeCheck())
            {
                CoreUtils.SetKeyword(material, "_SKIN", _SKIN);
                CoreUtils.SetKeyword(material, "_MATCAP", _MATCAP);
                CoreUtils.SetKeyword(material, "_SCREENSPACERIM", _SCREENSPACERIM);
            }

            DrawEmissionProperties(material, true);
            DrawTileOffset(materialEditor, baseMapProp);
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