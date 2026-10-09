package com.example.lector.models;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class ParagraphBlock extends TextBlock implements BlockSerializer {
    private boolean isBold;
    private boolean isItalic;
    private TextAlignment alignment;

    public ParagraphBlock(String text, long timestamp) {
        super(text, timestamp);
        this.isBold = false;
        this.isItalic = false;
        this.alignment = TextAlignment.LEFT;
    }

    @Override
    public BlockType getType() {
        return BlockType.PARAGRAPH;
    }

    public boolean isBold() { return isBold; }
    public void setBold(boolean bold) { isBold = bold; }
    public boolean isItalic() { return isItalic; }
    public void setItalic(boolean italic) { isItalic = italic; }
    public TextAlignment getAlignment() { return alignment; }
    public void setAlignment(TextAlignment alignment) { this.alignment = alignment; }

    @Override
    public JSONObject toJson() {
        JSONObject json = super.toJson();
        try {
            json.put("isBold", isBold);
            json.put("isItalic", isItalic);
            json.put("alignment", alignment.name());
        } catch (Exception ignored) {}
        return json;
    }

    public static ParagraphBlock fromJson(JSONObject json, long timestamp) {
        String savedId = json.optString("id", null);
        ParagraphBlock b = new ParagraphBlock(json.optString("text", ""), timestamp);
        if (savedId != null) b.id = savedId;
        b.setBold(json.optBoolean("isBold", false));
        b.setItalic(json.optBoolean("isItalic", false));
        String al = json.optString("alignment", null);
        if (al != null) {
            try { b.setAlignment(TextAlignment.valueOf(al)); } catch (Exception ignored) {}
        }
        b.applyBaseJson(json);
        return b;
    }

    @Override
    public String toMarkdown() {
        String text = getText();
        
        if (isBold && isItalic) {
            text = "***" + text + "***";
        } else if (isBold) {
            text = "**" + text + "**";
        } else if (isItalic) {
            text = "*" + text + "*";
        }
        
        return text;
    }
