package com.example.lector.models;

import java.io.Serializable;

/**
 * Точка для хранения координат рисунка
 */
public class Point implements Serializable {
    private float x;
    private float y;
    private int color;      // Цвет точки (ARGB)
    private float strokeWidth; // Толщина штриха

    public Point(float x, float y) {
        this.x = x;
        this.y = y;
        this.color = 0xFF000000; // Черный по умолчанию
        this.strokeWidth = 5.0f;
    }

    public Point(float x, float y, int color, float strokeWidth) {
        this.x = x;
        this.y = y;
        this.color = color;
        this.strokeWidth = strokeWidth;
    }

    public float getX() { return x; }
    public void setX(float x) { this.x = x; }
    public float getY() { return y; }
    public void setY(float y) { this.y = y; }
    public int getColor() { return color; }
    public void setColor(int color) { this.color = color; }
    public float getStrokeWidth() { return strokeWidth; }
    public void setStrokeWidth(float strokeWidth) { this.strokeWidth = strokeWidth; }
}
