package com.example.lector.plugin.builtin;

import android.graphics.Typeface;
import android.text.SpannableString;
import android.text.style.RelativeSizeSpan;
import android.view.View;
import android.widget.TextView;

import com.example.lector.models.ContentBlock;
import com.example.lector.models.Lecture;
import com.example.lector.models.TextBlock;
import com.example.lector.plugin.BlockHandler;
import com.example.lector.plugin.BlockRenderer;
import com.example.lector.plugin.EventBus;
import com.example.lector.plugin.LectorPlugin;
import com.example.lector.plugin.PluginContext;
import com.example.lector.plugin.PluginRegistry;
import com.example.lector.plugin.PluginSettings;
import com.example.lector.plugin.PostProcessor;
import com.example.lector.plugin.ToolbarAction;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Мод «TaskMaster» — голосовые задачи (чек-лист TODO).
 *
 * Возможности (реализованы только через Plugin API v1.0–v1.5, код ядра не изменён):
 *  • BlockHandler: голосовые команды при диктовке лекции —
 *      «задача выучить интегральный множитель», «не забыть принести тетрадь»,
 *      «дз параграф 12», «todo …», «таск …» → появляется чек-лист TODO с ☐/☑.
 *  • Новый тип блока TodoBlock (TYPE_KEY="TODO") со своим JSON:
 *    статус выполнения каждого пункта сохраняется между запусками.
 *  • BlockRenderer (v1.1): оранжевая карточка «☑ Задачи (N активных)»
 *    в редакторе + Markdown-экспорт GitHub-чекбоксами - [x] / - [ ].
 *  • PostProcessor: подряд продиктованные задачи склеиваются в один список
 *    при сохранении лекции (не засоряют конспект отдельными блоками).
 *  • ToolbarAction (v1.3): кнопка «✓Done» — отметить все задачи выполненными
 *    одним тапом (обратимо: повторное нажатие ничего не ломает).
 *  • Settings (v1.4): пользователь может поменять слово-триггер задач
 *    на экране «Моды» (настройка «task_trigger»).
 */
public class TaskMasterPlugin implements LectorPlugin {

    public static final String ID = "builtin.taskmaster";

    /** Триггер по умолчанию (если пользователь не поменял настройку). */
    public static final String DEFAULT_TRIGGER = "задача";

    // ===== Настройки (v1.4) =====

    private static final PluginSettings.SettingDescriptor SET_TRIGGER =
        PluginSettings.SettingDescriptor.string("task_trigger",
            "Слово-триггер задач (голосовая команда)", DEFAULT_TRIGGER);

    /** Контекст для чтения настроек (ядро вызывает getSettings/bind до использования). */
    private PluginContext currentContext;

    @Override
    public String getId() { return ID; }

    @Override
    public String getName() { return "TaskMaster"; }

    @Override
    public String getVersion() { return "1.0.0"; }

    @Override
    public String getDescription() {
        return "Голосовые задачи: команды «задача …», «не забыть …», «дз …» "
            + "превращаются в чек-лист TODO (оранжевая карточка, статус "
            + "сохраняется, подряд идущие задачи склеиваются, экспорт - [ ]/- [x]).";
    }

    @Override
    public List<PluginSettings.SettingDescriptor> getSettings() {
        return Arrays.asList(SET_TRIGGER);
    }

    @Override
    public void onInit(PluginContext context) {
        this.currentContext = context;
    }

    /** Ядро (v1.5) подвязывает контекст рефлексивно — как у ObsidianVault. */
    public void bindContext(PluginContext ctx) {
        this.currentContext = ctx;
    }

    @Override
    public void onRegister(PluginRegistry registry) {
        // 1. Новый тип блока TODO — ядро умеет только сериализовать его через фабрику.
        registry.registerBlockType(TodoBlock.TYPE_KEY, this,
            new PluginRegistry.BlockFactory() {
                @Override
                public ContentBlock create(long timestamp) {
                    return new TodoBlock(timestamp);
                }

                @Override
                public ContentBlock fromJson(org.json.JSONObject json, long timestamp) {
                    return TodoBlock.fromJson(json, timestamp);
                }
            });

        // 2. Оранжевая карточка «☑ Задачи (N активных)» + Markdown-чекбоксы (v1.1).
        registry.registerBlockRenderer(TodoBlock.TYPE_KEY, new BlockRenderer() {
            @Override
            public void render(ContentBlock block, TextView timestampView,
                               TextView contentView, View itemView) {
                if (block instanceof TodoBlock) {
                    TodoBlock todo = (TodoBlock) block;
                    SpannableString s = new SpannableString(renderCard(todo));
                    s.setSpan(new RelativeSizeSpan(1.05f), 0, 1, 0); // крупный ☑
                    contentView.setText(s);
                    contentView.setTypeface(null, Typeface.BOLD);
                    contentView.setBackgroundColor(0xFFFFF3E0); // оранжевая карточка
                    contentView.setTextColor(0xFFE65100);
                } else {
                    contentView.setText(block.toMarkdown());
                }
            }

            @Override
            public String renderMarkdown(ContentBlock block) {
                return block instanceof TodoBlock ? block.toMarkdown() : block.toMarkdown();
            }
        });
    }

    /** Текст карточки: «☑ Задачи (N активных)\n☐ пункт…\n☑ пункт…». */
    static String renderCard(TodoBlock todo) {
        StringBuilder sb = new StringBuilder();
        sb.append("☑ Задачи (").append(todo.activeCount()).append(" активных)");
        for (TodoItem i : todo.getItems()) {
            sb.append("\n").append(i.isDone() ? "☑ " : "☐ ").append(i.getText());
        }
        return sb.toString();
    }

    // ===== 3. Голосовые команды → TODO =====

    /** Пользовательский триггер из настройки v1.4 (по умолчанию «задача»). */
    String triggerWord() {
        try {
            if (currentContext != null) {
                String t = currentContext.getSettings()
                    .getString("task_trigger", DEFAULT_TRIGGER);
                if (t != null && !t.trim().isEmpty()) return t.trim().toLowerCase(Locale.ROOT);
            }
        } catch (Exception ignored) { }
        return DEFAULT_TRIGGER;
    }

    /**
     * Встроенные синонимы триггера (всегда работают) + слово из настройки.
     * Возвращает текст задачи без триггерного слова либо null, если фраза не задача.
     */
    public static String stripTrigger(String text, String customTrigger) {
        if (text == null) return null;
        String t = text.trim();
        if (t.isEmpty()) return null;
        String lower = t.toLowerCase(Locale.ROOT);

        String[] prefixes = {"задача", "задачи", "не забыть", "нельзя забыть",
                             "дз", "todo", "туду", "таск", "task"};
        List<String> all = new ArrayList<>(Arrays.asList(prefixes));
        if (customTrigger != null && !customTrigger.isEmpty()) {
            String c = customTrigger.toLowerCase(Locale.ROOT);
            if (!all.contains(c)) all.add(0, c);
        }
        for (String p : all) {
            if (lower.equals(p)) return null; // голая команда без текста
            if (lower.startsWith(p)) {
                String rest = t.substring(p.length());
                if (rest.isEmpty()) return null;
                char next = rest.charAt(0);
                if (Character.isLetterOrDigit(next)) continue; // «задачи-минимум» — не префикс
                rest = rest.replaceFirst("^[\\s:,.\\-—]+", "");
                return rest.isEmpty() ? null : rest;
            }
        }
        return null;
    }

    /** Перегрузка для тестов/блоков: текущий триггер мода. */
    public String stripTrigger(String text) {
        return stripTrigger(text, triggerWord());
    }

    /** Чистка хвостовых слов распознавания («задача … точка»). */
    static String cleanTaskText(String raw) {
        if (raw == null) return "";
        String s = raw.trim();
        s = s.replaceAll("(?i)\\s+(?:точка|новая строка|абзац)$", "");
        return s.trim();
    }

    @Override
    public List<BlockHandler> getBlockHandlers() {
        return Arrays.<BlockHandler>asList(new BlockHandler() {
            @Override
            public String getName() { return "taskmaster-todo"; }

            @Override
            public boolean canHandle(String text, long timestampMs) {
                return stripTrigger(text, triggerWord()) != null;
            }

            @Override
            public ContentBlock createBlock(String text, long timestampMs) {
                String body = cleanTaskText(stripTrigger(text, triggerWord()));
                TodoBlock b = new TodoBlock(timestampMs);
                b.addItem(new TodoItem(body));
                return b;
            }
        });
    }

    // ===== 4. Пост-процессор: склейка подряд идущих задач (при сохранении) =====

    @Override
    public List<PostProcessor> getPostProcessors() {
        return Arrays.<PostProcessor>asList(new PostProcessor() {
            @Override
            public String getName() { return "taskmaster-merge"; }

            @Override
            public void process(Lecture lecture) {
                mergeConsecutiveTodos(lecture);
            }
        });
    }

    /**
     * Склеивает соседние TODO-блоки и текстовые фразы-задачи в один чек-лист.
     * Публично и без Android-зависимостей — вызывается и из unit-тестов.
     */
    public static Lecture mergeConsecutiveTodos(Lecture lecture) {
        if (lecture == null || lecture.getBlocks() == null) return lecture;
        List<ContentBlock> src = new ArrayList<>(lecture.getBlocks());
        List<ContentBlock> out = new ArrayList<>();
        int i = 0;
        while (i < src.size()) {
            ContentBlock b = src.get(i);
            if (!(b instanceof TodoBlock)) {
                out.add(b);
                i++;
                continue;
            }
            TodoBlock merged = new TodoBlock(b.getTimestamp());
            
            for (TodoItem it : ((TodoBlock) b).getItems()) merged.addItem(it);
            int j = i + 1;
            int lastTask = j - 1; // последний поглощённый пункт-источник
            while (j < src.size()) {
                ContentBlock n = src.get(j);
                if (n instanceof TodoBlock) {
                    for (TodoItem it : ((TodoBlock) n).getItems()) merged.addItem(it);
                    j++; lastTask = j - 1;
                } else if (n instanceof TextBlock) {
                    String body = stripTrigger(((TextBlock) n).getText(), null);
                    if (body != null) {
                        merged.addItem(new TodoItem(cleanTaskText(body)));
                        j++; lastTask = j - 1;
                    } else {
                        // обычный абзац разрывает чек-лист: склеиваем только
                        // подряд продиктованные задачи
                        break;
                    }
                } else break;
            }
            out.add(merged);
            i = j;
        }
        lecture.setBlocks(out);
        return lecture;
    }

    // ===== 5. Кнопка «✓Done» в тулбаре редактора (v1.3) =====

    @Override
    public List<ToolbarAction> getToolbarActions() {
        return Arrays.<ToolbarAction>asList(new ToolbarAction() {
            @Override
            public String getLabel() { return "✓Done"; }

            @Override
            public int getOrder() { return 30; }

            @Override
            public boolean isVisible(Lecture lecture) {
                if (lecture == null || lecture.getBlocks() == null) return false;
                for (ContentBlock b : lecture.getBlocks()) {
                    if (b instanceof TodoBlock && ((TodoBlock) b).activeCount() > 0) {
                        return true;
                    }
                }
                return false;
            }

            @Override
            public void onClick(Lecture lecture, PluginContext context) {
                if (lecture == null) return;
                int done = 0;
                for (ContentBlock b : lecture.getBlocks()) {
                    if (b instanceof TodoBlock) {
                        for (TodoItem it : ((TodoBlock) b).getItems()) {
                            if (!it.isDone()) { it.setDone(true); done++; }
                        }
                    }
                }
                android.widget.Toast.makeText(context.getAppContext(),
                    "Задачи выполнены: " + done,
                    android.widget.Toast.LENGTH_SHORT).show();
            }
        });
    }

    @Override
    public void subscribe(EventBus bus) { /* статистика не требуется */ }
}
