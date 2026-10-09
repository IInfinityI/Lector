package com.example.lector.models;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

/**
 * Блок текста - результат транскрибации речи.
 * Поддерживает смешанный русский/английский язык.
 */
public class TextBlock extends ContentBlock implements BlockSerializer {
    private String text;
    private String language; // "ru", "en", "mixed"
    private List<WordTimestamp> wordTimestamps; // Для синхронизации с аудио

    public TextBlock(String text, long timestamp) {
        super(timestamp);
        this.text = text;
        this.language = detectLanguage(text);
        this.wordTimestamps = new ArrayList<>();
    }

    private String detectLanguage(String text) {
        if (text == null || text.isEmpty()) return "unknown";
        
        int cyrillic = 0;
        int latin = 0;
        
        for (char c : text.toCharArray()) {
            if (Character.UnicodeBlock.of(c) == Character.UnicodeBlock.CYRILLIC) {
                cyrillic++;
            } else if (Character.UnicodeBlock.of(c) == Character.UnicodeBlock.BASIC_LATIN) {
                latin++;
            }
        }
        
        if (cyrillic > 0 && latin > 0) return "mixed";
        if (cyrillic > latin) return "ru";
        if (latin > 0) return "en";
        return "unknown";
    }

    @Override
    public BlockType getType() {
        return BlockType.TEXT;
    }

    public String getText() { return text; }
    public void setText(String text) { this.text = text; }
    public String getLanguage() { return language; }
    public List<WordTimestamp> getWordTimestamps() { return wordTimestamps; }
    public void setWordTimestamps(List<WordTimestamp> timestamps) { 
        this.wordTimestamps = timestamps; 
    }

    @Override
    public JSONObject toJson() {
        JSONObject json = super.toJson();
        try {
            json.put("text", text);
            json.put("language", language);
            JSONArray wt = new JSONArray();
            for (WordTimestamp w : wordTimestamps) {
                JSONObject o = new JSONObject();
                o.put("word", w.getWord());
                o.put("start", w.getStartTime());
                o.put("end", w.getEndTime());
                wt.put(o);
            }
            json.put("wordTimestamps", wt);
        } catch (Exception ignored) {}
        return json;
    }

    public static TextBlock fromJson(JSONObject json, long timestamp) {
        String savedId = json.optString("id", null);
        TextBlock b = new TextBlock(json.optString("text", ""), timestamp);
        if (savedId != null) b.id = savedId;
        JSONArray wt = json.optJSONArray("wordTimestamps");
        if (wt != null) {
            List<WordTimestamp> list = new ArrayList<>();
            for (int i = 0; i < wt.length(); i++) {
                JSONObject o = wt.optJSONObject(i);
                if (o != null) {
                    list.add(new WordTimestamp(o.optString("word", ""),
                        o.optLong("start", 0), o.optLong("end", 0)));
                }
            }
            b.setWordTimestamps(list);
        }
        b.applyBaseJson(json);
        return b;
    }

    @Override
    public String toMarkdown() {
        StringBuilder sb = new StringBuilder();
        if (!isVerified() && !getWarnings().isEmpty()) {
            sb.append("**"); // Пометка неточности
        }
        sb.append(text);
        if (!isVerified() && !getWarnings().isEmpty()) {
            sb.append("**");
        }
        return sb.toString();
    }

    /**
     * Внутренний класс для хранения таймкодов каждого слова.
     * Нужно для синхронизации аудио и текста (клик на слово -> перемотка).
     */
    public static class WordTimestamp implements Serializable {
        private String word;
        private long startTime; // мс
        private long endTime;   // мс

        public WordTimestamp(String word, long start, long end) {
            this.word = word;
            this.startTime = start;
            this.endTime = end;
        }

        public String getWord() { return word; }
        public long getStartTime() { return startTime; }
        public long getEndTime() { return endTime; }
    }
}
