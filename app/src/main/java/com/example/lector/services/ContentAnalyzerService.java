package com.example.lector.services;

import android.content.Context;
import android.util.Log;

import com.example.lector.models.BlockType;
import com.example.lector.models.ContentBlock;
import com.example.lector.models.HeadingBlock;
import com.example.lector.models.Lecture;
import com.example.lector.models.MathBlock;
import com.example.lector.models.ParagraphBlock;
import com.example.lector.models.SubheadingBlock;
import com.example.lector.models.TextBlock;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Сервис для анализа текста и создания структурированных блоков.
 * Распознает команды для создания заголовков, абзацев, математических выражений.
 */
public class ContentAnalyzerService {
    private static final String TAG = "ContentAnalyzer";
    
    // Паттерны для распознавания команд форматирования
    private static final Pattern HEADING_PATTERN = Pattern.compile(
        "^(заголовок|header|h1)\\s*[:\\-]?\\s*(.+)",
        Pattern.CASE_INSENSITIVE
    );
    
    private static final Pattern SUBHEADING_PATTERN = Pattern.compile(
        "^(подзаголовок|subheader|подпункт|h2)\\s*[:\\-]?\\s*(.+)",
        Pattern.CASE_INSENSITIVE
    );
    
    private static final Pattern PARAGRAPH_PATTERN = Pattern.compile(
        "^(абзац|параграф|paragraph|p)\\s*[:\\-]?\\s*(.+)",
        Pattern.CASE_INSENSITIVE
    );
    
    // Паттерны для математики
    private static final Pattern MATH_PATTERN = Pattern.compile(
        "(два|три|четыре|пять|шесть|семь|восемь|девять|десять|ноль|" +
        "плюс|минус|умножить|разделить|равно|степень|корень|дробь|" +
        "one|two|three|four|five|six|seven|eight|nine|ten|zero|" +
        "plus|minus|multiply|divide|equals|power|sqrt|fraction)",
        Pattern.CASE_INSENSITIVE
    );

    public ContentAnalyzerService() {
    }

    /**
     * Проанализировать текст и создать соответствующий блок контента
     */
    public ContentBlock analyzeText(String text, long timestamp) {
        if (text == null || text.trim().isEmpty()) {
            return null;
        }

        String trimmedText = text.trim();
        
        // Проверяем на команду заголовка
        Matcher headingMatcher = HEADING_PATTERN.matcher(trimmedText);
        if (headingMatcher.find()) {
            String content = headingMatcher.group(2);
            Log.d(TAG, "Создан заголовок: " + content);
            return new HeadingBlock(content, timestamp, 1);
        }
        
        // Проверяем на команду подзаголовка
        Matcher subheadingMatcher = SUBHEADING_PATTERN.matcher(trimmedText);
        if (subheadingMatcher.find()) {
            String content = subheadingMatcher.group(2);
            Log.d(TAG, "Создан подзаголовок: " + content);
            return new SubheadingBlock(content, timestamp);
        }
        
        // Проверяем на команду абзаца
        Matcher paragraphMatcher = PARAGRAPH_PATTERN.matcher(trimmedText);
        if (paragraphMatcher.find()) {
            String content = paragraphMatcher.group(2);
            Log.d(TAG, "Создан абзац: " + content);
            ParagraphBlock block = new ParagraphBlock(content, timestamp);
            block.setType(BlockType.PARAGRAPH);
            return block;
        }
        
        // Проверяем на математическое выражение
        if (isMathExpression(trimmedText)) {
            Log.d(TAG, "Обнаружена математика: " + trimmedText);
            return new MathBlock(trimmedText, timestamp);
        }
        
        // Обычный текстовый блок
        Log.d(TAG, "Создан текстовый блок: " + trimmedText);
        return new TextBlock(trimmedText, timestamp);
    }

    /**
     * Проверить, является ли текст математическим выражением
     */
    private boolean isMathExpression(String text) {
        // Проверяем наличие математических ключевых слов
        Matcher mathMatcher = MATH_PATTERN.matcher(text);
        boolean hasMathKeywords = mathMatcher.find();
        
        // Проверяем наличие цифр и математических операторов
        boolean hasNumbers = text.matches(".*\\d+.*");
        boolean hasOperators = text.contains("+") || text.contains("-") || 
                               text.contains("=") || text.contains("*") || 
                               text.contains("/") || text.contains("^");
        
        // Математикой считаем если есть ключевые слова И (цифры ИЛИ операторы)
        return hasMathKeywords && (hasNumbers || hasOperators);
    }

    /**
     * Обработать поток текста и разбить на блоки
     */
    public ContentBlock[] processTextStream(String text, long baseTimestamp) {
        if (text == null || text.isEmpty()) {
            return new ContentBlock[0];
        }

        // Разбиваем текст на предложения
        String[] sentences = text.split("(?<=[.!?])\\s+");
        ContentBlock[] blocks = new ContentBlock[sentences.length];
        
        long timestampOffset = 0;
        for (int i = 0; i < sentences.length; i++) {
            String sentence = sentences[i].trim();
            if (!sentence.isEmpty()) {
                blocks[i] = analyzeText(sentence, baseTimestamp + timestampOffset);
                timestampOffset += 1000; // Примерно 1 секунда на предложение
            }
        }
        
        return blocks;
    }

    /**
     * Обновить существующий блок новым текстом (для уточнения)
     */
    public void updateBlock(ContentBlock block, String newText) {
        if (block == null || newText == null) {
            return;
        }

        if (block instanceof TextBlock) {
            TextBlock textBlock = (TextBlock) block;
            // Добавляем новый текст к существующему
            textBlock.setText(textBlock.getText() + " " + newText);
        }
    }

    /**
     * Пометить блок как непроверенный (требует глубокого анализа)
     */
    public void markAsUnverified(ContentBlock block, String reason) {
        if (block != null) {
            block.setVerified(false);
            block.addWarning(reason);
            Log.d(TAG, "Блок помечен как непроверенный: " + reason);
        }
    }
}
