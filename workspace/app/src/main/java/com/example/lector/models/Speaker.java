package com.example.lector.models;

import java.io.Serializable;

/**
 * Модель спикера для Speaker Diarization.
 */
public class Speaker implements Serializable {
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
        return colors[Math.abs(seed) % colors.length];
    }
}
