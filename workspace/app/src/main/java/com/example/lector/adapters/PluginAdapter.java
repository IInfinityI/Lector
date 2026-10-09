package com.example.lector.adapters;

import android.text.InputType;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.recyclerview.widget.RecyclerView;

import com.example.lector.R;
import com.example.lector.plugin.LectorPlugin;
import com.example.lector.plugin.PluginContext;
import com.example.lector.plugin.PluginSettings;

import java.util.List;

/**
 * Список установленных модов + ошибки загрузки + кнопка импорта.
 * UI-слот v1.4: для каждого мода с объявленными настройками ядро
 * автогенерирует панель конфигурации (чекбокс / число / строка / выбор).
 */
public class PluginAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

    private static final int TYPE_HEADER = 0;
    private static final int TYPE_PLUGIN = 1;
    private static final int TYPE_ERROR = 2;

    /** Источник контекстов настроек — внедряется из PluginsFragment/PluginManager. */
    public interface ContextProvider {
        @Nullable PluginContext getContextFor(String pluginId);
    }

    private final List<LectorPlugin> plugins;
    private final List<String> errors;
    private final Runnable importAction;
    private final ContextProvider contextProvider;

    public PluginAdapter(List<LectorPlugin> plugins, List<String> errors, Runnable importAction) {
        this(plugins, errors, importAction, null);
    }

    public PluginAdapter(List<LectorPlugin> plugins, List<String> errors, Runnable importAction,
                         ContextProvider contextProvider) {
        this.plugins = plugins;
        this.errors = errors;
        this.importAction = importAction;
        this.contextProvider = contextProvider;
    }

    @NonNull
    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        int layout = viewType == TYPE_PLUGIN ? R.layout.item_plugin : R.layout.item_plugin_row_simple;
        return new SimpleHolder(LayoutInflater.from(parent.getContext())
            .inflate(layout, parent, false));
    }

    @Override
    public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
        SimpleHolder h = (SimpleHolder) holder;
        if (position == 0) {
            h.title.setText(R.string.plugins_installed);
            h.subtitle.setText(plugins.size() + " шт.");
            h.itemView.setOnClickListener(v -> importAction.run());
            return;
        }
        int idx = position - 1;
        if (idx < plugins.size()) {
            LectorPlugin p = plugins.get(idx);
            h.title.setText(p.getName() + " v" + p.getVersion());
            h.subtitle.setText(p.getDescription() + "\nID: " + p.getId());
            h.itemView.setOnClickListener(null);
            bindSettings(h, p);
        } else {
            String err = errors.get(idx - plugins.size());
            h.title.setText(R.string.plugins_error);
            h.subtitle.setText(err);
        }
    }

    /** Автогенерация панели настроек мода (ядро не знает конкретных ключей). */
    private void bindSettings(SimpleHolder h, LectorPlugin plugin) {
        h.settingsContainer.removeAllViews();
        List<PluginSettings.SettingDescriptor> rawDescriptors;
        try {
            rawDescriptors = plugin.getSettings();
        } catch (Exception e) {
            rawDescriptors = null;
        }
        if (rawDescriptors == null || rawDescriptors.isEmpty()) return;
        final List<PluginSettings.SettingDescriptor> descriptors = rawDescriptors;

        LayoutInflater inflater = LayoutInflater.from(h.itemView.getContext());
        View header = inflater.inflate(R.layout.item_plugin_row_simple, h.settingsContainer, false);
        ((TextView) header.findViewById(R.id.textTitle))
            .setText(R.string.plugins_settings_title);
        ((TextView) header.findViewById(R.id.textSubtitle)).setText("");
        h.settingsContainer.addView(header);

        PluginContext ctx = contextProvider != null
            ? contextProvider.getContextFor(plugin.getId()) : null;
        final PluginSettings settings = ctx != null ? ctx.getSettings() : null;
        if (settings == null) return;

        for (PluginSettings.SettingDescriptor d : descriptors) {
            switch (d.type) {
                case BOOLEAN: {
                    CheckBox cb = new CheckBox(h.itemView.getContext());
                    cb.setText(d.label);
                    cb.setChecked(settings.getBoolean(d.key, (Boolean) d.defaultValue));
                    cb.setOnCheckedChangeListener((v, checked) ->
                        settings.putBoolean(d.key, checked));
                    h.settingsContainer.addView(cb);
                } break;
                case INT: {
                    LinearLayout row = makeLabelledRow(inflater, d.label);
                    EditText input = row.findViewById(R.id.editSetting);
                    input.setInputType(InputType.TYPE_CLASS_NUMBER);
                    input.setText(String.valueOf(settings.getInt(d.key, (Integer) d.defaultValue)));
                    input.addTextChangedListener(new android.text.TextWatcher() {
                        @Override public void beforeTextChanged(CharSequence s, int a, int b, int c) { }
                        @Override public void onTextChanged(CharSequence s, int a, int b, int c) { }
                        @Override public void afterTextChanged(android.text.Editable s) {
                            try {
                                settings.putInt(d.key, Integer.parseInt(s.toString().trim()));
                            } catch (NumberFormatException ignored) { }
                        }
                    });
                    h.settingsContainer.addView(row);
                } break;
                case CHOICE: {
                    LinearLayout row = makeLabelledRow(inflater, d.label);
                    Spinner spinner = row.findViewById(R.id.spinnerSetting);
                    ArrayAdapter<String> aa = new ArrayAdapter<>(h.itemView.getContext(),
                        android.R.layout.simple_spinner_dropdown_item, d.choices);
                    spinner.setAdapter(aa);
                    String current = settings.getString(d.key, String.valueOf(d.defaultValue));
                    int pos = d.choices.indexOf(current);
                    spinner.setSelection(Math.max(0, pos));
                    spinner.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener() {
                        @Override public void onItemSelected(android.widget.AdapterView<?> parent,
                                                             View view, int position, long id) {
                            settings.putString(d.key, d.choices.get(position));
                        }
                        @Override public void onNothingSelected(android.widget.AdapterView<?> parent) { }
                    });
                    h.settingsContainer.addView(row);
                } break;
                case STRING:
                default: {
                    LinearLayout row = makeLabelledRow(inflater, d.label);
                    EditText input = row.findViewById(R.id.editSetting);
                    input.setText(settings.getString(d.key, String.valueOf(d.defaultValue)));
                    input.addTextChangedListener(new android.text.TextWatcher() {
                        @Override public void beforeTextChanged(CharSequence s, int a, int b, int c) { }
                        @Override public void onTextChanged(CharSequence s, int a, int b, int c) { }
                        @Override public void afterTextChanged(android.text.Editable s) {
                            settings.putString(d.key, s.toString());
                        }
                    });
                    h.settingsContainer.addView(row);
                } break;
            }
        }

        // Кнопка сброса к значениям по умолчанию, объявленным самим модом
        TextView reset = new TextView(h.itemView.getContext());
        reset.setText(R.string.plugins_settings_reset);
        reset.setTextColor(0xFF3F51B5);
        reset.setPadding(0, 12, 0, 0);
        reset.setOnClickListener(v -> {
            settings.resetToDefaults(descriptors);
            notifyDataSetChanged();
        });
        h.settingsContainer.addView(reset);
    }

    private LinearLayout makeLabelledRow(LayoutInflater inflater, String label) {
        LinearLayout row = (LinearLayout) inflater
            .inflate(R.layout.item_plugin_setting_row, null);
        ((TextView) row.findViewById(R.id.textSettingLabel)).setText(label);
        return row;
    }

    @Override
    public int getItemCount() {
        return 1 + plugins.size() + errors.size();
    }

    @Override
    public int getItemViewType(int position) {
        if (position == 0) return TYPE_HEADER;
        return position - 1 < plugins.size() ? TYPE_PLUGIN : TYPE_ERROR;
    }

    static class SimpleHolder extends RecyclerView.ViewHolder {
        final TextView title;
        final TextView subtitle;
        final LinearLayout settingsContainer;

        SimpleHolder(View itemView) {
            super(itemView);
            title = itemView.findViewById(R.id.textTitle);
            subtitle = itemView.findViewById(R.id.textSubtitle);
            settingsContainer = itemView.findViewById(R.id.settingsContainer);
        }
    }
}
