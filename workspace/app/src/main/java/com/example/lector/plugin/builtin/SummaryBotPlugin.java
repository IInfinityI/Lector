package com.example.lector.plugin.builtin;

import android.widget.TextView;
import android.view.View;

import com.example.lector.models.ContentBlock;
import com.example.lector.models.GraphBlock;
import com.example.lector.models.Lecture;
import com.example.lector.models.MathBlock;
import com.example.lector.models.TableBlock;
import com.example.lector.models.TextBlock;
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

/**
 * Мод «SummaryBot» — авто-резюме лекции.
 *
 * Возможности (только Plugin API v1.0–v1.5, код ядра не изменён):
 *  • PostProcessor: при остановке записи мод сам вставляет в начало конспекта
 *    блок «✍ Резюме: …» — первые N предложений + счётчики
 *    («· формул: 3 · таблиц: 1 · задач: 5»).
 *  • ToolbarAction (v1.3): кнопка «Резюме» в тулбаре редактора — пересборка
 *    одним тапом; повторная обработка ЗАМЕНЯЕТ резюме, а не дублирует его.
 *  • Settings (v1.4): длина резюме — число предложений (1–10).
 */
public class SummaryBotPlugin implements LectorPlugin {

    public static final String ID = "builtin.summarybot";

    /** Маркер строки резюме внутри TextBlock (для замены, а не дублирования). */
    public static final String SUMMARY_PREFIX = "✍ Резюме:";

    private static final PluginSettings.SettingDescriptor SET_SENTENCES =
        PluginSettings.SettingDescriptor.intVal("summary_sentences",
            "Длина резюме (число предложений, 1–10)", 3);

    private PluginContext currentContext;

    @Override
    public String getId() { return ID; }

    @Override
    public String getName() { return "SummaryBot"; }

    @Override
    public String getVersion() { return "1.0.0"; }

    @Override
    public String getDescription() {
        return "Авто-резюме: при остановке записи в начало конспекта вставляется "
            + "блок «✍ Резюме: …» (первые N предложений + счётчики формул/таблиц/"
            + "задач). Кнопка «Резюме» пересобирает его одним тапом без дублей.";
    }

    @Override
    public List<PluginSettings.SettingDescriptor> getSettings() {
        return Arrays.asList(SET_SENTENCES);
    }

    @Override
    public void onInit(PluginContext context) { this.currentContext = context; }

    public void bindContext(PluginContext ctx) { this.currentContext = ctx; }

    @Override
    public void onRegister(PluginRegistry registry) {
        // Резюме живёт в обычном TextBlock, но подсвечивается серой карточкой,
        // если это строка резюме (рендерер вешается на TEXT только через кастомный
        // тип — поэтому используем отдельный тип блока SUMMARY).
        registry.registerBlockType(SummaryBlock.TYPE_KEY, this,
            new PluginRegistry.BlockFactory() {
                @Override
                public ContentBlock create(long timestamp) {
                    return new SummaryBlock("", timestamp);
                }

                @Override
                public ContentBlock fromJson(org.json.JSONObject json, long timestamp) {
                    return SummaryBlock.fromJson(json, timestamp);
                }
            });

        registry.registerBlockRenderer(SummaryBlock.TYPE_KEY, new BlockRenderer() {
            @Override
            public void render(ContentBlock block, TextView timestampView,
                               TextView contentView, View itemView) {
                if (block instanceof SummaryBlock) {
                    contentView.setText(block.toMarkdown());
                    contentView.setBackgroundColor(0x14000000);
                } else {
                    contentView.setText(block.toMarkdown());
                }
            }

            @Override
            public String renderMarkdown(ContentBlock block) {
                return block.toMarkdown();
            }
        });
    }

    // ===== Настройки =====

    int sentencesSetting() {
        try {
            if (currentContext != null) {
                return clampSentences(
                    currentContext.getSettings().getInt("summary_sentences", 3));
            }
        } catch (Exception ignored) { }
        return 3;
    }

    public static int clampSentences(int n) {
        return Math.max(1, Math.min(10, n));
    }

    // ===== Пост-процессор: вставка/замена резюме при остановке записи =====

    @Override
    public List<PostProcessor> getPostProcessors() {
        return Arrays.<PostProcessor>asList(new PostProcessor() {
            @Override
            public String getName() { return "summarybot-insert"; }

            @Override
            public void process(Lecture lecture) {
                rebuild(lecture, sentencesSetting());
            }
        });
    }

    /**
     * Пересобрать резюме лекции: заменить существующий SummaryBlock в начале
     * либо вставить новый. Публичный статический метод — используется и тестами.
     */
    public static Lecture rebuild(Lecture lecture, int maxSentences) {
        if (lecture == null || lecture.getBlocks() == null) return lecture;
        List<ContentBlock> blocks = lecture.getBlocks();

        String text = buildSummaryText(lecture, clampSentences(maxSentences));

        int existing = -1;
        for (int i = 0; i < blocks.size(); i++) {
            if (blocks.get(i) instanceof SummaryBlock) { existing = i; break; }
        }
        if (existing >= 0) {
            SummaryBlock old = (SummaryBlock) blocks.get(existing);
            old.setLines(text);
            // резюме всегда в начале конспекта
            if (existing != 0) {
                blocks.remove(existing);
                blocks.add(0, old);
            }
        } else {
            long ts = blocks.isEmpty() ? 0 : Math.max(0, blocks.get(0).getTimestamp() - 1);
            blocks.add(0, new SummaryBlock(text, ts));
        }
        return lecture;
    }

    /** Текст резюме: «✍ Резюме: с1. с2. с3. · формул: 3 · таблиц: 1 · задач: 5». */
    public static String buildSummaryText(Lecture lecture, int maxSentences) {
        StringBuilder body = new StringBuilder();
        int sentences = 0;
        for (ContentBlock b : lecture.getBlocks()) {
            if (b instanceof SummaryBlock) continue;
            String plain = plainTextOf(b);
            if (plain == null || plain.trim().isEmpty()) continue;
            for (String s : splitSentences(plain)) {
                body.append(s).append(". ");
                if (++sentences >= maxSentences) break;
            }
            if (sentences >= maxSentences) break;
        }
        String counters = " · формул: " + countType(lecture, MathBlock.class)
            + " · таблиц: " + countType(lecture, TableBlock.class)
            + " · графиков: " + countType(lecture, GraphBlock.class)
            + " · задач: " + countTasks(lecture);
        String trimmed = body.toString().trim();
        if (trimmed.isEmpty()) {
            return SUMMARY_PREFIX + " пусто" + counters;
        }
        return SUMMARY_PREFIX + " " + trimmed + counters;
    }

    /** Задачи считаются по TODO-пунктам мода TaskMaster (моды работают поверх друг друга). */
    static int countTasks(Lecture lecture) {
        int n = 0;
        for (ContentBlock b : lecture.getBlocks()) {
            if (b instanceof TodoBlock) n += ((TodoBlock) b).getItems().size();
        }
        return n;
    }

    private static int countType(Lecture lecture, Class<?> cls) {
        int n = 0;
        for (ContentBlock b : lecture.getBlocks()) {
            if (cls.isInstance(b)) n++;
        }
        return n;
    }

    private static String plainTextOf(ContentBlock b) {
        return ObsidianVaultPlugin.blockPlain(b);
    }

    /** Разбиение на предложения (русские/латинские точки, !, ?). */
    public static List<String> splitSentences(String text) {
        List<String> out = new ArrayList<>();
        if (text == null) return out;
        String[] parts = text.split("(?<=[.!?])\\s+");
        for (String p : parts) {
            String s = p.trim().replaceAll("[.!?]+$", "").trim();
            if (s.length() > 2) out.add(s);
        }
        return out;
    }

    // ===== Кнопка «Резюме» в тулбаре редактора (v1.3) =====

    @Override
    public List<ToolbarAction> getToolbarActions() {
        return Arrays.<ToolbarAction>asList(new ToolbarAction() {
            @Override
            public String getLabel() { return "Резюме"; }

            @Override
            public int getOrder() { return 40; }

            @Override
            public void onClick(Lecture lecture, PluginContext context) {
                if (lecture == null) return;
                int n = 3;
                try {
                    n = clampSentences(context.getSettings().getInt("summary_sentences", 3));
                } catch (Exception ignored) { }
                rebuild(lecture, n);
                android.widget.Toast.makeText(context.getAppContext(),
                    "Резюме обновлено (" + n + " предл.)",
                    android.widget.Toast.LENGTH_SHORT).show();
            }
        });
    }

    @Override
    public void subscribe(EventBus bus) { /* не требуется */ }
}
