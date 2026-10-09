package com.example.lector.plugin;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * Типизированные настройки мода (API v1.4), хранятся ядром в изолированном
 * SharedPreferences "plugin_settings.<id>" — мод не трогает чужие данные.
 *
 * Использование: плагин объявляет дескрипторы настроек через
 * {@link LectorPlugin#getSettings()}, а значения читает из PluginContext:
 * <pre>
 *   int w = context.getSettings().getInt("width", 3);
 * </pre>
 */
public class PluginSettings {

    /** Дескриптор одной настройки для автогенерации UI на экране «Моды». */
    public static class SettingDescriptor {
        public enum Type { BOOLEAN, INT, STRING, CHOICE }

        public final String key;
        public final String label;
        public final Type type;
        public final Object defaultValue;
        /** Только для CHOICE: список вариантов. */
        public final List<String> choices;

        private SettingDescriptor(String key, String label, Type type,
                                  Object defaultValue, List<String> choices) {
            this.key = key;
            this.label = label;
            this.type = type;
            this.defaultValue = defaultValue;
            this.choices = choices != null ? choices : new ArrayList<>();
        }

        public static SettingDescriptor bool(String key, String label, boolean def) {
            return new SettingDescriptor(key, label, Type.BOOLEAN, def, null);
        }

        public static SettingDescriptor intVal(String key, String label, int def) {
            return new SettingDescriptor(key, label, Type.INT, def, null);
        }

        public static SettingDescriptor string(String key, String label, String def) {
            return new SettingDescriptor(key, label, Type.STRING, def, null);
        }

        public static SettingDescriptor choice(String key, String label, String def,
                                               List<String> choices) {
            return new SettingDescriptor(key, label, Type.CHOICE, def, choices);
        }
    }

    private final SharedPreferences prefs;

    public PluginSettings(Context appContext, String pluginId) {
        this.prefs = appContext.getSharedPreferences("plugin_settings." + pluginId,
            Context.MODE_PRIVATE);
    }

    public boolean getBoolean(String key, boolean def) {
        return prefs.getBoolean(key, def);
    }

    public int getInt(String key, int def) {
        return prefs.getInt(key, def);
    }

    public String getString(String key, String def) {
        return prefs.getString(key, def);
    }

    public void putBoolean(String key, boolean value) {
        prefs.edit().putBoolean(key, value).apply();
    }

    public void putInt(String key, int value) {
        prefs.edit().putInt(key, value).apply();
    }

    public void putString(String key, String value) {
        prefs.edit().putString(key, value).apply();
    }

    /** Сброс всех настроек мода к значениям по умолчанию из дескрипторов. */
    public void resetToDefaults(List<SettingDescriptor> descriptors) {
        SharedPreferences.Editor e = prefs.edit();
        for (SettingDescriptor d : descriptors) {
            switch (d.type) {
                case BOOLEAN: e.putBoolean(d.key, (Boolean) d.defaultValue); break;
                case INT:     e.putInt(d.key, (Integer) d.defaultValue); break;
                default:      e.putString(d.key, String.valueOf(d.defaultValue)); break;
            }
        }
        e.apply();
    }

    /** JSON-снимок текущих значений (для отладки/экспорта конфигурации). */
    public JSONObject snapshot() {
        JSONObject json = new JSONObject();
        try {
            for (String key : prefs.getAll().keySet()) {
                Object v = prefs.getAll().get(key);
                json.put(key, JSONObject.wrap(v));
            }
        } catch (Exception ignored) { }
        return json;
    }

    /** Массив дескрипторов — утилита для плагинов, собирающих статический список. */
    public static JSONArray descriptorsToJson(List<SettingDescriptor> list) {
        JSONArray arr = new JSONArray();
        for (SettingDescriptor d : list) {
            try {
                JSONObject o = new JSONObject();
                o.put("key", d.key);
                o.put("label", d.label);
                o.put("type", d.type.name());
                o.put("default", JSONObject.wrap(d.defaultValue));
                if (!d.choices.isEmpty()) o.put("choices", new JSONArray(d.choices));
                arr.put(o);
            } catch (Exception ignored) { }
        }
        return arr;
    }
}
