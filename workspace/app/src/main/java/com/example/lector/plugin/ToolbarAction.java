package com.example.lector.plugin;

import com.example.lector.models.Lecture;

/**
 * Плагинная кнопка на панели инструментов редактора (UI-слот v1.3).
 *
 * Мод объявляет действие — ядро автоматически рисует кнопку в тулбаре
 * редактора и вызывает {@link #onClick(Lecture, PluginContext)} при нажатии.
 * Так работают аддоны в играх: мод добавляет себе кнопку, не трогая код UI.
 */
public interface ToolbarAction {

    /** Короткая подпись на кнопке (например «Тег», «PDF»). */
    String getLabel();

    /**
     * Иконка из ресурсов приложения (drawable res id) либо 0 — без иконки.
     * Ресурсы мода должны быть доступны в APK (встроенные плагины) —
     * для внешних DEX-модов используйте текстовые метки.
     */
    default int getIconResId() { return 0; }

    /** Порядок размещения кнопки (меньше — левее). По умолчанию — после всех. */
    default int getOrder() { return 100; }

    /**
     * Показать ли кнопку для данной лекции (например, только когда есть блоки
     * конкретного типа). Ядро скрывает неактивные действия.
     */
    default boolean isVisible(Lecture lecture) { return true; }

    /** Обработка нажатия. lecture — текущая лекция редактора. */
    void onClick(Lecture lecture, PluginContext context);
}
