package com.example.lector.services;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import com.example.lector.models.ContentBlock;
import com.example.lector.models.HeadingBlock;
import com.example.lector.models.Lecture;
import com.example.lector.models.TextBlock;
import com.example.lector.plugin.PostProcessor;

import org.junit.Test;

import java.util.List;

/**
 * Тесты пост-обработки лекций (встроенный процессор ядра + процессоры модов).
 */
public class PostProcessTest {

    private Lecture lectureWith(TextBlock... blocks) {
        Lecture l = new Lecture("Математический анализ", 0L);
        for (TextBlock b : blocks) l.addBlock(b);
        return l;
    }

    private TextBlock text(String t, long ts) {
        TextBlock b = new TextBlock(t, ts);
        b.setSpeakerId(0);
        b.setSpeakerName("Преподаватель");
        return b;
    }

    @Test
    public void coreProcessor_mergesConsecutiveSameSpeakerBlocks() {
        Lecture l = lectureWith(
            text("Рассмотрим функцию", 0),
            text("она непрерывна", 1000));
        new CorePostProcessor().process(l);

        // 1 заголовок H1 + 1 склеенный абзац
        assertEquals(2, l.getBlocks().size());
        assertTrue(l.getBlocks().get(0) instanceof HeadingBlock);
        TextBlock merged = (TextBlock) l.getBlocks().get(1);
        assertTrue(merged.getText().contains("Рассмотрим функцию"));
        assertTrue(merged.getText().contains("непрерывна"));
    }

    @Test
    public void coreProcessor_removesEmptyAndDuplicateBlocks() {
        Lecture l = lectureWith(
            text("Первая фраза.", 0),
            text("   ", 500),
            text("Первая фраза.", 900));
        new CorePostProcessor().process(l);

        int texts = 0;
        for (ContentBlock b : l.getBlocks()) if (b instanceof TextBlock) texts++;
        assertEquals(1, texts);
    }

    @Test
    public void coreProcessor_addsTitleHeadingOnce() {
        Lecture l = lectureWith(text("Тезис.", 0));
        CorePostProcessor p = new CorePostProcessor();
        p.process(l);
        p.process(l); // повторный вызов не должен удваивать заголовок
        int headings = 0;
        for (ContentBlock b : l.getBlocks()) if (b instanceof HeadingBlock) headings++;
        assertEquals(1, headings);
    }

    @Test
    public void registry_runsPluginPostProcessors_inOrder_andIsolatesCrashes() {
        com.example.lector.plugin.PluginRegistry registry = new com.example.lector.plugin.PluginRegistry();
        final List<String> order = new java.util.ArrayList<>();

        registry.registerPostProcessor(new PostProcessor() {
            @Override public String getName() { return "first"; }
            @Override public void process(Lecture lecture) { order.add("first"); }
        });
        registry.registerPostProcessor(new PostProcessor() {
            @Override public String getName() { return "boom"; }
            @Override public void process(Lecture lecture) { throw new RuntimeException("fail"); }
        });
        registry.registerPostProcessor(new PostProcessor() {
            @Override public String getName() { return "second"; }
            @Override public void process(Lecture lecture) { order.add("second"); }
        });

        Lecture l = new Lecture("Физика", 0L);
        registry.runPostProcessors(l);

        assertEquals(2, order.size());
        assertEquals("first", order.get(0));
        assertEquals("second", order.get(1));
    }
}
