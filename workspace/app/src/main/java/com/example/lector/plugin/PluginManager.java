package com.example.lector.plugin;

import android.content.Context;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.InputStream;
import java.lang.reflect.Constructor;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.ServiceLoader;

/**
 * Менеджер плагинов (модов) Lector.
 *
 * Порядок загрузки:
 *  1. Встроенные — из assets/plugins.json (класс уже в APK, инстанциация по имени).
 *  2. ServiceLoader — все LectorPlugin на classpath (gradle-модули).
 *  3. Внешние .jar/.dex — из filesDir/plugins_ext/ (динамическая загрузка).
 *
 * После загрузки каждый плагин инициализируется в изолированной песочнице
 * filesDir/plugins/<id>/ и регистрирует свои возможности в PluginRegistry.
 */
public class PluginManager {

    private static final String TAG = "PluginManager";
    public static final int PLUGIN_API_VERSION = 1;

    private static PluginManager instance;

    private final Context appContext;
    private final File pluginsRootDir;
    private final File externalPluginsDir;
    private final Map<String, LectorPlugin> loaded = new LinkedHashMap<>();
    private final List<String> loadErrors = new ArrayList<>();

    private PluginRegistry registry;
    private EventBus eventBus;
    private final Map<String, PluginContext> contexts = new LinkedHashMap<>();

    private PluginManager(Context context) {
        this.appContext = context.getApplicationContext();
        this.pluginsRootDir = new File(appContext.getFilesDir(), "plugins");
        this.externalPluginsDir = new File(appContext.getFilesDir(), "plugins_ext");
        if (!pluginsRootDir.exists()) pluginsRootDir.mkdirs();
        if (!externalPluginsDir.exists()) externalPluginsDir.mkdirs();
    }

    public static synchronized PluginManager getInstance(Context context) {
        if (instance == null) instance = new PluginManager(context);
        return instance;
    }

    /** Полная инициализация: реестр + шина + загрузка всех источников. */
    public synchronized void initialize() {
        if (registry != null) return; // уже инициализирован
        registry = new PluginRegistry();
        eventBus = new EventBus();

        loadBuiltinManifest();
        loadFromServiceLoader();
        loadExternalArchives();

        for (LectorPlugin plugin : loaded.values()) {
            try {
                File dir = new File(pluginsRootDir, plugin.getId());
                if (!dir.exists()) dir.mkdirs();
                PluginContext ctx = new PluginContext(appContext, dir);
                contexts.put(plugin.getId(), ctx);
                plugin.onInit(ctx);
                plugin.onRegister(registry);
                // Автоматическая регистрация декларативных возможностей плагина
                for (BlockHandler h : plugin.getBlockHandlers()) registry.registerBlockHandler(h);
                for (FormattingCommand c : plugin.getFormattingCommands()) registry.registerFormattingCommand(c);
                for (PostProcessor p : plugin.getPostProcessors()) registry.registerPostProcessor(p);
                for (Exporter ex : plugin.getExporters()) registry.registerExporter(ex);
                for (ToolbarAction ta : plugin.getToolbarActions()) registry.registerToolbarAction(ta);
                plugin.subscribe(eventBus);
                Log.i(TAG, "Плагин загружен: " + plugin.getId() + " v" + plugin.getVersion());
            } catch (Exception e) {
                loadErrors.add(plugin.getId() + ": init failed — " + e.getMessage());
                Log.e(TAG, "Plugin init failed: " + plugin.getId(), e);
            }
        }
    }

    public PluginRegistry getRegistry() { initialize(); return registry; }
    public EventBus getEventBus() { initialize(); return eventBus; }

    /** Контекст загруженного плагина (песочница + данные); null если плагин не загружен. */
    public PluginContext getContextFor(String pluginId) {
        initialize();
        return contexts.get(pluginId);
    }

    /**
     * Выполнить плагинное действие тулбара с контекстом его владельца-плагина.
     * Ядро вызывает это при нажатии на плагинную кнопку в редакторе.
     */
    public void runToolbarAction(ToolbarAction action, com.example.lector.models.Lecture lecture) {
        if (action == null) return;
        // Контекст того плагина, который зарегистрировал действие; иначе — общий
        PluginContext ctx = null;
        for (Map.Entry<String, PluginContext> e : contexts.entrySet()) {
            LectorPlugin p = loaded.get(e.getKey());
            if (p != null && p.getToolbarActions().contains(action)) { ctx = e.getValue(); break; }
        }
        if (ctx == null) ctx = new PluginContext(appContext, pluginsRootDir);
        try {
            action.onClick(lecture, ctx);
        } catch (Exception e) {
            Log.e(TAG, "Toolbar action failed: " + action.getLabel(), e);
        }
    }

    public List<LectorPlugin> getLoadedPlugins() {
        initialize();
        return new ArrayList<>(loaded.values());
    }
    public List<String> getLoadErrors() { initialize(); return new ArrayList<>(loadErrors); }

    public LectorPlugin getPlugin(String id) {
        initialize();
        return loaded.get(id);
    }

    /** Отключить и выгрузить плагин (удаление его данных не выполняется). */
    public synchronized void unload(String pluginId) {
        LectorPlugin p = loaded.remove(pluginId);
        if (p != null) {
            try { p.onShutdown(); } catch (Exception ignored) {}
            Log.i(TAG, "Плагин выгружен: " + pluginId);
        }
    }

    // ===== Источник 1: встроенный манифест assets/plugins.json =====

    private void loadBuiltinManifest() {
        try (InputStream is = appContext.getAssets().open("plugins.json")) {
            String raw = readAll(is);
            JSONObject manifest = new JSONObject(raw);
            JSONArray plugins = manifest.optJSONArray("plugins");
            if (plugins == null) return;
            for (int i = 0; i < plugins.length(); i++) {
                JSONObject entry = plugins.optJSONObject(i);
                if (entry == null || !entry.optBoolean("enabled", true)) continue;
                String className = entry.optString("class", null);
                if (className == null) continue;
                try {
                    Class<?> clazz = Class.forName(className);
                    Constructor<?> ctor = clazz.getConstructor();
                    registerInstance((LectorPlugin) ctor.newInstance());
                } catch (Exception e) {
                    loadErrors.add(className + ": " + e.getMessage());
                    Log.w(TAG, "Builtin plugin not found: " + className);
                }
            }
        } catch (Exception e) {
            Log.d(TAG, "No builtin plugins.json: " + e.getMessage());
        }
    }

    // ===== Источник 2: Java ServiceLoader =====

    private void loadFromServiceLoader() {
        try {
            ServiceLoader<LectorPlugin> loader = ServiceLoader.load(
                LectorPlugin.class, LectorPlugin.class.getClassLoader());
            for (LectorPlugin p : loader) {
                registerInstance(p);
            }
        } catch (Throwable t) {
            loadErrors.add("ServiceLoader: " + t.getMessage());
        }
    }

    // ===== Источник 3: внешние jar/dex в filesDir/plugins_ext =====

    private void loadExternalArchives() {
        File[] files = externalPluginsDir.listFiles();
        if (files == null) return;
        for (File f : files) {
            String name = f.getName().toLowerCase();
            if (!name.endsWith(".jar") && !name.endsWith(".dex")) continue;
            loadArchive(f);
        }
    }

    private void loadArchive(File archive) {
        dalvik.system.DexClassLoader cl = null;
        try {
            File optimizedDir = new File(appContext.getCacheDir(), "plugin_opt");
            if (!optimizedDir.exists()) optimizedDir.mkdirs();
            cl = new dalvik.system.DexClassLoader(
                archive.getAbsolutePath(),
                optimizedDir.getAbsolutePath(),
                null,
                appContext.getClassLoader());

            // Манифест плагина внутри архива: assets/plugin.json или корневой plugin.json
            String manifestJson = readEntryFromArchive(archive);
            String className = null;
            if (manifestJson != null) {
                className = new JSONObject(manifestJson).optString("class", null);
            }
            if (className == null) {
                loadErrors.add(archive.getName() + ": no plugin.json/class");
                return;
            }
            Class<?> clazz = cl.loadClass(className);
            Object instance = clazz.getConstructor().newInstance();
            if (instance instanceof LectorPlugin) {
                registerInstance((LectorPlugin) instance);
            } else {
                loadErrors.add(archive.getName() + ": does not implement LectorPlugin");
            }
        } catch (Throwable t) {
            loadErrors.add(archive.getName() + ": " + t.getMessage());
            Log.w(TAG, "Failed to load plugin archive " + archive, t);
        }
    }

    private String readEntryFromArchive(File archive) {
        try (java.util.zip.ZipFile zip = new java.util.zip.ZipFile(archive)) {
            java.util.zip.ZipEntry entry = zip.getEntry("assets/plugin.json");
            if (entry == null) entry = zip.getEntry("plugin.json");
            if (entry == null) return null;
            try (InputStream is = zip.getInputStream(entry)) {
                return readAll(is);
            }
        } catch (Exception e) {
            return null;
        }
    }

    // ===== Утилиты =====

    private void registerInstance(LectorPlugin plugin) {
        if (plugin == null || plugin.getId() == null) return;
        if (loaded.containsKey(plugin.getId())) return;
        if (plugin.getApiVersion() > PLUGIN_API_VERSION) {
            loadErrors.add(plugin.getId() + ": requires API " + plugin.getApiVersion()
                + ", core has " + PLUGIN_API_VERSION);
            return;
        }
        loaded.put(plugin.getId(), plugin);
    }

    private static String readAll(InputStream is) throws java.io.IOException {
        java.io.ByteArrayOutputStream bos = new java.io.ByteArrayOutputStream();
        byte[] buf = new byte[4096];
        int n;
        while ((n = is.read(buf)) > 0) bos.write(buf, 0, n);
        return bos.toString("UTF-8");
    }

    /** Директория для установки внешних модов (пользовательский импорт). */
    public File getExternalPluginsDir() { return externalPluginsDir; }
}
