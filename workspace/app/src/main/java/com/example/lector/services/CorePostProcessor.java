package com.example.lector.services;

import com.example.lector.models.ContentBlock;
import com.example.lector.models.HeadingBlock;
import com.example.lector.models.Lecture;
import com.example.lector.models.TextBlock;
import com.example.lector.plugin.PostProcessor;

import java.util.ArrayList;
import java.util.List;

/**
 * Встроенный пост-процессор ядра (реализует плагин-API PostProcessor).
 * Применяется к лекции после остановки записи:
 *  1. Удаляет пустые текстовые блоки и повторы подряд идущих одинаковых фраз
 *     (частый артефакт SpeechRecognizer при перезапуске распознавания).
 *  2. Склеивает короткие соседние текстовые блоки одного спикера в абзацы.
 *  3. Если у лекции нет заголовка — добавляет HeadingBlock с названием предмета.
 */
public class CorePostProcessor implements PostProcessor {

    private static final int MIN_CHUNK_LEN = 3;         // «слово» короче — мусор
    private static final int MERGE_MAX_CHARS = 400;     // предел длины абзаца

    @Override
    public String getName() { return "core-postprocess"; }

    @Override
    public void process(Lecture lecture) {
        if (lecture == null || lecture.getBlocks() == null) return;

        List<ContentBlock> cleaned = new ArrayList<>();
        TextBlock pending = null;

        for (ContentBlock block : lecture.getBlocks()) {
            if (!(block instanceof TextBlock)) {
                if (pending != null) { cleaned.add(pending); pending = null; }
                cleaned.add(block);
                continue;
            }
            TextBlock tb = (TextBlock) block;
            String text = normalize(tb.getText());

            if (text.isEmpty()) continue;                       // пустой блок
            if (!cleaned.isEmpty() && isDuplicateTail(cleaned, text)) continue; // дубль фразы

            if (pending == null) {
                pending = new TextBlock(text, tb.getTimestamp());
                pending.setSpeakerId(tb.getSpeakerId());
                pending.setSpeakerName(tb.getSpeakerName());
                copyWordTimestamps(pending, tb);
            } else if (sameSpeaker(pending, tb)
                    && pending.getText().length() + text.length() < MERGE_MAX_CHARS) {
                pending.setText(joinSentences(pending.getText(), text));
                appendWordTimestamps(pending, tb);
            } else {
                cleaned.add(pending);
                pending = new TextBlock(text, tb.getTimestamp());
                pending.setSpeakerId(tb.getSpeakerId());
                pending.setSpeakerName(tb.getSpeakerName());
                copyWordTimestamps(pending, tb);
            }
        }
        if (pending != null) cleaned.add(pending);

        lecture.setBlocks(cleaned);

        // Заголовок из названия предмета, если структура отсутствует
        boolean hasHeading = false;
        for (ContentBlock b : cleaned) {
            if (b instanceof HeadingBlock) { hasHeading = true; break; }
        }
        if (!hasHeading && !cleaned.isEmpty()) {
            HeadingBlock h = new HeadingBlock(lecture.getSubjectSafe(), 0, 1);
            lecture.insertBlock(0, h);
        }
    }

    private String normalize(String raw) {
        if (raw == null) return "";
        String s = raw.trim().replaceAll("\\s+", " ");
        return s.length() < MIN_CHUNK_LEN && !s.matches(".*[а-яa-zA-Z].*") ? "" : s;
    }

    /** Последний текстовый блок уже содержит точно эту фразу — артефакт перезапуска распознавания. */
    private boolean isDuplicateTail(List<ContentBlock> blocks, String text) {
        for (int i = blocks.size() - 1; i >= 0; i--) {
            ContentBlock b = blocks.get(i);
            if (!(b instanceof TextBlock)) break;
            String prev = normalize(((TextBlock) b).getText());
            if (prev.equalsIgnoreCase(text)) return true;
            if (prev.endsWith(text.toLowerCase())) return true;
            break; // сравниваем только с последним блоком
        }
        return false;
    }

    private boolean sameSpeaker(TextBlock a, TextBlock b) {
        return a.getSpeakerId() == b.getSpeakerId();
    }

    private String joinSentences(String a, String b) {
        String left = a.trim();
        char last = left.isEmpty() ? ' ' : left.charAt(left.length() - 1);
        boolean ended = last == '.' || last == '!' || last == '?' || last == ':' || last == ';';
        return ended ? left + " " + b : left + ", " + b;
    }

    private void copyWordTimestamps(TextBlock target, TextBlock source) {
        target.setWordTimestamps(new ArrayList<>(source.getWordTimestamps()));
    }

    private void appendWordTimestamps(TextBlock target, TextBlock source) {
        target.getWordTimestamps().addAll(source.getWordTimestamps());
    }
}
