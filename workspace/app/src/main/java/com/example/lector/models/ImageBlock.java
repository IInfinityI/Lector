package com.example.lector.models;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

/**
 * Блок изображения (фотография доски, слайда или нарисованная схема).
 */
public class ImageBlock extends ContentBlock implements BlockSerializer {
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
    public JSONObject toJson() {
        JSONObject json = super.toJson();
        try {
            json.put("imagePath", imagePath);
            json.put("caption", caption);
            json.put("source", source.name());
            json.put("width", width);
            json.put("height", height);
            JSONArray pts = new JSONArray();
            for (Point pt : points) {
                JSONObject o = new JSONObject();
                o.put("x", pt.getX());
                o.put("y", pt.getY());
                o.put("color", pt.getColor());
                o.put("strokeWidth", pt.getStrokeWidth());
                pts.put(o);
            }
            json.put("points", pts);
        } catch (Exception ignored) {}
        return json;
    }

    public static ImageBlock fromJson(JSONObject json, long timestamp) {
        String path = json.optString("imagePath", null);
        ImageSource src;
        try { src = ImageSource.valueOf(json.optString("source", "CAMERA")); }
        catch (Exception e) { src = ImageSource.CAMERA; }
        String savedId = json.optString("id", null);
        ImageBlock b = path != null ? new ImageBlock(path, timestamp)
                                    : new ImageBlock(timestamp, src);
        if (savedId != null) b.id = savedId;
        b.caption = json.optString("caption", null);
        b.width = json.optInt("width", 0);
        b.height = json.optInt("height", 0);
        JSONArray pts = json.optJSONArray("points");
        if (pts != null) {
            b.points.clear();
            for (int i = 0; i < pts.length(); i++) {
                JSONObject o = pts.optJSONObject(i);
                if (o != null) {
                    b.points.add(new Point((float) o.optDouble("x", 0), (float) o.optDouble("y", 0),
                        o.optInt("color", 0xFF000000), (float) o.optDouble("strokeWidth", 5.0)));
                }
            }
        }
        b.applyBaseJson(json);
        return b;
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

