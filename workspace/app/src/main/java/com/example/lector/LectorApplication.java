package com.example.lector;

import android.app.Application;

/**
 * Application-класс Lector.
 *
 * Нужен для того, чтобы падение при инициализации приложения (например, ошибка
 * загрузки мода) было видно в logcat с тегом "LectorApp" вместо тихого закрытия
 * окна на пустом экране.
 */
public class LectorApplication extends Application {

    private static final String TAG = "LectorApp";

    @Override
    public void onCreate() {
        super.onCreate();
        Thread.setDefaultUncaughtExceptionHandler((t, e) -> {
            android.util.Log.e(TAG, "Необработанная ошибка в " + t.getName(), e);
            // Стандартное поведение Android: завершение процесса
            android.os.Process.killProcess(android.os.Process.myPid());
            System.exit(10);
        });
    }
}
