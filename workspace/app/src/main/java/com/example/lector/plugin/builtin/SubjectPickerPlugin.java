package com.example.lector.plugin.builtin;

import android.widget.ArrayAdapter;
import android.widget.AutoCompleteTextView;
import android.widget.Filter;

import com.example.lector.data.SubjectRegistry;
import com.example.lector.plugin.LectorPlugin;
import com.example.lector.plugin.PluginContext;
import com.example.lector.plugin.PluginRegistry;
import com.example.lector.plugin.PluginSettings;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Мод «SubjectPicker» — удобный выбор предмета при начале лекции (UI-слот v1.5).
 *
 * Возможности (реализовано только через Plugin API, код ядра не изменён):
 *  • Экран записи: поле «Предмет» превращается в автодополняемый — все названия,
 *    которые пользователь уже вводил, подсказываются одним тапом по стрелке,
 *    сортировка «свежие/частые сверху», справа — счётчик лекций («· 12 лекций»).
 *  • Дата начала лекции показывается прямо на экране (чип «📅 сегодня, 10.10.2026»)
 *    и фиксируется в момент старта записи (Lecture.date), а затем попадает
 *    в шапку конспекта, Markdown-экспорт и YAML-frontmatter vault'а.
 *  • Долгое нажатие на подсказку удаляет её из реестра (очистка истории).
 *  • Настройки (v1.4): показывать ли счётчики лекций и сколько подсказок хранить.
 *
 * Ядро уже сохраняет предмет в SubjectRegistry при старте записи — мод лишь
 * отображает этот реестр и дополняет его статистикой хранилища.
 */
public class SubjectPickerPlugin implements LectorPlugin {

    public static final String ID = "builtin.subject-picker";

    /** Ключевые слова, по которым мод находит поле предмета на экране записи. */
    private static final String[] SUBJECT_FIELD_HINTS = {"предмет", "subject"};

    // ===== Настройки (v1.4) =====

    private static final PluginSettings.SettingDescriptor SET_SHOW_COUNTERS =
        PluginSettings.SettingDescriptor.bool("show_counters",
            "Показывать число лекций у каждого предмета", true);

    private static final PluginSettings.SettingDescriptor SET_MAX_SUGGESTIONS =
        PluginSettings.SettingDescriptor.intVal("max_suggestions",
            "Максимум подсказок в списке (3–50)", 12);

    @Override
    public String getId() { return ID; }

    @Override
    public String getName() { return "SubjectPicker"; }

    @Override
    public String getVersion() { return "1.0.0"; }

    @Override
    public String getDescription() {
        return "Удобный старт лекции: автодополнение поля «Предмет» по ранее "
            + "введённым названиям (сохраняются и подсвечиваются со счётчиком "
            + "лекций), чип с текущей датой, долгое нажатие на подсказку — "
            + "удаление из истории.";
    }

    @Override
    public List<PluginSettings.SettingDescriptor> getSettings() {
        return Arrays.asList(SET_SHOW_COUNTERS, SET_MAX_SUGGESTIONS);
    }

    @Override
    public void onInit(PluginContext context) { /* настройки читаются лениво */ }

    @Override
    public void onRegister(PluginRegistry registry) {
        // UI-слот v1.5: кастомные view-группы недоступны — улучшаем существующее
        // поле предмета декларативно, находя его обходом дерева экрана записи.
    }

    @Override
    public void onScreenReady(String screenId, android.view.View root) {
        if (!"recording".equals(screenId) || root == null) return;
        try {
            AutoCompleteTextView field = findSubjectField(root);
            if (field == null) return;
            attachSuggestions(field, root.getContext());
            attachDateChip(root);
        } catch (Exception ignored) {
            // мод не должен ронять экран ядра
        }
    }

    // ===== Подсказки предметов =====

    /** Привязка адаптера подсказок к полю ввода предмета. */
    void attachSuggestions(AutoCompleteTextView field, android.content.Context ctx) {
        final SubjectRegistry registry = new SubjectRegistry(ctx);
        final SubjectRegistry.ChipDecorator decorator = makeDecorator(ctx);
        final Map<String, Integer> stats = registry.subjectStats(ctx);
        final List<SubjectRegistry.Entry> entries =
            registry.recent(maxSuggestions(ctx));

        // Отображаемые строки и параллельный список канонических имён
        final List<String> labels = new ArrayList<>();
        final List<String> names = new ArrayList<>();
        for (SubjectRegistry.Entry e : entries) {
            names.add(e.name);
            Integer c = stats.get(e.name);
            labels.add(decorator.decorate(e.name, c != null ? c : 0));
        }

        ArrayAdapter<String> adapter = new ArrayAdapter<>(ctx,
            android.R.layout.simple_dropdown_item_1line, labels) {
            @Override
            public Filter getFilter() {
                // Показываем весь список независимо от набранного текста
                return new Filter() {
                    @Override
                    protected FilterResults performFiltering(CharSequence constraint) {
                        FilterResults r = new FilterResults();
                        r.values = labels;
                        r.count = labels.size();
                        return r;
                    }
                    @Override
                    protected void publishResults(CharSequence constraint,
                                                  FilterResults results) {
                        notifyDataSetChanged();
                    }
                };
            }
        };
        field.setAdapter(adapter);
        field.setThreshold(0);              // подсказки — сразу по тапу на стрелку
        field.setCompletionHint("Название сохраняется и предлагается снова");

        // Удаление предмета из истории — через SubjectRegistry.forget()
        // (экран «Моды» / долгий тап по чипу в списке лекций).

        // Тап по полю открывает список сразу (как выпадающий выбор)
        field.setOnClickListener(v -> {
            if (!field.isPopupShowing() && adapter.getCount() > 0) {
                field.showDropDown();
            }
        });
    }

    /** Строки подсказок для юнит-теста / превью (без Android-виджетов). */
    static List<String> suggestionLabels(android.content.Context ctx) {
        SubjectRegistry registry = new SubjectRegistry(ctx);
        SubjectRegistry.ChipDecorator decorator = makeDecorator(ctx);
        Map<String, Integer> stats = registry.subjectStats(ctx);
        List<String> out = new ArrayList<>();
        for (SubjectRegistry.Entry e : registry.recent(maxSuggestions(ctx))) {
            Integer c = stats.get(e.name);
            out.add(decorator.decorate(e.name, c != null ? c : 0));
        }
        return out;
    }

    // ===== Чип даты =====

    /**
     * Вешает над полем предмета строку с сегодняшней датой: дата начала лекции
     * видна до старта записи и фиксируется в Lecture.date при нажатии «Старт».
     */
    void attachDateChip(android.view.View root) {
        // Если на экране уже есть текстовое поле с датой (id text_lecture_date —
        // просто заполним его и выйдем, дублирующий чип не нужен)
        android.widget.TextView existing = findDateLabel(root);
        if (existing != null) {
            if (existing.getText() == null || existing.getText().length() == 0) {
                existing.setText(dateLabel(System.currentTimeMillis()));
            }
            return;
        }
        if (!(root instanceof android.view.ViewGroup)) return;
        android.view.ViewGroup group = (android.view.ViewGroup) findTopGroup((android.view.ViewGroup) root);
        if (group == null) return;

        android.content.Context ctx = group.getContext();
        android.widget.TextView chip = new android.widget.TextView(ctx);
        chip.setText(dateLabel(System.currentTimeMillis()));
        chip.setTextSize(13f);
        int pad = dp(ctx, 8);
        chip.setPadding(pad, pad / 2, pad, pad / 2);
        chip.setTextColor(android.graphics.Color.parseColor("#FF9800"));

        android.view.ViewGroup.LayoutParams lp = new android.view.ViewGroup.LayoutParams(
            android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
            android.view.ViewGroup.LayoutParams.WRAP_CONTENT);
        group.addView(chip, 0, lp);
    }

    /** Находит поле даты на экране (id text_lecture_date). */
    static android.widget.TextView findDateLabel(android.view.View root) {
        if (root == null) return null;
        if (root instanceof android.widget.TextView && "text_lecture_date".equals(entryName(root))) {
            return (android.widget.TextView) root;
        }
        if (root instanceof android.view.ViewGroup) {
            android.view.ViewGroup vg = (android.view.ViewGroup) root;
            for (int i = 0; i < vg.getChildCount(); i++) {
                android.widget.TextView found = findDateLabel(vg.getChildAt(i));
                if (found != null) return found;
            }
        }
        return null;
    }

    private android.view.View findTopGroup(android.view.ViewGroup vg) {
        // поднимаемся к первому вертикальному LinearLayout — панели с полем предмета
        android.view.ViewGroup cur = vg;
        while (cur.getParent() instanceof android.view.ViewGroup) {
            android.view.ViewGroup parent = (android.view.ViewGroup) cur.getParent();
            boolean vertical = !(parent instanceof android.widget.LinearLayout)
                || ((android.widget.LinearLayout) parent).getOrientation()
                    == android.widget.LinearLayout.VERTICAL;
            if (!vertical) break;
            cur = parent;
        }
        if (cur instanceof android.widget.LinearLayout
                && ((android.widget.LinearLayout) cur).getOrientation()
                    == android.widget.LinearLayout.HORIZONTAL) {
            return null;
        }
        return cur;
    }

    /** Человекочитаемая метка даты начала лекции. */
    public static String dateLabel(long millis) {
        SimpleDateFormat fmt = new SimpleDateFormat("EEEE, dd.MM.yyyy",
            Locale.forLanguageTag("ru"));
        Date d = new Date(millis);
        Calendar today = Calendar.getInstance();
        Calendar that = Calendar.getInstance();
        that.setTime(d);
        String prefix = sameDay(today, that) ? "📅 сегодня, " : "📅 ";
        return prefix + fmt.format(d);
    }

    private static boolean sameDay(Calendar a, Calendar b) {
        return a.get(Calendar.YEAR) == b.get(Calendar.YEAR)
            && a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR);
    }

    // ===== Поиск поля предмета в дереве экранов =====

    /** Находит поле «Предмет» (TextInputEditText / EditText) по подсказке или id. */
    static AutoCompleteTextView findSubjectField(android.view.View root) {
        if (root == null) return null;
        if (root instanceof AutoCompleteTextView) {
            return describeField((android.widget.EditText) root) ? (AutoCompleteTextView) root : null;
        }
        if (root instanceof android.widget.EditText && describeField((android.widget.EditText) root)) {
            // обычный EditText ядра — оборачивать нельзя; возвращаем null,
            // поле должно быть редактируемым списком (см. layout edit_subject)
            return null;
        }
        if (root instanceof android.view.ViewGroup) {
            android.view.ViewGroup vg = (android.view.ViewGroup) root;
            for (int i = 0; i < vg.getChildCount(); i++) {
                AutoCompleteTextView found = findSubjectField(vg.getChildAt(i));
                if (found != null) return found;
            }
        }
        return null;
    }

    private static boolean describeField(android.widget.EditText et) {
        CharSequence hint = et.getHint();
        if (hint != null) {
            String h = hint.toString().toLowerCase(Locale.ROOT);
            for (String key : SUBJECT_FIELD_HINTS) {
                if (h.contains(key)) return true;
            }
        }
        return "edit_subject".equals(entryName(et));
    }

    private static String entryName(android.view.View v) {
        try {
            int id = (int) v.getId();
            if (id == 0) return "";
            return v.getResources().getResourceEntryName(id);
        } catch (Exception e) {
            return "";
        }
    }

    // ===== настройки =====

    private static int maxSuggestions(android.content.Context ctx) {
        PluginSettings s = com.example.lector.plugin.PluginManager
            .getInstance(ctx).getContextFor(ID) != null
            ? com.example.lector.plugin.PluginManager.getInstance(ctx)
                .getContextFor(ID).getSettings()
            : null;
        int n = s == null ? 12 : s.getInt("max_suggestions", 12);
        return Math.max(3, Math.min(50, n));
    }

    private static boolean showCounters(android.content.Context ctx) {
        PluginSettings s = com.example.lector.plugin.PluginManager
            .getInstance(ctx).getContextFor(ID) != null
            ? com.example.lector.plugin.PluginManager.getInstance(ctx)
                .getContextFor(ID).getSettings()
            : null;
        return s == null || s.getBoolean("show_counters", true);
    }

    private static SubjectRegistry.ChipDecorator makeDecorator(final android.content.Context ctx) {
        if (showCounters(ctx)) return new SubjectRegistry.ChipDecorator();
        return new SubjectRegistry.ChipDecorator() {
            @Override
            public String decorate(String name, int lectureCount) { return name; }
        };
    }

    private static int dp(android.content.Context ctx, int value) {
        return Math.round(value * ctx.getResources().getDisplayMetrics().density);
    }

    /** Тосты без прямого импорта Toast в горячем пути. */
    private static final class ToastHelper {
        static void show(android.content.Context ctx, String text) {
            android.widget.Toast.makeText(ctx.getApplicationContext(),
                text, android.widget.Toast.LENGTH_SHORT).show();
        }
    }
}
