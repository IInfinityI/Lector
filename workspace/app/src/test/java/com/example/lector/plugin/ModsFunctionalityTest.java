package com.example.lector.plugin;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;

import com.example.lector.models.ContentBlock;
import com.example.lector.models.Lecture;
import com.example.lector.models.MathBlock;
import com.example.lector.models.TextBlock;
import com.example.lector.plugin.builtin.SummaryBlock;
import com.example.lector.plugin.builtin.SummaryBotPlugin;
import com.example.lector.plugin.builtin.TaskMasterPlugin;
import com.example.lector.plugin.builtin.TodoBlock;
import com.example.lector.plugin.builtin.TodoItem;

import org.json.JSONObject;
import org.junit.Test;

import java.util.List;

/**
 * Функциональные тесты модов «TaskMaster» и «SummaryBot» (6 шт.):
 * голосовые триггеры, сериализация TODO, склейка чек-листов,
 * вставка/замена резюме, лимит длины резюме.
 * Тесты не требуют Android — проверяют чистую логику модов.
 */
public class ModsFunctionalityTest {

    private Lecture lectureWith(ContentBlock... blocks) {
        Lecture l = new Lecture("Матанализ", 0L);
        for (ContentBlock b : blocks) l.addBlock(b);
        return l;
    }

    // ===== 1. Триггеры TaskMaster =====

    @Test
    public void taskMaster_triggersRecognizeTasks() {
        assertEquals("выучить интегральный множитель",
            TaskMasterPlugin.stripTrigger("задача выучить интегральный множитель", "задача"));
        assertEquals("принести тетрадь",
            TaskMasterPlugin.stripTrigger("не забыть принести тетрадь", "задача"));
        assertEquals("параграф 12",
            TaskMasterPlugin.stripTrigger("дз параграф 12", "задача"));
        assertNullCheck(TaskMasterPlugin.stripTrigger("это просто текст про задачи", "задача"));
    }

    private void assertNullCheck(String v) {
        assertTrue("фраза без начала-триггера не должна стать задачей", v == null);
    }

    // ===== 2. Настройка слова-триггера (v1.4) =====

    @Test
    public void taskMaster_customTriggerFromSettings() {
        // пользователь поменял триггер на «сделай» — он работает приоритетно
        assertEquals("купить молоко",
            TaskMasterPlugin.stripTrigger("сделай купить молоко", "сделай"));
        // а голая команда без текста задачей не становится
        assertTrue(TaskMasterPlugin.stripTrigger("сделай", "сделай") == null);
    }

    // ===== 3. Сериализация TODO: статус выполнения сохраняется =====

    @Test
    public void todoBlock_jsonRoundTripKeepsDoneStatus() throws Exception {
        TodoBlock block = new TodoBlock(1000L);
        block.addItem(new TodoItem("решить задачу 12"));
        block.addItem(new TodoItem("прочитать §3"));
        block.toggle(0); // первая выполнена

        JSONObject json = block.toJson();
        assertEquals("TODO", json.getString("type"));

        TodoBlock restored = TodoBlock.fromJson(json, 2000L);
        List<TodoItem> items = restored.getItems();
        assertEquals(2, items.size());
        assertTrue(items.get(0).isDone());
        assertFalse(items.get(1).isDone());
        assertEquals("решить задачу 12", items.get(0).getText());
        assertEquals(1, restored.activeCount());
        // Markdown — GitHub-чекбоксы
        assertEquals("- [x] решить задачу 12\n- [ ] прочитать §3", restored.toMarkdown());
    }

    // ===== 4. Пост-процессор: подряд продиктованные задачи склеиваются =====

    @Test
    public void taskMaster_mergesConsecutiveTodos() {
        TodoBlock a = new TodoBlock(0L);
        a.addItem(new TodoItem("купить тетрадь"));
        TodoBlock b = new TodoBlock(500L);
        b.addItem(new TodoItem("записать формулу"));
        TextBlock t = new TextBlock("задача позвонить декану", 900L);
        TextBlock plain = new TextBlock("обычный абзац лекции", 1200L);

        Lecture l = lectureWith(a, b, t, plain);
        TaskMasterPlugin.mergeConsecutiveTodos(l);

        // a + b + «задача …» слились в один TODO, обычный текст остался отдельно
        assertEquals(2, l.getBlocks().size());
        TodoBlock merged = (TodoBlock) l.getBlocks().get(0);
        assertEquals(3, merged.getItems().size());
        assertEquals("позвонить декану", merged.getItems().get(2).getText());
        assertTrue(l.getBlocks().get(1) instanceof TextBlock);
    }

    /** Обычный текст между задачами разрывает чек-лист — склейка не «насквозь». */
    @Test
    public void taskMaster_plainTextBreaksMerge() {
        TodoBlock a = new TodoBlock(0L);
        a.addItem(new TodoItem("первая"));
        TextBlock plain = new TextBlock("абзац лекции про теоремы", 500L);
        TodoBlock b = new TodoBlock(900L);
        b.addItem(new TodoItem("вторая"));

        Lecture l = lectureWith(a, plain, b);
        TaskMasterPlugin.mergeConsecutiveTodos(l);

        assertEquals(3, l.getBlocks().size());
        assertEquals(1, ((TodoBlock) l.getBlocks().get(0)).getItems().size());
        assertSame(plain, l.getBlocks().get(1));
        assertEquals(1, ((TodoBlock) l.getBlocks().get(2)).getItems().size());
    }

    // ===== 5. SummaryBot: вставка и ЗАМЕНА резюме (без дублей) =====

    @Test
    public void summaryBot_insertsThenReplacesNotDuplicates() {
        Lecture l = lectureWith(
            new TextBlock("Интеграл это площадь под кривой. Метод замены упрощает вычисления.", 0L),
            new MathBlock("\\int f dx", 500L));

        SummaryBotPlugin.rebuild(l, 3);
        int summaries = countSummaries(l);
        assertEquals(1, summaries);
        assertTrue(l.getBlocks().get(0) instanceof SummaryBlock);
        String first = l.getBlocks().get(0).toMarkdown();
        assertTrue(first.contains("✍ Резюме:"));
        assertTrue("счётчик формул должен присутствовать", first.contains("формул: 1"));

        // повторная обработка — заменяет, а не дублирует
        l.addBlock(new TextBlock("Добавлен новый абзац про ряды Тейлора.", 800L));
        SummaryBotPlugin.rebuild(l, 3);
        assertEquals(1, countSummaries(l));
        assertTrue(l.getBlocks().get(0) instanceof SummaryBlock);
    }

    private int countSummaries(Lecture l) {
        int n = 0;
        for (ContentBlock b : l.getBlocks()) if (b instanceof SummaryBlock) n++;
        return n;
    }

    // ===== 6. Лимит длины резюме (настройка 1–10 предложений) =====

    @Test
    public void summaryBot_sentenceLimitAndClamp() {
        Lecture l = lectureWith(new TextBlock(
            "Первое предложение. Второе предложение. Третье предложение. Четвёртое предложение.", 0L));

        String s2 = SummaryBotPlugin.buildSummaryText(l, 2);
        assertNotNull(s2);
        List<String> body = SummaryBotPlugin.splitSentences(
            s2.substring(SummaryBotPlugin.SUMMARY_PREFIX.length())
               .replaceAll(" · .*$", ""));
        assertEquals("в резюме ровно 2 предложения", 2, body.size());

        // clamp настройки: 0 → 1, 100 → 10
        assertEquals(1, SummaryBotPlugin.clampSentences(0));
        assertEquals(10, SummaryBotPlugin.clampSentences(100));
        assertEquals(5, SummaryBotPlugin.clampSentences(5));
    }
}
