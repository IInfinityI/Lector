package com.example.lector.models;

/**
 * Перечисление всех типов блоков контента.
 */
public enum BlockType {
    TEXT,           // Обычный текст транскрибации
    HEADING,        // Заголовок (H1)
    SUBHEADING,     // Подзаголовок (H2)
    PARAGRAPH,      // Абзац с форматированием
    MATH,           // Математическое выражение
    TABLE,          // Таблица
    DRAWING,        // Нарисованная схема
    GRAPH,          // График
    IMAGE,          // Фотография (доска, слайд)
    SPEAKER_CHANGE  // Смена спикера
}
