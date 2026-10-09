package com.example.lector.models;

/**
 * Блок подзаголовка (алиас для HeadingBlock с уровнем 2)
 */
class SubheadingBlock extends HeadingBlock {
    // Сериализация наследуется от HeadingBlock (type=SUBHEADING различается реестром)
    public SubheadingBlock(String text, long timestamp) {
        super(text, timestamp, 2);
    }

    @Override
    public BlockType getType() {
        return BlockType.SUBHEADING;
    }
}
