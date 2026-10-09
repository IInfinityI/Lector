package com.example.lector.plugin;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class PluginSettingsTest {

    @Test
    public void descriptorsAreTypedAndCarryDefaults() {
        PluginSettings.SettingDescriptor b = PluginSettings.SettingDescriptor
            .bool("enabled", "Включён", true);
        PluginSettings.SettingDescriptor i = PluginSettings.SettingDescriptor
            .intVal("border_width", "Толщина", 2);
        PluginSettings.SettingDescriptor s = PluginSettings.SettingDescriptor
            .string("prefix", "Префикс", "#");
        PluginSettings.SettingDescriptor c = PluginSettings.SettingDescriptor
            .choice("color", "Цвет", "yellow",
                java.util.Arrays.asList("yellow", "green", "blue"));

        assertEquals(PluginSettings.SettingDescriptor.Type.BOOLEAN, b.type);
        assertEquals(Boolean.TRUE, b.defaultValue);
        assertEquals(PluginSettings.SettingDescriptor.Type.INT, i.type);
        assertEquals(Integer.valueOf(2), i.defaultValue);
        assertEquals(PluginSettings.SettingDescriptor.Type.STRING, s.type);
        assertEquals(PluginSettings.SettingDescriptor.Type.CHOICE, c.type);
        assertEquals(3, c.choices.size());
        assertEquals("color", c.key);
    }

    @Test
    public void defaultGetSettingsIsEmptyForPluginsWithoutConfig() {
        LectorPlugin bare = new LectorPlugin() {
            @Override public String getId() { return "bare"; }
            @Override public String getName() { return "Bare"; }
            @Override public String getDescription() { return ""; }
            @Override public void onInit(PluginContext context) { }
            @Override public void onRegister(PluginRegistry registry) { }
        };
        assertTrue(bare.getSettings().isEmpty());
    }

    @Test
    public void descriptorsToJsonSerializesAllFields() throws org.json.JSONException {
        java.util.List<PluginSettings.SettingDescriptor> list = java.util.Arrays.asList(
            PluginSettings.SettingDescriptor.intVal("border_width", "Толщина", 2),
            PluginSettings.SettingDescriptor.choice("color", "Цвет", "yellow",
                java.util.Arrays.asList("yellow", "green")));
        org.json.JSONArray arr = PluginSettings.descriptorsToJson(list);
        assertEquals(2, arr.length());
        assertEquals("border_width", arr.getJSONObject(0).getString("key"));
        assertEquals("INT", arr.getJSONObject(0).getString("type"));
        assertEquals(2, arr.getJSONObject(1).getJSONArray("choices").length());
    }

    @Test
    public void highlighterDeclaresBorderWidthSetting() {
        // Демо-мод v1.4 обязан декларировать хотя бы одну настройку —
        // иначе панель конфигурации на экране «Моды» не появится.
        com.example.lector.plugin.builtin.HighlighterPlugin hl =
            new com.example.lector.plugin.builtin.HighlighterPlugin();
        java.util.List<PluginSettings.SettingDescriptor> settings = hl.getSettings();
        assertEquals(1, settings.size());
        assertEquals("border_width", settings.get(0).key);
        assertEquals(PluginSettings.SettingDescriptor.Type.INT, settings.get(0).type);
        assertEquals(Integer.valueOf(2), settings.get(0).defaultValue);
    }
}
