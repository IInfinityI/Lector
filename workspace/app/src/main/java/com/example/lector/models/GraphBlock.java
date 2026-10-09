package com.example.lector.models;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

/**
 * Блок графика для визуализации данных.
 * Поддерживает линейные и столбчатые графики.
 */
public class GraphBlock extends ContentBlock implements BlockSerializer {
    private GraphType graphType;
    private String title;
    private String xAxisLabel;
    private String yAxisLabel;
    private List<DataPoint> dataPoints;
    private List<String> xLabels; // Подписи по оси X (для столбчатых графиков)

    public GraphBlock(long timestamp) {
        super(timestamp);
        this.graphType = GraphType.LINE;
        this.dataPoints = new ArrayList<>();
        this.xLabels = new ArrayList<>();
    }

    @Override
    public BlockType getType() {
        return BlockType.GRAPH;
    }

    public GraphType getGraphType() { return graphType; }
    public void setGraphType(GraphType graphType) { this.graphType = graphType; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getXAxisLabel() { return xAxisLabel; }
    public void setXAxisLabel(String xAxisLabel) { this.xAxisLabel = xAxisLabel; }
    public String getYAxisLabel() { return yAxisLabel; }
    public void setYAxisLabel(String yAxisLabel) { this.yAxisLabel = yAxisLabel; }
    public List<DataPoint> getDataPoints() { return dataPoints; }
    public void setDataPoints(List<DataPoint> dataPoints) { this.dataPoints = dataPoints; }
    public List<String> getxLabels() { return xLabels; }
    public void setxLabels(List<String> xLabels) { this.xLabels = xLabels; }

    /**
     * Добавить точку данных
     */
    public void addDataPoint(double x, double y) {
        this.dataPoints.add(new DataPoint(x, y));
    }

    /**
     * Добавить точку с подписью
     */
    public void addDataPoint(double x, double y, String label) {
        DataPoint point = new DataPoint(x, y);
        point.setLabel(label);
        this.dataPoints.add(point);
    }

    /**
     * Удалить все точки
     */
    public void clearData() {
        this.dataPoints.clear();
        this.xLabels.clear();
    }

    @Override
    public JSONObject toJson() {
        JSONObject json = super.toJson();
        try {
            json.put("graphType", graphType.name());
            json.put("title", title);
            json.put("xAxisLabel", xAxisLabel);
            json.put("yAxisLabel", yAxisLabel);
            JSONArray pts = new JSONArray();
            for (DataPoint dp : dataPoints) {
                JSONObject o = new JSONObject();
                o.put("x", dp.getX());
                o.put("y", dp.getY());
                o.put("label", dp.getLabel());
                pts.put(o);
            }
            json.put("dataPoints", pts);
            json.put("xLabels", new JSONArray(xLabels));
        } catch (Exception ignored) {}
        return json;
    }

    public static GraphBlock fromJson(JSONObject json, long timestamp) {
        String savedId = json.optString("id", null);
        GraphBlock b = new GraphBlock(timestamp);
        if (savedId != null) b.id = savedId;
        try { b.graphType = GraphType.valueOf(json.optString("graphType", "LINE")); }
        catch (Exception ignored) {}
        b.title = json.optString("title", null);
        b.xAxisLabel = json.optString("xAxisLabel", null);
        b.yAxisLabel = json.optString("yAxisLabel", null);
        JSONArray pts = json.optJSONArray("dataPoints");
        if (pts != null) {
            b.dataPoints.clear();
            for (int i = 0; i < pts.length(); i++) {
                JSONObject o = pts.optJSONObject(i);
                if (o != null) {
                    DataPoint dp = new DataPoint(o.optDouble("x", 0), o.optDouble("y", 0));
                    dp.setLabel(o.optString("label", null));
                    b.dataPoints.add(dp);
                }
            }
        }
        JSONArray xl = json.optJSONArray("xLabels");
        if (xl != null) {
            b.xLabels.clear();
            for (int i = 0; i < xl.length(); i++) b.xLabels.add(xl.optString(i, ""));
        }
        b.applyBaseJson(json);
        return b;
    }

    @Override
    public String toMarkdown() {
        StringBuilder sb = new StringBuilder();
        
        if (title != null && !title.isEmpty()) {
            sb.append("### ").append(title).append("\n\n");
        }
        
        sb.append("```graph\n");
        sb.append("Type: ").append(graphType.name()).append("\n");
        
        if (xAxisLabel != null) {
            sb.append("X: ").append(xAxisLabel).append("\n");
        }
        if (yAxisLabel != null) {
            sb.append("Y: ").append(yAxisLabel).append("\n");
        }
        
        sb.append("Data:\n");
        for (DataPoint point : dataPoints) {
            sb.append(String.format("  (%.2f, %.2f)", point.getX(), point.getY()));
            if (point.getLabel() != null) {
                sb.append(" - ").append(point.getLabel());
            }
            sb.append("\n");
        }
        
        sb.append("```\n");
        
        return sb.toString();
    }

    /**
     * Получить минимальное значение Y
     */
    public double getMinY() {
        if (dataPoints.isEmpty()) return 0;
        double min = dataPoints.get(0).getY();
        for (DataPoint point : dataPoints) {
            if (point.getY() < min) min = point.getY();
        }
        return min;
    }

    /**
     * Получить максимальное значение Y
     */
    public double getMaxY() {
        if (dataPoints.isEmpty()) return 0;
        double max = dataPoints.get(0).getY();
        for (DataPoint point : dataPoints) {
            if (point.getY() > max) max = point.getY();
        }
        return max;
    }
}

