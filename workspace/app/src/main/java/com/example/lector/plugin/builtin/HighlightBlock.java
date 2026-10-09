package com.example.lector.plugin.builtin;

import com.example.lector.models.BlockSerializer;
import com.example.lector.models.BlockType;
import com.example.lector.models.ContentBlock;

import org.json.JSONObject;

/**
 * Демонстрационный кастомный блок от плагина «Highlighter» —
 * выделенная ключевая мысль/определение лекции.
 * Показывает, как мод добавляет новый тип блока, не трогая код ядра.
 */
public class HighlightBlock extends ContentBlock implements BlockSerializer {

    public static final String TYPE_KEY = "HIGHLIGHT";

    private String text;
    private String color; // "yellow", "green", "blue"… задаётся плагином

    public HighlightBlock(String text, long timestamp) {
        this(text, timestamp, "yellow");
    }

    public HighlightBlock(String text, long timestamp, String color) {
        super(timestamp);
        this.text = text;
        this.color = color;
    }

    @Override
    public BlockType getType() {
        return BlockType.TEXT; // базовый fallback для старого UI
    }

    @Override
    public String getTypeKey() {
        return TYPE_KEY; // реальный тип для JSON и реестра
    }

    public String getText() { return text; }
    public void setText(String text) { this.text = text; }
    public String getColor() { return color; }
    public void setColor(String color) { this.color = color; }

    /** ARGB-цвет выделения по имени (расширяется плагинами). */
    public int parseColor() {
        switch (color == null ? "yellow" : color.toLowerCase()) {
            case "green":  return 0x664CAF50;
            case "blue":   return 0x662196F3;
            case "red":    return 0x66F44336;
            case "pink":   return 0x66E91E63;
            case "yellow":
            default:       return 0x66FFEB3B;
        }
    }

    @Override
    public JSONObject toJson() {
        JSONObject json = super.toJson(); // служебные поля + type=HIGHLIGHT из getTypeKey()
        try {
            json.put("text", text);
            json.put("color", color);
        } catch (Exception ignored) {}
        return json;
    }

    public static HighlightBlock fromJson(JSONObject json, long timestamp) {
        HighlightBlock b = new HighlightBlock(json.optString("text", ""), timestamp,
            json.optString("color", "yellow"));
        String savedId = json.optString("id", null);
        if (savedId != null) b.id = savedId;
        b.applyBaseJson(json);
        return b;
    }

    @Override
    public String toMarkdown() {
        return "> [!NOTE]\n> **" + text + "**";
    }
}
