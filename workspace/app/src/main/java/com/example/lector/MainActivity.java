package com.example.lector;

import android.os.Bundle;

import androidx.activity.EdgeToEdge;

import androidx.appcompat.app.AppCompatActivity;

import android.view.View;

import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.navigation.NavController;
import androidx.navigation.Navigation;
import androidx.navigation.ui.AppBarConfiguration;
import androidx.navigation.ui.NavigationUI;

import com.example.lector.databinding.ActivityMainBinding;
import com.example.lector.plugin.PluginManager;

import android.view.Menu;
import android.view.MenuItem;

public class MainActivity extends AppCompatActivity {

    private AppBarConfiguration appBarConfiguration;
    private ActivityMainBinding binding;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EdgeToEdge.enable(this);

        // Инициализация системы модов до загрузки любого UI.
        // Ошибка одного мода не должна ронять всё приложение — на этом месте
        // вместо экрана появляется "Hello Android!" из шаблона, если что-то пошло не так.
        try {
            PluginManager.getInstance(this).initialize();
        } catch (Throwable t) {
            android.util.Log.e("LectorApp", "PluginManager.initialize() упал", t);
        }

        binding = ActivityMainBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        ViewCompat.setOnApplyWindowInsetsListener(binding.main, (v, insets) -> {
            Insets systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars());
            v.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom);
            return insets;
        });
        setSupportActionBar(binding.toolbar);

        // Получаем NavController после того, как представление полностью инициализировано.
        // Если по какой-то причине NavHostFragment не найден — падаем с внятной ошибкой
        // в logcat (тег LectorApp), а не показываем пустой экран.
        androidx.navigation.fragment.NavHostFragment navHostFragment =
            (androidx.navigation.fragment.NavHostFragment) getSupportFragmentManager()
                .findFragmentById(R.id.nav_host_fragment_content_main);
        if (navHostFragment == null) {
            throw new IllegalStateException(
                "NavHostFragment (R.id.nav_host_fragment_content_main) не найден — " +
                "проверьте content_main.xml и пересоберите APK начисто");
        }

        // Если NavHostFragment ещё не успел создать свой graph (крайне редкий случай),
        // дожидаемся корректного графа, иначе приложение покажет пустый экран.
        NavController navController = navHostFragment.getNavController();
        if (navController.getGraph() == null) {
            throw new IllegalStateException(
                "NavController не имеет графа навигации — проверьте app:navGraph=\"@navigation/nav_graph\" " +
                "в content_main.xml и наличие nav_graph.xml в res/navigation/");
        }

        appBarConfiguration = new AppBarConfiguration.Builder(navController.getGraph()).build();
        NavigationUI.setupActionBarWithNavController(this, navController, appBarConfiguration);

        binding.fabRecord.setOnClickListener(view ->
                navController.navigate(R.id.action_LectureListFragment_to_RecordingFragment));
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_main, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();

        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings) {
            return true;
        }

        if (id == R.id.action_plugins) {
            getSupportFragmentManager()
                .beginTransaction()
                .replace(R.id.nav_host_fragment_content_main, new PluginsFragment())
                .addToBackStack(null)
                .commit();
            return true;
        }

        return super.onOptionsItemSelected(item);
    }

    @Override
    public boolean onSupportNavigateUp() {
        // Получаем NavController через supportFragmentManager (может быть null, если
        // на экране сейчас PluginsFragment — тогда просто поднимаем back stack).
        androidx.navigation.fragment.NavHostFragment navHostFragment =
            (androidx.navigation.fragment.NavHostFragment) getSupportFragmentManager()
                .findFragmentById(R.id.nav_host_fragment_content_main);
        if (navHostFragment == null) {
            // Сейчас в контейнере обычный Fragment (например, PluginsFragment) — просто выходим назад.
            getSupportFragmentManager().popBackStack();
            return true;
        }
        NavController navController = navHostFragment.getNavController();
        return NavigationUI.navigateUp(navController, appBarConfiguration)
                || super.onSupportNavigateUp();
    }
}