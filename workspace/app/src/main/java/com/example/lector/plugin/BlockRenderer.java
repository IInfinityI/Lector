package com.example.lector.plugin;

import android.view.View;
import android.widget.TextView;

import com.example.lector.models.ContentBlock;

/**
 * UI-слот плагина: способ отрисовать кастомный блок в редакторе,
 * не изменяя код ядра (аналог кастомного рендера предмета в GUI-модах игр).
 *
 * Плагин регистрирует рендерер вместе с типом блока через
 * {@link PluginRegistry#registerBlockRenderer(String, BlockRenderer)}.
 */
public interface BlockRenderer {

    /** Привязать данные блока к элементам стандартной ячейки списка. */
    void render(ContentBlock block, TextView timestampView, TextView contentView, View itemView);

    /** Рендер для экспорта в Markdown (строка, представляющая блок). */
    default String renderMarkdown(ContentBlock block) {
        return block.toMarkdown();
    }
}
