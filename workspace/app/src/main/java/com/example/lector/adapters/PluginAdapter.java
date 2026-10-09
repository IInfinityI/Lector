package com.example.lector.adapters;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.example.lector.R;
import com.example.lector.plugin.LectorPlugin;

import java.util.List;

/**
 * Список установленных модов + ошибки загрузки + кнопка импорта.
 */
public class PluginAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

    private static final int TYPE_HEADER = 0;
    private static final int TYPE_PLUGIN = 1;
    private static final int TYPE_ERROR = 2;

    private final List<LectorPlugin> plugins;
    private final List<String> errors;
    private final Runnable importAction;

    public PluginAdapter(List<LectorPlugin> plugins, List<String> errors, Runnable importAction) {
        this.plugins = plugins;
        this.errors = errors;
        this.importAction = importAction;
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
        } else {
            String err = errors.get(idx - plugins.size());
            h.title.setText(R.string.plugins_error);
            h.subtitle.setText(err);
        }
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

        SimpleHolder(View itemView) {
            super(itemView);
            title = itemView.findViewById(R.id.textTitle);
            subtitle = itemView.findViewById(R.id.textSubtitle);
        }
    }
}
