package com.example.lector.plugin;

import com.example.lector.models.ContentBlock;

/**
 * Команда форматирования, распознаваемая в устной речи.
 * Пример встроенной команды: "заголовок ..." → HeadingBlock.
 * Плагины могут добавлять собственные команды ("определение ...", "теорема ...").
 */
public interface FormattingCommand {

    /** Ключевое слово-триггер в нижнем регистре, напр. "заголовок". */
    String keyword();

    /** Создаёт блок из остатка фразы или возвращает null. */
    ContentBlock execute(String argumentText, long timestampMs);
}
