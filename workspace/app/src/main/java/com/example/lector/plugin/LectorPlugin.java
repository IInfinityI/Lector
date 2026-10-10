package com.example.lector.plugin;

import java.util.Collections;
import java.util.List;

/**
 * Главный интерфейс мода (плагина) Lector.
 *
 * Плагин — это расширяющая функциональность единица, как мод в игре:
 * он регистрирует новые типы блоков контента и/или обработчики транскрипции,
 * не изменяя код ядра приложения.
 *
 * Способы подключения:
 *  1. Встроенные плагины — объявлены в assets/plugins.json, класс лежит в APK.
 *  2. Java ServiceLoader — плагин добавлен как gradle-модуль с META-INF/services.
 *  3. Динамическая загрузка DEX/JAR из filesDir/plugins_ext/ (привилегированные режимы).
 */
public interface LectorPlugin {

    /** Уникальный идентификатор, обратно-доменный стиль: "com.example.myplugin". */
    String getId();

    /** Человекочитаемое название (отображается в разделе «Моды»). */
    String getName();

    /** Описание для пользователя. */
    String getDescription();

    /** Версия плагина (SemVer). */
    default String getVersion() { return "1.0.0"; }

    /** Минимальная совместимая версия API плагинов. */
    default int getApiVersion() { return 1; }

    /** Инициализация плагина. Вызывается один раз после загрузки. */
    void onInit(PluginContext context);

    /** Регистрация возможностей плагина в реестре ядра. */
    void onRegister(PluginRegistry registry);

    /** Типы блоков, которые плагин умеет создавать из распознанного текста. */
    default List<BlockHandler> getBlockHandlers() { return Collections.emptyList(); }

    /** Обработчики команд форматирования ("заголовок", "таблица 3x4"). */
    default List<FormattingCommand> getFormattingCommands() { return Collections.emptyList(); }

    /** Процессоры пост-обработки, применяемые к лекции после остановки записи. */
    default List<PostProcessor> getPostProcessors() { return Collections.emptyList(); }

    /** Плагинные форматы экспорта (PDF, DOCX, HTML...). Markdown встроен в ядро. */
    default List<Exporter> getExporters() { return Collections.emptyList(); }

    /** Плагинные кнопки на панели инструментов редактора (UI-слот v1.3). */
    default List<ToolbarAction> getToolbarActions() { return Collections.emptyList(); }

    /**
     * Декларация настроек мода (UI-слот v1.4). Ядро автоматически рисует
     * панель конфигурации на экране «Моды»; значения доступны плагину
     * через {@link PluginContext#getSettings()}.
     */
    default List<PluginSettings.SettingDescriptor> getSettings() { return Collections.emptyList(); }

    /** Подписка на события ядра (начало/конец записи, сохранение лекции). */
    default void subscribe(EventBus bus) { }

    /** Расширения аудио, которые плагин готов принять в импорт (напр. ".mp3"). */
    default List<String> getSupportedAudioExtensions() { return Collections.emptyList(); }

    /**
     * UI-слот v1.5: хук «экран создан». Ядро вызывает его после построения
     * интерфейса своих экранов, передавая идентификатор экрана ("recording",
     * "editor", "lecture_list") и корневой View. Мод может тонко дополнить
     * интерфейс (подсказки, чипы), не меняя код ядра. Исключения гасит ядро.
     */
    default void onScreenReady(String screenId, android.view.View root) { }

    /** Освобождение ресурсов. */
    default void onShutdown() { }
}
