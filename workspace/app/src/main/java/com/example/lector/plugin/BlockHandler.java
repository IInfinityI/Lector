package com.example.lector.plugin;

import com.example.lector.models.ContentBlock;

/**
 * Обработчик, превращающий распознанный текст в блок контента.
 * Плагины регистрируют свои хендлеры через {@link LectorPlugin#getBlockHandlers()},
 * ядро опрашивает их по цепочке ответственности до встроенного анализатора.
 */
public interface BlockHandler {

    /** Название хендлера для отладки. */
    String getName();

    /** Возвращает true, если этот хендлер берётся данный текст. */
    boolean canHandle(String text, long timestampMs);

    /** Создаёт блок. Вызывается только если canHandle вернул true. */
    ContentBlock createBlock(String text, long timestampMs);
}
