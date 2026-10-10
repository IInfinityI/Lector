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
        // Ошибка одного мода не должна ронять всё приложение — инициализацию
        // оборачиваем в try/catch, чтобы при сбое плагина открывался основной экран,
        // а не пустой/шаблонный экран из-за падения Activity.
        try {
            PluginManager.getInstance(this).initialize();
        } catch (Throwable t) {
            android.util.Log.e("LectorApp", "PluginManager.initialize() упал", t);
        }

        binding = ActivityMainBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        // CoordinatorLayout + AppBarLayout сами корректно обрабатывают системные отступы
        // (android:fitsSystemWindows="true" в разметке), поэтому не ставим свой listener.
        ViewCompat.setOnApplyWindowInsetsListener(binding.main, null);

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

        // ВАЖНО: MaterialToolbar в этом проекте объявлен внутри AppBarLayout как обычный
        // view, а не как android:theme="@style/...Toolbar" action bar. Вызов
        // setSupportActionBar(...) при отсутствии action bar в теме приводит к падению
        // ("The specified child already has a parent..." / IllegalStateException), и на
        // экране оставался лишь шаблонный текст. Toolbar работает самостоятельно
        // (app:title + навигация через NavigationUI), поэтому action bar не регистрируем.
        binding.toolbar.setTitle(getString(R.string.app_name));

        appBarConfiguration = new AppBarConfiguration.Builder(navController.getGraph()).build();
        // Связываем заголовок и кнопку «Назад» с NavController без привязки toolbar к action bar.
        NavigationUI.setupWithNavController(binding.toolbar, navController, appBarConfiguration);

        binding.fabRecord.setOnClickListener(view -> {
            // Кнопка записи активна только на экране библиотеки лекций; на других
            // экранах она скрывается (см. OnDestinationChangedListener ниже).
            try {
                navController.navigate(R.id.action_LectureListFragment_to_RecordingFragment);
            } catch (IllegalStateException e) {
                android.util.Log.e("LectorApp", "Не удалось открыть экран записи", e);
            }
        });

        // Показываем/скрываем FAB в зависимости от текущего экрана.
        navController.addOnDestinationChangedListener((ctrl, destination, args) -> {
            boolean onList = destination.getId() == R.id.LectureListFragment;
            binding.fabRecord.setVisibility(onList ? View.VISIBLE : View.GONE);
        });
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
            // Открываем экран «Моды» поверх NavHost-контейнера и сохраняем state,
            // чтобы при возврате назад восстановилась привычная навигация приложения.
            getSupportFragmentManager()
                .beginTransaction()
                .setReorderingAllowed(true)
                .replace(R.id.nav_host_fragment_content_main, new PluginsFragment())
                .addToBackStack("plugins")
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