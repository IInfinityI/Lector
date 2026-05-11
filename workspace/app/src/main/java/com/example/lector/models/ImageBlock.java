package com.example.lector.models;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

/**
 * Блок изображения (фотография доски, слайда или нарисованная схема).
 */
public class ImageBlock extends ContentBlock {
    private String imagePath;      // Путь к файлу изображения
    private String caption;        // Подпись
    private ImageSource source;    // Источник изображения
    private int width;             // Ширина в пикселях
    private int height;            // Высота в пикселях
    private List<Point> points;    // Точки для рисованных схем

    public ImageBlock(String imagePath, long timestamp) {
        super(timestamp);
        this.imagePath = imagePath;
        this.source = ImageSource.CAMERA;
        this.points = new ArrayList<>();
    }

    /**
     * Конструктор для рисованных схем
     */
    public ImageBlock(long timestamp, ImageSource source) {
        super(timestamp);
        this.source = source;
        this.points = new ArrayList<>();
        this.imagePath = null; // Для рисунков путь генерируется при сохранении
    }

    @Override
    public BlockType getType() {
        return BlockType.IMAGE;
    }

    public String getImagePath() { return imagePath; }
    public void setImagePath(String imagePath) { this.imagePath = imagePath; }
    public String getCaption() { return caption; }
    public void setCaption(String caption) { this.caption = caption; }
    public ImageSource getSource() { return source; }
    public void setSource(ImageSource source) { this.source = source; }
    public int getWidth() { return width; }
    public void setWidth(int width) { this.width = width; }
    public int getHeight() { return height; }
    public void setHeight(int height) { this.height = height; }
    public List<Point> getPoints() { return points; }
    public void setPoints(List<Point> points) { this.points = points; }
    
    /**
     * Добавить точку для рисованной схемы
     */
    public void addPoint(Point point) {
        this.points.add(point);
    }

    /**
     * Очистить все точки
     */
    public void clearPoints() {
        this.points.clear();
    }

    @Override
    public String toMarkdown() {
        StringBuilder sb = new StringBuilder();
        
        if (caption != null && !caption.isEmpty()) {
            sb.append("*").append(caption).append("*\n\n");
        }
        
        if (imagePath != null) {
            // Извлекаем только имя файла из полного пути
            String fileName = imagePath.substring(imagePath.lastIndexOf('/') + 1);
            sb.append("![Image](").append(fileName).append(")");
        } else if (!points.isEmpty()) {
            sb.append("![Drawing](drawing_").append(getTimestamp()).append(".png)");
        }
        
        return sb.toString();
    }
}

/**
 * Источник изображения
 */
enum ImageSource {
    CAMERA,         // Фото с камеры
    GALLERY,        // Из галереи
    DRAWING,        // Нарисовано от руки
    SCREENSHOT      // Скриншот
}

/**
 * Точка для хранения координат рисунка
 */
class Point implements Serializable {
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
