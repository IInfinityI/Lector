package com.example.lector.plugin.builtin;

import android.content.Intent;
import android.widget.TextView;
import android.widget.Toast;

import com.example.lector.data.LectureRepository;
import com.example.lector.data.SubjectRegistry;
import com.example.lector.models.ContentBlock;
import com.example.lector.models.Lecture;
import com.example.lector.models.TextBlock;
import com.example.lector.plugin.BlockHandler;
import com.example.lector.plugin.EventBus;
import com.example.lector.plugin.ExportFormat;
import com.example.lector.plugin.Exporter;
import com.example.lector.plugin.LectorPlugin;
import com.example.lector.plugin.PluginContext;
import com.example.lector.plugin.PluginRegistry;
import com.example.lector.plugin.PluginSettings;
import com.example.lector.plugin.PostProcessor;
import com.example.lector.plugin.ToolbarAction;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Мод «ObsidianVault» — экспорт лекций в хранилище Obsidian (Markdown + wiki-ссылки).
 *
 * Возможности (реализованы только через Plugin API v1.2–v1.5, код ядра не изменён):
 *  • Exporter: формат «Obsidian (.md)» — YAML-frontmatter (tags, date),
 *    авто-теги из заголовков/выделений, [[wiki-ссылки]] на связанные темы,
 *    повторный экспорт перезаписывает файл без дубликатов, пересобирается _index.md.
 *  • BlockHandler: голосовые команды «вики ссылка [тема]» / «wiki link [тема]»
 *    во время диктовки добавляют в конспект строку [[тема]].
 *  • PostProcessor: при остановке записи собирает теги и вики-ссылки предмета
 *    в конец конспекта (секция «Связи»), чтобы синхронизированный vault был графом знаний.
 *  • ToolbarAction v1.3: кнопка «Vault» в редакторе — одним тапом экспортировать
 *    лекцию и открыть папку хранилища файловым менеджером.
 *  • Settings v1.4: имя папки внутри vault и количество авто-тегов.
 *
 * Хранилище: filesDir/obsidian-vault/ — синхронизируется с ПК (Syncthing, Drive, git)
 * и открывается десктопным Obsidian как обычный vault.
 */
public class ObsidianVaultPlugin implements LectorPlugin {

    public static final String ID = "builtin.obsidian-vault";
    public static final String VAULT_DIR_NAME_DEFAULT = "obsidian-vault";

    // ===== Настройки (v1.4) =====

    private static final PluginSettings.SettingDescriptor SET_VAULT_FOLDER =
        PluginSettings.SettingDescriptor.string("vault_folder",
            "Имя папки хранилища (filesDir/...)", VAULT_DIR_NAME_DEFAULT);

    private static final PluginSettings.SettingDescriptor SET_AUTO_TAGS =
        PluginSettings.SettingDescriptor.intVal("auto_tags",
            "Количество авто-тегов (0–10)", 5);

    private static final PluginSettings.SettingDescriptor SET_LINK_SUBJECT =
        PluginSettings.SettingDescriptor.bool("link_subject",
            "Вики-ссылка на предмет в каждой лекции", true);

    @Override
    public String getId() { return ID; }

    @Override
    public String getName() { return "ObsidianVault"; }

    @Override
    public String getVersion() { return "1.0.0"; }

    @Override
    public String getDescription() {
        return "Экспорт лекций в хранилище Obsidian: Markdown с YAML-frontmatter, "
            + "тегами и [[wiki-ссылками]]; команда «вики ссылка тема», кнопка «Vault», "
            + "пересобираемый индекс _index.md. Vault: files/obsidian-vault/ "
            + "(синхронизация Syncthing/Drive/git).";
    }

    @Override
    public List<PluginSettings.SettingDescriptor> getSettings() {
        return Arrays.asList(SET_VAULT_FOLDER, SET_AUTO_TAGS, SET_LINK_SUBJECT);
    }

    @Override
    public void onInit(PluginContext context) { /* настройки читаются лениво */ }

    @Override
    public void onRegister(PluginRegistry registry) {
        // пусто: всё декларировано ниже через getExporters/getBlockHandlers/...
    }

    // ===== 1. Экспортёр формата «Obsidian» =====

    @Override
    public List<Exporter> getExporters() {
        return Arrays.<Exporter>asList(new Exporter() {

            final ExportFormat FORMAT =
                new ExportFormat("obsidian", "Obsidian (vault .md)", ".md");

            @Override
            public ExportFormat getFormat() { return FORMAT; }

            @Override
            public boolean export(Lecture lecture, String markdown, File targetFile)
                    throws Exception {
                // targetFile от ядра не используется: мод пишет в свою структуру vault
                File vault = vaultDir(currentContext);
                if (!vault.exists() && !vault.mkdirs()) return false;

                String title = SubjectRegistry.fileTitle(
                    lecture.getSubjectSafe(), lecture.getDate());
                File out = new File(vault, title + ".md");

                List<String> tags = collectTags(lecture, currentContext);
                Set<String> links = collectLinks(lecture, currentContext);

                StringBuilder sb = new StringBuilder();
                appendFrontmatter(sb, lecture, tags);
                sb.append("# ").append(lecture.getSubjectSafe()).append("\n\n");
                sb.append(markdown == null ? "" : markdown.trim()).append("\n");
                if (!links.isEmpty()) {
                    sb.append("\n## Связи\n\n");
                    for (String l : links) sb.append("- [[").append(l).append("]]\n");
                }
                write(out, sb.toString());
                rebuildIndex(vault);
                lastExported = out;
                return out.exists();
            }
        });
    }

    // ===== 2. Голосовая команда «вики ссылка [тема]» =====

    /** Триггеры вики-ссылки: «вики ссылка …», «wiki link …». */
    static final Pattern WIKI_TRIGGER = Pattern.compile(
        "^\\s*(?:вики\\s*ссылка|wiki\\s*link)\\s+(.+)$", Pattern.CASE_INSENSITIVE);

    @Override
    public List<BlockHandler> getBlockHandlers() {
        return Arrays.<BlockHandler>asList(new BlockHandler() {
            @Override
            public String getName() { return "obsidian-wiki-link"; }

            @Override
            public boolean canHandle(String text, long timestampMs) {
                return text != null && WIKI_TRIGGER.matcher(text).find();
            }

            @Override
            public ContentBlock createBlock(String text, long timestampMs) {
                Matcher m = WIKI_TRIGGER.matcher(text.trim());
                String topic = m.matches() ? cleanTopic(m.group(1)) : cleanTopic(text);
                // Блок-строка с готовой wiki-ссылкой: попадёт и в конспект, и в экспорт
                return new TextBlock("[[" + topic + "]]", timestampMs);
            }
        });
    }

    // ===== 3. Пост-обработка: секция связей и авто-теги =====

    @Override
    public List<PostProcessor> getPostProcessors() {
        return Arrays.<PostProcessor>asList(new PostProcessor() {
            @Override
            public String getName() { return "obsidian-links"; }

            @Override
            public void process(Lecture lecture) {
                if (lecture == null || lecture.getBlocks() == null) return;
                Set<String> links = collectLinks(lecture, null);
                // Тема самого предмета — постоянная вики-ссылка всех лекций курса
                if (links.size() > 0 || shouldLinkSubject(null)) {
                    String subject = SubjectRegistry.normalize(lecture.getSubjectSafe());
                    if (!subject.isEmpty()) links.add(subject);
                }
                if (links.isEmpty()) return;
                StringBuilder sb = new StringBuilder("Связи: ");
                boolean first = true;
                for (String l : links) {
                    if (!first) sb.append(" · ");
                    sb.append("[[").append(l).append("]]");
                    first = false;
                }
                // Не дублировать при повторной пост-обработке
                for (ContentBlock b : lecture.getBlocks()) {
                    if (b instanceof TextBlock
                        && ((TextBlock) b).getText().startsWith("Связи: ")) return;
                }
                TextBlock tail = new TextBlock(sb.toString(), lastTimestamp(lecture));
                lecture.addBlock(tail);
            }
        });
    }

    // ===== 4. Кнопка «Vault» в тулбаре редактора (v1.3) =====

    @Override
    public List<ToolbarAction> getToolbarActions() {
        return Arrays.<ToolbarAction>asList(new ToolbarAction() {
            @Override
            public String getLabel() { return "Vault"; }

            @Override
            public int getOrder() { return 20; }

            @Override
            public void onClick(Lecture lecture, PluginContext context) {
                if (lecture == null) return;
                currentContext = context;
                try {
                    File vault = vaultDir(context);
                    if (!vault.exists()) vault.mkdirs();
                    String title = SubjectRegistry.fileTitle(
                        lecture.getSubjectSafe(), lecture.getDate());
                    File out = new File(vault, title + ".md");

                    String md = lecture.toMarkdown();
                    List<String> tags = collectTags(lecture, context);
                    Set<String> links = collectLinks(lecture, context);

                    StringBuilder sb = new StringBuilder();
                    appendFrontmatter(sb, lecture, tags);
                    sb.append("# ").append(lecture.getSubjectSafe()).append("\n\n");
                    sb.append(md.trim()).append("\n");
                    if (!links.isEmpty()) {
                        sb.append("\n## Связи\n\n");
                        for (String l : links) sb.append("- [[").append(l).append("]]\n");
                    }
                    write(out, sb.toString());
                    rebuildIndex(vault);

                    // Сохраняем предмет, чтобы он подсвечивался на экране новой лекции
                    new SubjectRegistry(context.getAppContext())
                        .remember(lecture.getSubjectSafe());

                    openFolder(context, vault);
                    Toast.makeText(context.getAppContext(),
                        "Экспортировано в vault: " + out.getName(),
                        Toast.LENGTH_LONG).show();
                } catch (Exception e) {
                    Toast.makeText(context.getAppContext(),
                        "Ошибка vault: " + e.getMessage(), Toast.LENGTH_LONG).show();
                } finally {
                    currentContext = null;
                }
            }
        });
    }

    @Override
    public void subscribe(EventBus bus) {
        // После сохранения лекции тихо обновляем индекс хранилища
        bus.subscribe(EventBus.Event.LECTURE_SAVED, (event, payload) -> {
            try {
                File vault = vaultDir(null);
                if (vault.isDirectory()) rebuildIndex(vault);
            } catch (Exception ignored) { }
        });
    }

    // ===== Логика формирования vault =====

    /** Контекст вызова (экспортёр ядра создаётся без контекста — используем последний). */
    private volatile PluginContext currentContext;
    private volatile File lastExported;

    private File vaultDir(PluginContext ctx) {
        android.content.Context app = ctx != null ? ctx.getAppContext() : fallbackApp;
        String folder = VAULT_DIR_NAME_DEFAULT;
        if (ctx != null) {
            folder = ctx.getSettings().getString("vault_folder", VAULT_DIR_NAME_DEFAULT);
        }
        folder = SubjectRegistry.normalize(folder).replace("/", "-");
        if (folder.isEmpty()) folder = VAULT_DIR_NAME_DEFAULT;
        File base = app != null ? app.getFilesDir()
            : new File(System.getProperty("user.dir", "."), "build/test-files");
        return new File(base, folder);
    }

    /** Ядро не даёт контекст экспортёру напрямую — мод запоминает его при подписке. */
    private volatile android.content.Context fallbackApp;

    @Override
    public void onShutdown() { fallbackApp = null; }

    /** Пакетная регистрация экспортёров не передаёт контекст — ловим его из settings-входа. */
    void bindContext(PluginContext ctx) {
        this.currentContext = ctx;
        if (ctx != null) fallbackApp = ctx.getAppContext();
    }

    static String cleanTopic(String raw) {
        if (raw == null) return "";
        String t = SubjectRegistry.normalize(raw);
        t = t.replaceAll("^[«\"'\\[\\]]+|[«\"'\\[\\].,!?]+$", "");
        return t;
    }

    /** Авто-теги: подзаголовки/заголовки + первые слова ключевых выделений, лимит из настроек. */
    static List<String> autoTags(Lecture lecture, int limit) {
        List<String> tags = new ArrayList<>();
        if (limit <= 0 || lecture == null) return tags;
        Set<String> seen = new LinkedHashSet<>();
        for (ContentBlock b : lecture.getBlocks()) {
            String key = b.getTypeKey();
            if ("HIGHLIGHT".equals(key) || "HEADING".equals(key)
                    || "SUBHEADING".equals(key) || b instanceof com.example.lector.models.HeadingBlock) {
                String text = blockPlain(b);
                for (String w : splitKeywords(text)) {
                    if (w.length() >= 4 && seen.add(w.toLowerCase(Locale.ROOT))) {
                        tags.add(w.toLowerCase(Locale.ROOT));
                        if (tags.size() >= limit) return tags;
                    }
                }
            }
        }
        // Фолбэк: теги из названия предмета
        if (tags.isEmpty()) {
            for (String w : splitKeywords(lecture.getSubjectSafe())) {
                if (w.length() >= 4) tags.add(w.toLowerCase(Locale.ROOT));
                if (tags.size() >= Math.min(3, limit)) break;
            }
        }
        return tags;
    }

    /** Теги лекции для экспортёра: авто-теги блоков + слова названия предмета. */
    static List<String> collectTags(Lecture lecture, PluginContext ctx) {
        int limit = 5;
        try {
            if (ctx != null) limit = tagLimit(ctx.getSettings());
        } catch (Exception ignored) { }
        List<String> tags = new ArrayList<>(autoTags(lecture, limit));
        if (lecture != null) {
            for (String w : splitKeywords(lecture.getSubjectSafe())) {
                String t = w.toLowerCase(Locale.ROOT);
                if (t.length() >= 4 && !tags.contains(t) && tags.size() < limit) tags.add(t);
            }
        }
        return tags;
    }

    private static List<String> splitKeywords(String text) {
        List<String> words = new ArrayList<>();
        if (text == null) return words;
        for (String w : text.split("[^\\p{L}\\p{Nd}]+")) {
            String s = w.trim();
            if (!s.isEmpty()) words.add(s);
        }
        return words;
    }

    static String blockPlain(ContentBlock b) {
        if (b instanceof TextBlock) return ((TextBlock) b).getText();
        if (b instanceof com.example.lector.models.ParagraphBlock)
            return ((com.example.lector.models.ParagraphBlock) b).getText();
        if (b instanceof com.example.lector.models.HeadingBlock)
            return ((com.example.lector.models.HeadingBlock) b).getText();
        if (b instanceof com.example.lector.models.SubheadingBlock)
            return ((com.example.lector.models.SubheadingBlock) b).getText();
        if (b instanceof com.example.lector.plugin.builtin.HighlightBlock)
            return ((HighlightBlock) b).getText();
        return "";
    }

    /** Wiki-ссылки: явные [[..]] в тексте блоков + заголовки как смежные темы. */
    static Set<String> collectLinks(Lecture lecture, PluginContext ctx) {
        Set<String> links = new LinkedHashSet<>();
        if (lecture == null) return links;
        Pattern p = Pattern.compile("\\[\\[([^\\]\\[]+)\\]\\]");
        for (ContentBlock b : lecture.getBlocks()) {
            String text = blockPlain(b);
            if (text == null || text.isEmpty()) continue;
            Matcher m = p.matcher(text);
            while (m.find()) {
                String topic = cleanTopic(m.group(1));
                if (!topic.isEmpty()) links.add(topic);
            }
        }
        return links;
    }

    private boolean shouldLinkSubject(PluginContext ctx) {
        return ctx == null || ctx.getSettings().getBoolean("link_subject", true);
    }

    private void appendFrontmatter(StringBuilder sb, Lecture lecture, List<String> tags) {
        SimpleDateFormat iso = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.ROOT);
        sb.append("---\n");
        sb.append("title: \"").append(lecture.getSubjectSafe()
            .replace("\"", "'")).append("\"\n");
        sb.append("date: ").append(iso.format(new java.util.Date(lecture.getDate()))).append("\n");
        sb.append("source: Lector\n");
        sb.append("tags:\n");
        sb.append("  - lectures\n");
        String subjectTag = SubjectRegistry.normalize(lecture.getSubjectSafe())
            .toLowerCase(Locale.ROOT).replaceAll("\\s+", "-");
        if (!subjectTag.isEmpty()) sb.append("  - ").append(subjectTag).append("\n");
        for (String t : tags) sb.append("  - ").append(t).append("\n");
        sb.append("---\n\n");
    }

    private void write(File out, String content) throws Exception {
        File parent = out.getParentFile();
        if (parent != null && !parent.exists()) parent.mkdirs();
        // Перезапись без дубликатов: один файл = одна лекция (id в комментарии-якоре)
        try (OutputStreamWriter w = new OutputStreamWriter(
                new FileOutputStream(out), "UTF-8")) {
            w.write(content);
        }
    }

    /** Пересобираемый индекс vault: _index.md со списком всех заметок по датам. */
    void rebuildIndex(File vault) {
        try {
            File[] files = vault.listFiles((dir, name) ->
                name.endsWith(".md") && !name.equals("_index.md"));
            List<File> notes = new ArrayList<>();
            if (files != null) notes.addAll(Arrays.asList(files));
            java.util.Collections.sort(notes,
                (a, b) -> a.getName().compareToIgnoreCase(b.getName()));

            Map<String, Integer> bySubject = new LinkedHashMap<>();
            StringBuilder sb = new StringBuilder();
            sb.append("---\ntags:\n  - index\n---\n\n");
            sb.append("# Индекс хранилища Lector\n\n");
            sb.append("_Автогенерация мода ObsidianVault; всего заметок: ")
              .append(notes.size()).append("_\n\n");
            for (File f : notes) {
                String stem = f.getName().replaceAll("\\.md$", "");
                int us = stem.lastIndexOf('_');
                String subject = us > 0 ? stem.substring(0, us) : stem;
                bySubject.merge(subject, 1, Integer::sum);
            }
            for (Map.Entry<String, Integer> e : bySubject.entrySet()) {
                sb.append("## [[").append(e.getKey()).append("]]")
                  .append(" (").append(e.getValue()).append(")\n\n");
                for (File f : notes) {
                    String stem = f.getName().replaceAll("\\.md$", "");
                    if (stem.startsWith(e.getKey() + "_")) {
                        sb.append("- [[").append(stem).append("]] — ")
                          .append(stem.substring(e.getKey().length() + 1)).append("\n");
                    }
                }
                sb.append("\n");
            }
            write(new File(vault, "_index.md"), sb.toString());
        } catch (Exception ignored) {
            // индекс не должен ронять экспорт
        }
    }

    /** Открываем папку хранилища во внешнем файловом менеджере (быстрый доступ). */
    private void openFolder(PluginContext ctx, File folder) {
        try {
            android.content.Context app = ctx.getAppContext();
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(android.net.Uri.fromFile(folder), "resource/folder");
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            app.startActivity(intent);
        } catch (Exception e) {
            Toast.makeText(ctx.getAppContext(),
                "Папка vault: " + folder.getAbsolutePath(), Toast.LENGTH_LONG).show();
        }
    }

    private long lastTimestamp(Lecture lecture) {
        long t = 0;
        for (ContentBlock b : lecture.getBlocks()) t = Math.max(t, b.getTimestamp());
        return t;
    }

    // ===== видимость для тестов =====

    static int tagLimit(PluginSettings settings) {
        int n = settings == null ? 5 : settings.getInt("auto_tags", 5);
        return Math.max(0, Math.min(10, n));
    }
}
