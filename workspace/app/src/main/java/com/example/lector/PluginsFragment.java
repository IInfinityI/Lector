package com.example.lector;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.example.lector.adapters.PluginAdapter;
import com.example.lector.databinding.FragmentPluginsBinding;
import com.example.lector.plugin.LectorPlugin;
import com.example.lector.plugin.PluginManager;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.List;

/**
 * Экран «Моды»: список загруженных плагинов и установка внешних .jar/.dex.
 */
public class PluginsFragment extends Fragment {

    private static final int REQUEST_IMPORT_PLUGIN = 200;

    private FragmentPluginsBinding binding;
    private PluginManager pluginManager;
    private PluginAdapter adapter;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater,
                             @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        binding = FragmentPluginsBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        pluginManager = PluginManager.getInstance(requireContext());
        List<LectorPlugin> plugins = pluginManager.getLoadedPlugins();

        adapter = new PluginAdapter(plugins, pluginManager.getLoadErrors(),
            this::installFromPicker);
        binding.recyclerPlugins.setLayoutManager(new LinearLayoutManager(getContext()));
        binding.recyclerPlugins.setAdapter(adapter);

        binding.toolbar.setNavigationOnClickListener(v ->
            requireActivity().getSupportFragmentManager().popBackStack());

        binding.btnImportPlugin.setOnClickListener(v -> installFromPicker());
    }

    private void installFromPicker() {
        Intent picker = new Intent(Intent.ACTION_GET_CONTENT);
        picker.setType("*/*");
        picker.addCategory(Intent.CATEGORY_OPENABLE);
        try {
            startActivityForResult(Intent.createChooser(picker, "Выберите файл мода (.jar/.dex)"),
                REQUEST_IMPORT_PLUGIN);
        } catch (Exception e) {
            Toast.makeText(getContext(), "Нет файла для выбора модов", Toast.LENGTH_SHORT).show();
        }
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQUEST_IMPORT_PLUGIN
                || resultCode != android.app.Activity.RESULT_OK || data == null) return;
        Uri uri = data.getData();
        if (uri == null) return;

        File target = new File(pluginManager.getExternalPluginsDir(),
            "plugin_" + System.currentTimeMillis() + ".jar");
        try (InputStream is = requireContext().getContentResolver().openInputStream(uri);
             FileOutputStream os = new FileOutputStream(target)) {
            if (is == null) throw new IllegalStateException("empty stream");
            byte[] buf = new byte[8192];
            int n;
            while ((n = is.read(buf)) > 0) os.write(buf, 0, n);
            Toast.makeText(getContext(), "Мод установлен. Перезапустите приложение.",
                Toast.LENGTH_LONG).show();
        } catch (Exception e) {
            if (target.exists()) target.delete();
            Toast.makeText(getContext(), "Ошибка установки: " + e.getMessage(),
                Toast.LENGTH_LONG).show();
        }
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}
