package com.example.lector.plugin;

import android.content.Context;

import com.example.lector.models.Lecture;

import java.io.File;
import java.util.Collections;
import java.util.List;

/**
 * Окружение, передаваемое плагину при инициализации.
 * Даёт плагину доступ к данным лекции и изолированной песочнице на диске,
 * но НЕ даёт прямого доступа к внутренностям приложения.
 */
public class PluginContext {

    private final Context appContext;
    private final File pluginDataDir;
    private final PluginSettings settings;
    private Lecture lecture;

    public PluginContext(Context appContext, File pluginDataDir) {
        this.appContext = appContext;
        this.pluginDataDir = pluginDataDir;
        String id = pluginDataDir != null ? pluginDataDir.getName() : "core";
        this.settings = new PluginSettings(appContext, id);
    }

    /** Android-контекст приложения (для ресурсов, файловых операций). */
    public Context getAppContext() { return appContext; }

    /** Изолированная директория данных плагина: filesDir/plugins/<id>. */
    public File getPluginDataDir() { return pluginDataDir; }

    /** Типизированные настройки мода (v1.4), объявленные через LectorPlugin.getSettings(). */
    public PluginSettings getSettings() { return settings; }

    /** Текущая редактируемая лекция (может быть null вне редактора). */
    public Lecture getLecture() { return lecture; }

    public void setLecture(Lecture lecture) { this.lecture = lecture; }

    /**
     * Разрешённые расширения аудиофайлов. Плагин может сузить список,
     * переопределив {@link LectorPlugin#getSupportedAudioExtensions()}.
     */
    public List<String> getAllowedAudioExtensions() {
        return Collections.singletonList(".m4a");
    }
}
