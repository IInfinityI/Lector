package com.example.lector.models;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * Блок заголовка (H1, H2 и т.д.)
 * Используется для структурирования конспекта.
 */
public class HeadingBlock extends ContentBlock implements BlockSerializer {
    private String text;
    private int level; // 1 = H1, 2 = H2, и т.д.

    public HeadingBlock(String text, long timestamp, int level) {
        super(timestamp);
        this.text = text;
        this.level = Math.max(1, Math.min(6, level)); // Ограничиваем от 1 до 6
    }

    @Override
    public BlockType getType() {
        return BlockType.HEADING;
    }

    public String getText() { return text; }
    public void setText(String text) { this.text = text; }
    public int getLevel() { return level; }
    public void setLevel(int level) { this.level = level; }

    @Override
    public JSONObject toJson() {
        JSONObject json = super.toJson();
        try {
            json.put("text", getText());
            json.put("level", getLevel());
        } catch (Exception ignored) {}
        return json;
    }

    public static HeadingBlock fromJson(JSONObject json, long timestamp) {
        String savedId = json.optString("id", null);
        HeadingBlock b = new HeadingBlock(json.optString("text", ""), timestamp,
            json.optInt("level", 1));
        if (savedId != null) b.id = savedId;
        b.applyBaseJson(json);
        return b;
    }

    @Override
    public String toMarkdown() {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < level; i++) {
            sb.append("#");
        }
        sb.append(" ").append(text);
        return sb.toString();
    }
}

