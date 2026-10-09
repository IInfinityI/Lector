package com.example.lector.services;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;

import com.example.lector.MainActivity;
import com.example.lector.R;

/**
 * Foreground-сервис, удерживающий запись аудио живой при свернутом приложении.
 * Саму запись выполняет AudioRecorderService (обычный класс-обёртка над MediaRecorder);
 * этот сервис лишь обеспечивает high-importance уведомление и жизненный цикл.
 *
 * Использование:
 *   startService(new Intent(ctx, RecordingForegroundService.class).putExtra(EXTRA_PATH, path))
 *   stopService(new Intent(ctx, RecordingForegroundService.class))
 */
public class RecordingForegroundService extends Service {

    public static final String EXTRA_PATH = "recording_path";
    private static final String CHANNEL_ID = "lector_recording";
    private static final int NOTIFICATION_ID = 42;

    @Override
    public void onCreate() {
        super.onCreate();
        createChannel();
    }

    @Override
    public int onStartCommand(@Nullable Intent intent, int flags, int startId) {
        String path = intent != null ? intent.getStringExtra(EXTRA_PATH) : null;
        startForeground(NOTIFICATION_ID, buildNotification(path));
        // Если процесс сервиса убит системой — не пересоздаём автоматически,
        // пользователь увидит остановку по уведомлению.
        return START_NOT_STICKY;
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private Notification buildNotification(String path) {
        Intent tapIntent = new Intent(this, MainActivity.class);
        tapIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        int flags = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                ? PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
                : PendingIntent.FLAG_UPDATE_CURRENT;
        PendingIntent pi = PendingIntent.getActivity(this, 0, tapIntent, flags);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(getString(R.string.notification_recording_title))
                .setContentText(path != null ? shortName(path)
                        : getString(R.string.notification_recording_default))
                .setSmallIcon(R.drawable.ic_mic)
                .setOngoing(true)
                .setSilent(true)
                .setContentIntent(pi)
                .setPriority(NotificationCompat.PRIORITY_HIGH);
        return builder.build();
    }

    private static String shortName(String path) {
        int i = path.lastIndexOf('/');
        return i >= 0 ? path.substring(i + 1) : path;
    }

    private void createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null && nm.getNotificationChannel(CHANNEL_ID) == null) {
                NotificationChannel channel = new NotificationChannel(
                        CHANNEL_ID,
                        getString(R.string.notification_channel_name),
                        NotificationManager.IMPORTANCE_LOW);
                channel.setDescription(getString(R.string.notification_channel_desc));
                nm.createNotificationChannel(channel);
            }
        }
    }
}
