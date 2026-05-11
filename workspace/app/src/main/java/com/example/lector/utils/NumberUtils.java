package com.example.lector.utils;

import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Утилиты для работы с числами и математическими выражениями.
 * Преобразование русских числительных в арабские цифры.
 */
public class NumberUtils {

    private static final Map<String, Integer> NUMBERS = new HashMap<>();
    
    static {
        // Простые числа
        NUMBERS.put("ноль", 0);
        NUMBERS.put("один", 1);
        NUMBERS.put("одна", 1);
        NUMBERS.put("одно", 1);
        NUMBERS.put("два", 2);
        NUMBERS.put("две", 2);
        NUMBERS.put("три", 3);
        NUMBERS.put("четыре", 4);
        NUMBERS.put("пять", 5);
        NUMBERS.put("шесть", 6);
        NUMBERS.put("семь", 7);
        NUMBERS.put("восемь", 8);
        NUMBERS.put("девять", 9);
        NUMBERS.put("десять", 10);
        NUMBERS.put("одиннадцать", 11);
        NUMBERS.put("двенадцать", 12);
        NUMBERS.put("тринадцать", 13);
        NUMBERS.put("четырнадцать", 14);
        NUMBERS.put("пятнадцать", 15);
        NUMBERS.put("шестнадцать", 16);
        NUMBERS.put("семнадцать", 17);
        NUMBERS.put("восемнадцать", 18);
        NUMBERS.put("девятнадцать", 19);
        NUMBERS.put("двадцать", 20);
        NUMBERS.put("тридцать", 30);
        NUMBERS.put("сорок", 40);
        NUMBERS.put("пятьдесят", 50);
        NUMBERS.put("шестьдесят", 60);
        NUMBERS.put("семьдесят", 70);
        NUMBERS.put("восемьдесят", 80);
        NUMBERS.put("девяносто", 90);
        NUMBERS.put("сто", 100);
        NUMBERS.put("двести", 200);
        NUMBERS.put("триста", 300);
        NUMBERS.put("четыреста", 400);
        NUMBERS.put("пятьсот", 500);
        NUMBERS.put("шестьсот", 600);
        NUMBERS.put("семьсот", 700);
        NUMBERS.put("восемьсот", 800);
        NUMBERS.put("девятьсот", 900);
        
        // Порядковые числительные
        NUMBERS.put("первый", 1);
        NUMBERS.put("второй", 2);
        NUMBERS.put("третий", 3);
        NUMBERS.put("четвертый", 4);
        NUMBERS.put("пятый", 5);
    }

    /**
     * Преобразует русские числительные в тексте в арабские цифры.
     * Пример: "два плюс три" → "2 + 3"
     */
    public static String russianToArabic(String text) {
        if (text == null || text.isEmpty()) return text;
        
        String result = text;
        
        // Сортируем ключи по длине (от длинных к коротким) чтобы избежать частичных замен
        java.util.List<String> keys = new java.util.ArrayList<>(NUMBERS.keySet());
        keys.sort((a, b) -> b.length() - a.length());
        
        for (String key : keys) {
            // Используем regex для замены только полных слов
            Pattern pattern = Pattern.compile("\\b" + key + "\\b", Pattern.CASE_INSENSITIVE);
            Matcher matcher = pattern.matcher(result);
            result = matcher.replaceAll(String.valueOf(NUMBERS.get(key)));
        }
        
        return result;
    }

    /**
     * Парсит составное число из русских слов.
     * Пример: "двадцать один" → 21
     */
    public static int parseCompositeNumber(String text) {
        if (text == null || text.isEmpty()) return 0;
        
        String[] words = text.toLowerCase().split("\\s+");
        int result = 0;
        int temp = 0;
        
        for (String word : words) {
            Integer value = NUMBERS.get(word);
            if (value == null) continue;
            
            if (value >= 100) {
                temp = (temp == 0 ? 1 : temp) * value;
            } else if (value >= 10 && value < 100) {
                temp += value;
            } else {
                temp += value;
            }
        }
        
        result += temp;
        return result;
    }

    /**
     * Проверяет, содержит ли текст русские числительные.
     */
    public static boolean containsRussianNumbers(String text) {
        if (text == null || text.isEmpty()) return false;
        
        String lower = text.toLowerCase();
        for (String key : NUMBERS.keySet()) {
            if (lower.contains(key)) return true;
        }
        return false;
    }
}
