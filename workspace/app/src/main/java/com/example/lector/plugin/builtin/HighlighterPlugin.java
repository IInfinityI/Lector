package com.example.lector.plugin.builtin;

import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.graphics.pdf.PdfDocument;
import android.view.View;
import android.widget.TextView;

import com.example.lector.plugin.BlockHandler;
import com.example.lector.plugin.BlockRenderer;
import com.example.lector.plugin.EventBus;
import com.example.lector.plugin.ExportFormat;
import com.example.lector.plugin.Exporter;
import com.example.lector.plugin.LectorPlugin;
import com.example.lector.plugin.PluginContext;
import com.example.lector.plugin.PluginRegistry;
import com.example.lector.plugin.ToolbarAction;

import java.io.File;
import java.io.FileOutputStream;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

/**
 * Демо-мод «Highlighter»: распознаёт устные команды
 *  - «ключевое …» / «выдели …» / «определение …»
 * и превращает фразу в блок HighlightBlock (кастомный тип HIGHLIGHT).
 *
 * Плагин подключается списком в assets/plugins.json — без правки ядра.
 * UI-слот v1.4: мод объявляет настройки через getSettings(); ядро само
 * рисует панель конфигурации на экране «Моды», а мод читает значения
 * из context.getSettings() (в демо — ширина рамки выделения).
 */
public class HighlighterPlugin implements LectorPlugin {

    public static final String ID = "builtin.highlighter";

    private static final com.example.lector.plugin.PluginSettings.SettingDescriptor
        SETTING_BORDER = com.example.lector.plugin.PluginSettings.SettingDescriptor
            .intVal("border_width", "Толщина рамки (dp)", 2);

    @Override
    public String getId() { return ID; }

    @Override
    public String getName() { return "Highlighter"; }

    @Override
    public String getDescription() {
        return "Выделение ключевых мыслей и определений цветными блоками.";
    }

    @Override
    public void onInit(PluginContext context) { /* настройки читаются лениво из getSettings() */ }

    /**
     * UI-слот v1.4: декларация настроек мода. Ядро автоматически рисует
     * панель конфигурации на экране «Моды» (числовое поле), значение
     * сохраняется в изолированном SharedPreferences этого мода.
     */
    @Override
    public List<com.example.lector.plugin.PluginSettings.SettingDescriptor> getSettings() {
        return Collections.singletonList(SETTING_BORDER);
    }

    @Override
    public void onRegister(PluginRegistry registry) {
        // 1. Новый тип блока
        registry.registerBlockType(HighlightBlock.TYPE_KEY, this,
            new PluginRegistry.BlockFactory() {
                @Override
                public com.example.lector.models.ContentBlock create(long timestamp) {
                    return new HighlightBlock("", timestamp);
                }

                @Override
                public com.example.lector.models.ContentBlock fromJson(org.json.JSONObject json,
                                                                       long timestamp) {
                    return HighlightBlock.fromJson(json, timestamp);
                }
            });

        // 2. Обработчик текста: фразы с триггерными словами → HighlightBlock
        registry.registerBlockHandler(new BlockHandler() {
            @Override
            public String getName() { return "highlight-keywords"; }

            @Override
            public boolean canHandle(String text, long timestampMs) {
                if (text == null) return false;
                String lower = text.toLowerCase();
                return lower.startsWith("ключевое") || lower.startsWith("выдели")
                    || lower.startsWith("определение");
            }

            @Override
            public com.example.lector.models.ContentBlock createBlock(String text, long timestampMs) {
                String lower = text.toLowerCase();
                String color = lower.startsWith("определение") ? "blue" : "yellow";
                // Убираем триггерное слово из содержимого
                int sp = text.indexOf(' ');
                String body = sp > 0 ? text.substring(sp + 1) : text;
                return new HighlightBlock(body, timestampMs, color);
            }
        });

        // 3. UI-слот: как рисовать HIGHLIGHT в редакторе и экспортировать в Markdown.
        //    Ядро не знает про HighlightBlock — вся логика отображения принадлежит моду.
        registry.registerBlockRenderer(HighlightBlock.TYPE_KEY, new BlockRenderer() {
            @Override
            public void render(com.example.lector.models.ContentBlock block,
                               TextView timestampView, TextView contentView, View itemView) {
                if (block instanceof HighlightBlock) {
                    HighlightBlock hl = (HighlightBlock) block;
                    contentView.setText(hl.getText());
                    contentView.setTypeface(null, Typeface.BOLD);
                    contentView.setBackgroundColor(hl.parseColor());
                } else {
                    contentView.setText(block.toMarkdown());
                }
            }

            @Override
            public String renderMarkdown(com.example.lector.models.ContentBlock block) {
                if (block instanceof HighlightBlock) {
                    return "> [!NOTE]\n> **" + ((HighlightBlock) block).getText() + "**";
                }
                return block.toMarkdown();
            }
        });
    }

    @Override
    public void subscribe(EventBus bus) {
        // Демо: можно вести статистику выделений в свою песочницу
    }

    /**
     * Демо UI-слота v1.3: кнопка «Тег #» в тулбаре редактора.
     * Мод сам решает, что делать с лекцией — ядро только рисует кнопку.
     */
    @Override
    public List<ToolbarAction> getToolbarActions() {
        return Arrays.<ToolbarAction>asList(new ToolbarAction() {
            @Override
            public String getLabel() { return "Тег #"; }

            @Override
            public int getOrder() { return 10; }

            @Override
            public void onClick(com.example.lector.models.Lecture lecture, PluginContext context) {
                if (lecture == null) return;
                // Простой демо-эффект: добавить хештег-выделение последнему текстовому блоку
                com.example.lector.models.ContentBlock last = null;
                for (com.example.lector.models.ContentBlock b : lecture.getBlocks()) {
                    if (b instanceof com.example.lector.models.TextBlock) last = b;
                }
                if (last != null) {
                    String text = ((com.example.lector.models.TextBlock) last).getText();
                    HighlightBlock hl = new HighlightBlock("#" + firstWord(text),
                        last.getTimestamp(), "green");
                    // Демонстрация v1.4: мод читает свою настройку, которую
                    // пользователь изменил на экране «Моды» (ядро сохранило её).
                    int borderDp = context.getSettings().getInt("border_width", 2);
                    hl.setNote("border=" + borderDp + "dp");
                    lecture.addBlock(hl);
                    // Сохранение через контекст не нужно — ядро сохранит лекцию само;
                    // плагин может использовать context.getPluginDataDir() для своих файлов
                }
            }

            private String firstWord(String s) {
                if (s == null || s.isEmpty()) return "идея";
                String t = s.trim();
                int sp = t.indexOf(' ');
                String w = sp > 0 ? t.substring(0, sp) : t;
                return w.replaceAll("[^\\p{L}\\d]", "");
            }
        });
    }

    /**
     * Демо плагинного формата экспорта: PDF через PdfDocument (системный, без библиотек).
     * Показывает, как мод добавляет новый формат, не трогая код ядра.
     */
    @Override
    public List<Exporter> getExporters() {
        return Arrays.<Exporter>asList(new PdfExporter());
    }

    static class PdfExporter implements Exporter {

        static final ExportFormat FORMAT = new ExportFormat("pdf", "PDF-документ", ".pdf");

        @Override
        public ExportFormat getFormat() { return FORMAT; }

        @Override
        public boolean export(com.example.lector.models.Lecture lecture, String markdown,
                              File targetFile) throws Exception {
            android.graphics.pdf.PdfDocument doc = new android.graphics.pdf.PdfDocument();
            int pageWidth = 720, pageHeight = 1080; // ~A4 при 72dpi

            Paint bodyPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
            bodyPaint.setColor(Color.DKGRAY);
            bodyPaint.setTextSize(14f);

            float margin = 40f, lineHeight = 20f, maxWidth = pageWidth - 2 * margin;
            int pageNum = 1;
            PdfDocument.PageInfo info = new PdfDocument.PageInfo.Builder(
                pageWidth, pageHeight, pageNum).create();
            PdfDocument.Page page = doc.startPage(info);
            Canvas canvas = page.getCanvas();
            float y = margin + 24f;

            String[] lines = markdown.split("\n", -1);
            for (String raw : lines) {
                String line = raw.replaceAll("[*>`#]", " ").trim().isEmpty()
                    ? "" : raw.replaceAll("^[*># ]+", "");
                // Перенос длинных строк по словам
                StringBuilder para = new StringBuilder(line);
                while (para.length() > 0) {
                    int fit = breakIndex(para.toString(), bodyPaint, maxWidth);
                    String chunk = para.substring(0, fit);
                    if (y > pageHeight - margin) {
                        doc.finishPage(page);
                        info = new PdfDocument.PageInfo.Builder(
                            pageWidth, pageHeight, ++pageNum).create();
                        page = doc.startPage(info);
                        canvas = page.getCanvas();
                        y = margin + 24f;
                    }
                    canvas.drawText(chunk, margin, y, bodyPaint);
                    y += lineHeight;
                    para = new StringBuilder(para.substring(fit));
                }
                if (line.isEmpty()) y += lineHeight / 2; // пустая строка — интервал
            }

            doc.finishPage(page);
            try (FileOutputStream out = new FileOutputStream(targetFile)) {
                doc.writeTo(out);
            } finally {
                doc.close();
            }
            return targetFile.exists();
        }

        private int breakIndex(String s, Paint paint, float maxWidth) {
            if (paint.measureText(s) <= maxWidth) return s.length();
            int lo = 1, hi = s.length();
            while (lo < hi) {
                int mid = (lo + hi + 1) / 2;
                if (paint.measureText(s.substring(0, mid)) <= maxWidth) lo = mid;
                else hi = mid - 1;
            }
            // Стянуть до границы слова
            int cut = lo;
            int space = s.lastIndexOf(' ', lo);
            if (space > 0) cut = space + 1;
            return Math.max(1, cut);
        }
    }
}
