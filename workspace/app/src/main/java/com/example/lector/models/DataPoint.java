package com.example.lector.models;

import java.io.Serializable;

/**
 * Точка данных для графика
 */
public class DataPoint implements Serializable {
    private double x;
    private double y;
    private String label; // Опциональная подпись

    public DataPoint(double x, double y) {
        this.x = x;
        this.y = y;
    }

    public double getX() { return x; }
    public void setX(double x) { this.x = x; }
    public double getY() { return y; }
    public void setY(double y) { this.y = y; }
    public String getLabel() { return label; }
    public void setLabel(String label) { this.label = label; }
}
