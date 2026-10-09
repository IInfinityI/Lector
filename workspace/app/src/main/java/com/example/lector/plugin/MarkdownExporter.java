package com.example.lector.plugin;

import com.example.lector.models.Lecture;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;

/**
 * Встроенный экспортёр Markdown — базовый формат ядра.
 * Реализует тот же интерфейс Exporter, что и плагинные форматы,
 * чтобы UI экспорта был единообразным для всех форматов.
 */
public class MarkdownExporter implements Exporter {

    public static final ExportFormat FORMAT =
        new ExportFormat("markdown", "Markdown (.md)", ".md");

    @Override
    public ExportFormat getFormat() { return FORMAT; }

    @Override
    public boolean export(Lecture lecture, String markdown, File targetFile) throws Exception {
        try (OutputStreamWriter w = new OutputStreamWriter(new FileOutputStream(targetFile), "UTF-8")) {
            w.write(markdown);
        }
        return targetFile.exists();
    }
}
