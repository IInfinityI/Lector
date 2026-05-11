package com.example.lector.models;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

/**
 * Модель всей лекции - содержит все блоки контента и метаданные.
 */
public class Lecture implements Serializable {
    private String id;
    private String subject;           // Название предмета
    private long date;                // Дата создания (timestamp)
    private String audioPath;         // Путь к аудиофайлу
    private long duration;            // Длительность записи (мс)
    private List<ContentBlock> blocks; // Все блоки контента
    private List<Speaker> speakers;   // Список спикеров
    private boolean isVerified;       // Проверена ли глубоким анализом
    private String notes;             // Пользовательские заметки

    public Lecture(String subject, long date) {
        this.id = java.util.UUID.randomUUID().toString();
        this.subject = subject;
        this.date = date;
        this.blocks = new ArrayList<>();
        this.speakers = new ArrayList<>();
        this.isVerified = false;
        
        // Добавляем дефолтных спикеров
        speakers.add(new Speaker(0, "Преподаватель"));
        speakers.add(new Speaker(1, "Студент"));
    }

    public String getId() { return id; }
    public String getSubject() { return subject; }
    public void setSubject(String subject) { this.subject = subject; }
    public long getDate() { return date; }
    public void setDate(long date) { this.date = date; }
    public String getAudioPath() { return audioPath; }
    public void setAudioPath(String audioPath) { this.audioPath = audioPath; }
    public long getDuration() { return duration; }
    public void setDuration(long duration) { this.duration = duration; }
    public List<ContentBlock> getBlocks() { return blocks; }
    public void setBlocks(List<ContentBlock> blocks) { this.blocks = blocks; }
    public List<Speaker> getSpeakers() { return speakers; }
    public void setSpeakers(List<Speaker> speakers) { this.speakers = speakers; }
    public boolean isVerified() { return isVerified; }
    public void setVerified(boolean verified) { isVerified = verified; }
    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }

    /**
     * Добавить блок контента
     */
    public void addBlock(ContentBlock block) {
        this.blocks.add(block);
    }

    /**
     * Вставить блок на определенную позицию
     */
    public void insertBlock(int index, ContentBlock block) {
        if (index >= 0 && index <= blocks.size()) {
            this.blocks.add(index, block);
        }
    }

    /**
     * Удалить блок по индексу
     */
    public void removeBlock(int index) {
        if (index >= 0 && index < blocks.size()) {
            this.blocks.remove(index);
        }
    }

    /**
     * Удалить блок по ID
     */
    public void removeBlockById(String blockId) {
        for (int i = 0; i < blocks.size(); i++) {
            if (blocks.get(i).getId().equals(blockId)) {
                blocks.remove(i);
                break;
            }
        }
    }

    /**
     * Получить последний блок определенного типа
     */
    public <T extends ContentBlock> T getLastBlockOfType(BlockType type) {
        for (int i = blocks.size() - 1; i >= 0; i--) {
            ContentBlock block = blocks.get(i);
            if (block.getType() == type) {
                try {
                    return (T) block;
                } catch (ClassCastException e) {
                    continue;
                }
            }
        }
        return null;
    }

    /**
     * Получить все блоки текста
     */
    public List<TextBlock> getTextBlocks() {
        List<TextBlock> result = new ArrayList<>();
        for (ContentBlock block : blocks) {
            if (block instanceof TextBlock) {
                result.add((TextBlock) block);
            }
        }
        return result;
    }

    /**
     * Экспорт всей лекции в Markdown
     */
    public String toMarkdown() {
        StringBuilder sb = new StringBuilder();
        
        // Заголовок лекции
        sb.append("# ").append(subject).append("\n\n");
        sb.append("**Дата:** ").append(formatDate(date)).append("\n\n");
        sb.append("**Длительность:** ").append(formatDuration(duration)).append("\n\n");
        sb.append("---\n\n");
        
        // Все блоки
        for (ContentBlock block : blocks) {
            sb.append(block.toMarkdown()).append("\n\n");
        }
        
        // Заметки
        if (notes != null && !notes.isEmpty()) {
            sb.append("---\n\n");
            sb.append("## Заметки\n\n").append(notes).append("\n");
        }
        
        return sb.toString();
    }

    /**
     * Сгенерировать имя файла для аудио
     */
    public String generateAudioFileName() {
        java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", java.util.Locale.getDefault());
        String dateStr = sdf.format(new java.util.Date(date));
        String safeSubject = subject.replaceAll("[^a-zA-Z0-9а-яА-ЯёЁ\\s_-]", "").trim().replaceAll("\\s+", "_");
        return safeSubject + "_" + dateStr + ".m4a";
    }

    private String formatDate(long timestamp) {
        java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("dd.MM.yyyy HH:mm", java.util.Locale.getDefault());
        return sdf.format(new java.util.Date(timestamp));
    }

    private String formatDuration(long ms) {
        long seconds = ms / 1000;
        long hours = seconds / 3600;
        long minutes = (seconds % 3600) / 60;
        long secs = seconds % 60;
        return String.format("%02d:%02d:%02d", hours, minutes, secs);
    }
}

/**
 * Модель спикера для Speaker Diarization
 */
class Speaker implements Serializable {
    private int id;
    private String name;
    private int color; // Цвет для отображения в UI
    private int totalSpeakingTime; // Общее время речи (мс)

    public Speaker(int id, String name) {
        this.id = id;
        this.name = name;
        this.color = generateColor(id);
        this.totalSpeakingTime = 0;
    }

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public int getColor() { return color; }
    public void setColor(int color) { this.color = color; }
    public int getTotalSpeakingTime() { return totalSpeakingTime; }
    public void setTotalSpeakingTime(int totalSpeakingTime) { this.totalSpeakingTime = totalSpeakingTime; }
    
    public void addSpeakingTime(int ms) {
        this.totalSpeakingTime += ms;
    }

    private int generateColor(int seed) {
        // Генерируем приятные цвета для разных спикеров
        int[] colors = {
            0xFF2196F3, // Синий
            0xFF4CAF50, // Зеленый
            0xFFFF9800, // Оранжевый
            0xFF9C27B0, // Фиолетовый
            0xFFF44336  // Красный
        };
        return colors[seed % colors.length];
    }
}
