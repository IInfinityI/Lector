package com.example.lector.models;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

/**
 * Блок таблицы для хранения структурированных данных.
 * Поддерживает интерактивное редактирование и экспорт в Markdown.
 */
public class TableBlock extends ContentBlock implements BlockSerializer {
    private List<List<String>> rows;
    private int columns;
    private String caption; // Заголовок таблицы
    private boolean hasHeader; // Есть ли заголовочная строка

    public TableBlock(int rows, int columns, long timestamp) {
        super(timestamp);
        this.rows = new ArrayList<>();
        this.columns = columns;
        this.hasHeader = true;
        
        // Инициализация пустыми ячейками
        for (int i = 0; i < rows; i++) {
            List<String> row = new ArrayList<>();
            for (int j = 0; j < columns; j++) {
                row.add("");
            }
            this.rows.add(row);
        }
    }

    @Override
    public BlockType getType() {
        return BlockType.TABLE;
    }

    public List<List<String>> getRows() { return rows; }
    public int getColumns() { return columns; }
    public void setColumns(int columns) { this.columns = columns; }
    public String getCaption() { return caption; }
    public void setCaption(String caption) { this.caption = caption; }
    public boolean hasHeader() { return hasHeader; }
    public void setHasHeader(boolean hasHeader) { this.hasHeader = hasHeader; }

    /**
     * Установить значение ячейки
     */
    public void setCell(int row, int col, String value) {
        if (row >= 0 && row < rows.size() && col >= 0 && col < columns) {
            rows.get(row).set(col, value);
        }
    }

    /**
     * Получить значение ячейки
     */
    public String getCell(int row, int col) {
        if (row >= 0 && row < rows.size() && col >= 0 && col < columns) {
            return rows.get(row).get(col);
        }
        return "";
    }

    /**
     * Добавить строку
     */
    public void addRow(List<String> values) {
        if (values.size() != columns) {
            throw new IllegalArgumentException("Количество значений должно совпадать с количеством колонок");
        }
        rows.add(new ArrayList<>(values));
    }

    /**
     * Удалить строку
     */
    public void removeRow(int index) {
        if (index >= 0 && index < rows.size()) {
            rows.remove(index);
        }
    }

    /**
     * Добавить колонку
     */
    public void addColumn(String defaultValue) {
        for (List<String> row : rows) {
            row.add(defaultValue);
        }
        columns++;
    }

    /**
     * Экспорт в Markdown формат
     */
    @Override
    public JSONObject toJson() {
        JSONObject json = super.toJson();
        try {
            json.put("columns", columns);
            json.put("caption", caption);
            json.put("hasHeader", hasHeader);
            JSONArray rowsArr = new JSONArray();
            for (List<String> row : rows) {
                JSONArray r = new JSONArray();
                for (String cell : row) r.put(cell);
                rowsArr.put(r);
            }
            json.put("rows", rowsArr);
        } catch (Exception ignored) {}
        return json;
    }

    public static TableBlock fromJson(JSONObject json, long timestamp) {
        int cols = json.optInt("columns", 1);
        JSONArray rowsArr = json.optJSONArray("rows");
        int rowCount = rowsArr != null ? rowsArr.length() : 1;
        String savedId = json.optString("id", null);
        TableBlock b = new TableBlock(rowCount, cols, timestamp);
        if (savedId != null) b.id = savedId;
        b.caption = json.optString("caption", null);
        b.hasHeader = json.optBoolean("hasHeader", false);
        if (rowsArr != null) {
            b.rows.clear();
            for (int i = 0; i < rowsArr.length(); i++) {
                JSONArray r = rowsArr.optJSONArray(i);
                List<String> row = new ArrayList<>();
                if (r != null) {
                    for (int j = 0; j < r.length(); j++) row.add(r.optString(j, ""));
                }
                b.rows.add(row);
            }
        }
        b.applyBaseJson(json);
        return b;
    }

    @Override
    public String toMarkdown() {
        StringBuilder sb = new StringBuilder();
        
        if (caption != null && !caption.isEmpty()) {
            sb.append("**").append(caption).append("**\n\n");
        }
        
        for (int i = 0; i < rows.size(); i++) {
            List<String> row = rows.get(i);
            sb.append("|");
            for (String cell : row) {
                sb.append(" ").append(cell).append(" |");
            }
            sb.append("\n");
            
            // Добавляем разделитель после заголовка
            if (i == 0 && hasHeader) {
                sb.append("|");
                for (int j = 0; j < columns; j++) {
                    sb.append("---|");
                }
                sb.append("\n");
            }
        }
        
        return sb.toString();
    }

    /**
     * Экспорт в CSV формат
     */
    public String toCSV() {
        StringBuilder sb = new StringBuilder();
        for (List<String> row : rows) {
            sb.append(String.join(",", row)).append("\n");
        }
        return sb.toString();
    }

    /**
     * Получить количество строк
     */
    public int getRowCount() {
        return rows.size();
    }
}
