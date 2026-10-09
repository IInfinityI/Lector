package com.example.lector.models;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

/**
 * Базовый класс для всех типов контента в конспекте.
 * Каждый блок имеет тип, временную метку и уникальный идентификатор.
 */
public abstract class ContentBlock implements Serializable {
    protected String id;
    protected long timestamp; // Позиция в аудио (мс)
    protected int speakerId;  // ID спикера (-1 если не определен)
    protected String speakerName; // Имя спикера ("Преподаватель", "Студент")
    protected boolean isVerified; // Проверено ли глубоким анализом
    protected List<String> warnings; // Предупреждения о неточностях

    public ContentBlock(long timestamp) {
        this.id = java.util.UUID.randomUUID().toString();
        this.timestamp = timestamp;
        this.speakerId = -1;
        this.speakerName = "Unknown";
        this.isVerified = false;
        this.warnings = new ArrayList<>();
    }

    public abstract BlockType getType();

    /**
     * Имя типа блока, включая типы, добавленные плагинами (модами).
     * По умолчанию совпадает с именем встроенного BlockType.
     * Плагины могут переопределить этот метод для кастомных типов.
     */
    public String getTypeKey() {
        return getType().name();
    }

    public String getId() { return id; }
    public long getTimestamp() { return timestamp; }
    public void setTimestamp(long timestamp) { this.timestamp = timestamp; }
    public int getSpeakerId() { return speakerId; }
    public void setSpeakerId(int speakerId) { this.speakerId = speakerId; }
    public String getSpeakerName() { return speakerName; }
    public void setSpeakerName(String speakerName) { this.speakerName = speakerName; }
    public boolean isVerified() { return isVerified; }
    public void setVerified(boolean verified) { isVerified = verified; }
    public List<String> getWarnings() { return warnings; }
    public void addWarning(String warning) { this.warnings.add(warning); }
    
    public abstract String toMarkdown();

    /**
     * Служебная часть JSON (id, таймкод, спикер, предупреждения).
     * Специфичные поля добавляет реализация BlockSerializer.toJson().
     */
    public org.json.JSONObject baseJson(org.json.JSONObject json) {
        try {
            json.put("id", id);
            json.put("timestamp", timestamp);
            json.put("type", getTypeKey());
            json.put("speakerId", speakerId);
            json.put("speakerName", speakerName);
            json.put("isVerified", isVerified);
            json.put("warnings", new org.json.JSONArray(warnings));
        } catch (Exception ignored) {}
        return json;
    }

    /** Сериализация служебных + специфичных полей. Переопределяется блоками-наследниками. */
    public org.json.JSONObject toJson() {
        return baseJson(new org.json.JSONObject());
    }

    /** Восстановление служебных полей из JSON. */
    public void applyBaseJson(org.json.JSONObject json) {
        if (json.has("id")) this.id = json.optString("id", this.id);
        this.speakerId = json.optInt("speakerId", -1);
        this.speakerName = json.optString("speakerName", "Unknown");
        this.isVerified = json.optBoolean("isVerified", false);
        org.json.JSONArray w = json.optJSONArray("warnings");
        if (w != null) {
            warnings.clear();
            for (int i = 0; i < w.length(); i++) warnings.add(w.optString(i, ""));
        }
    }
}
