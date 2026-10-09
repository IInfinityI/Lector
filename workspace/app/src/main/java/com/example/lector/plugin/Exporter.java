package com.example.lector.plugin;

import com.example.lector.models.Lecture;

import java.io.File;

/**
 * Плагинный экспортёр — второй пример «модифицируемости» после BlockRenderer.
 *
 * Мод объявляет формат (например PDF или DOCX) и умеет превращать лекцию
 * в файл на диске. Ядро показывает все зарегистрированные форматы
 * в диалоге экспорта редактора и вызывает соответствующий экспортёр.
 *
 * Экспортёр получает уже готовый Markdown лекции (с учётом рендереров
 * других модов) — так моды могут работать поверх контента друг друга,
 * как аддоны в играх, не зная друг о друге.
 */
public interface Exporter {

    /** Формат, который этот экспортёр умеет производить. */
    ExportFormat getFormat();

    /**
     * Экспортировать лекцию в файл.
     *
     * @param lecture   экспортируемая лекция
     * @param markdown  уже отрендеренный Markdown (через реестр рендереров)
     * @param targetFile целевой файл (директория существует, файл может не существовать)
     * @return true, если файл успешно записан
     * @throws Exception любая ошибка будет показана пользователю как Toast
     */
    boolean export(Lecture lecture, String markdown, File targetFile) throws Exception;
}
