package com.example.lector.models;

import com.example.lector.utils.NumberUtils;

/**
 * Блок математического выражения.
 * Преобразует устные формулы в структурированный вид.
 * Пример: "два плюс три равно пять" → "2 + 3 = 5"
 */
public class MathBlock extends ContentBlock {
    private String originalText;      // Как было сказано
    private String latexExpression;   // LaTeX представление
    private String plainExpression;   // Простой текст (2+3=5)
    private MathType mathType;        // Тип выражения

    public MathBlock(String originalText, long timestamp) {
        super(timestamp);
        this.originalText = originalText;
        this.plainExpression = parseToPlain(originalText);
        this.latexExpression = parseToLatex(originalText);
        this.mathType = detectMathType(originalText);
    }

    private String parseToPlain(String text) {
        // Упрощенный парсер - будет заменен на полноценный MathAssistant
        String result = text.toLowerCase();
        result = result.replace("плюс", "+");
        result = result.replace("минус", "-");
        result = result.replace("умножить на", "*");
        result = result.replace("разделить на", "/");
        result = result.replace("равно", "=");
        result = result.replace("в степени", "^");
        result = result.replace("корень из", "sqrt(");
        result = result.replace("дробь", "/");
        
        // Замена русских чисел на арабские (упрощенно)
        result = NumberUtils.russianToArabic(result);
        
        return result;
    }

    private String parseToLatex(String text) {
        // Конвертация в LaTeX для красивого отображения
        String plain = parseToPlain(text);
        plain = plain.replace("+", " + ");
        plain = plain.replace("-", " - ");
        plain = plain.replace("*", " \\cdot ");
        plain = plain.replace("/", " \\div ");
        plain = plain.replace("=", " = ");
        plain = plain.replace("^", "^{");
        plain = plain.replace("sqrt(", "\\sqrt{");
        return "$" + plain + "$";
    }

    private MathType detectMathType(String text) {
        String lower = text.toLowerCase();
        if (lower.contains("степень") || lower.contains("^")) return MathType.POWER;
        if (lower.contains("корень")) return MathType.SQRT;
        if (lower.contains("дробь")) return MathType.FRACTION;
        if (lower.contains("интеграл")) return MathType.INTEGRAL;
        if (lower.contains("производная")) return MathType.DERIVATIVE;
        if (lower.contains("уравнение") || lower.contains("=")) return MathType.EQUATION;
        return MathType.EXPRESSION;
    }

    @Override
    public BlockType getType() {
        return BlockType.MATH;
    }

    public String getOriginalText() { return originalText; }
    public void setOriginalText(String originalText) { this.originalText = originalText; }
    public String getLatexExpression() { return latexExpression; }
    public void setLatexExpression(String latexExpression) { this.latexExpression = latexExpression; }
    public String getPlainExpression() { return plainExpression; }
    public void setPlainExpression(String plainExpression) { this.plainExpression = plainExpression; }
    public MathType getMathType() { return mathType; }

    @Override
    public String toMarkdown() {
        return "```\n" + plainExpression + "\n```";
    }
}

/**
 * Типы математических выражений
 */
enum MathType {
    EXPRESSION,  // Простое выражение
    EQUATION,    // Уравнение
    POWER,       // Степень
    SQRT,        // Корень
    FRACTION,    // Дробь
    INTEGRAL,    // Интеграл
    DERIVATIVE   // Производная
}
