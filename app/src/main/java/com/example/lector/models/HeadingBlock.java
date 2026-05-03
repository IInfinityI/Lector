package com.example.lector.models;

import java.util.ArrayList;
import java.util.List;

/**
 * Блок заголовка (H1, H2 и т.д.)
 * Используется для структурирования конспекта.
 */
public class HeadingBlock extends ContentBlock {
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
    public String toMarkdown() {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < level; i++) {
            sb.append("#");
        }
        sb.append(" ").append(text);
        return sb.toString();
    }
}

/**
 * Блок подзаголовка (алиас для HeadingBlock с уровнем 2)
 */
class SubheadingBlock extends HeadingBlock {
    public SubheadingBlock(String text, long timestamp) {
        super(text, timestamp, 2);
    }

    @Override
    public BlockType getType() {
        return BlockType.SUBHEADING;
    }
}

/**
 * Блок абзаца с форматированием
 */
class ParagraphBlock extends TextBlock {
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
}

/**
 * Выравнивание текста
 */
enum TextAlignment {
    LEFT,
    CENTER,
    RIGHT,
    JUSTIFY
}
