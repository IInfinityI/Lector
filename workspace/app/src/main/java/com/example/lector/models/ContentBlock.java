package com.example.lector.models;

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
}
