package com.example.lector.plugin.builtin;

import com.example.lector.models.BlockSerializer;
import com.example.lector.models.BlockType;
import com.example.lector.models.ContentBlock;

import org.json.JSONObject;

/**
 * Кастомный блок мода «SummaryBot» — авто-резюме лекции.
 *
 * Тип блока для JSON/реестра: {@code SUMMARY} (ядро его не знает — весь цикл
 * жизни блока принадлежит моду через Plugin API v1.0–v1.4).
 * Хранит текст резюме в поле {@code lines}; статус пересборки определяется
 * маркером «✍ Резюме:», поэтому повторная обработка ЗАМЕНЯЕТ блок, а не дублирует.
 */
public class SummaryBlock extends ContentBlock implements BlockSerializer {

    public static final String TYPE_KEY = "SUMMARY";

    private String lines;

    public SummaryBlock(String lines, long timestamp) {
        super(timestamp);
        this.lines = lines == null ? "" : lines;
    }

    @Override
    public BlockType getType() {
        return BlockType.TEXT; // базовый fallback для старого UI
    }

    @Override
    public String getTypeKey() {
        return TYPE_KEY; // реальный тип для JSON и реестра рендереров
    }

    public String getLines() { return lines; }

    public void setLines(String lines) {
        this.lines = lines == null ? "" : lines;
    }

    @Override
    public JSONObject toJson() {
        JSONObject json = super.toJson(); // служебные поля + type=SUMMARY из getTypeKey()
        try {
            json.put("lines", lines);
        } catch (Exception ignored) { }
        return json;
    }

    public static SummaryBlock fromJson(JSONObject json, long timestamp) {
        SummaryBlock b = new SummaryBlock(json.optString("lines", ""), timestamp);
        String savedId = json.optString("id", null);
        if (savedId != null) b.id = savedId;
        b.applyBaseJson(json);
        return b;
    }

    /** Markdown: цитата с текстом резюме. */
    @Override
    public String toMarkdown() {
        return "> " + lines;
    }
}
