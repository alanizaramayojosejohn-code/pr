package com.davidmorales.pr;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;
import androidx.core.app.NotificationCompat;

public class WorkoutTimerService extends Service {

    public static final String CHANNEL_ID      = "workout_timer_channel";
    public static final int    NOTIFICATION_ID  = 1001;

    public static final String ACTION_START   = "com.davidmorales.pr.TIMER_START";
    public static final String ACTION_PAUSE   = "com.davidmorales.pr.TIMER_PAUSE";
    public static final String ACTION_RESUME  = "com.davidmorales.pr.TIMER_RESUME";
    public static final String ACTION_STOP    = "com.davidmorales.pr.TIMER_STOP";
    public static final String EXTRA_NAME     = "routineName";

    private String  routineName     = "Entrenamiento";
    private boolean isPaused        = false;
    private long    startedAtMs     = 0;   // epoch ms adjusted: (now - startedAtMs) = elapsed
    private long    pausedElapsedMs = 0;   // frozen elapsed when paused

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) return START_NOT_STICKY;

        String action = intent.getAction();
        if (action == null) action = ACTION_START;

        switch (action) {
            case ACTION_START:
                String name = intent.getStringExtra(EXTRA_NAME);
                routineName     = name != null ? name : "Entrenamiento";
                startedAtMs     = System.currentTimeMillis();
                pausedElapsedMs = 0;
                isPaused        = false;
                createChannel();
                launchForeground();
                break;

            case ACTION_PAUSE:
                if (!isPaused) {
                    pausedElapsedMs = System.currentTimeMillis() - startedAtMs;
                    isPaused = true;
                    updateNotification();
                }
                break;

            case ACTION_RESUME:
                if (isPaused) {
                    startedAtMs = System.currentTimeMillis() - pausedElapsedMs;
                    isPaused    = false;
                    updateNotification();
                }
                break;

            case ACTION_STOP:
                stopForeground(true);
                stopSelf();
                break;
        }
        return START_STICKY;
    }

    private void launchForeground() {
        Notification n = buildNotification();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH);
        } else {
            startForeground(NOTIFICATION_ID, n);
        }
    }

    private void createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel ch = new NotificationChannel(
                CHANNEL_ID,
                "Timer de entrenamiento",
                NotificationManager.IMPORTANCE_LOW
            );
            ch.setDescription("Tiempo del entrenamiento activo");
            ch.setSound(null, null);
            ch.enableVibration(false);
            getSystemService(NotificationManager.class).createNotificationChannel(ch);
        }
    }

    private Notification buildNotification() {
        Intent openIntent = getPackageManager().getLaunchIntentForPackage(getPackageName());
        PendingIntent openPi = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        String pauseLabel  = isPaused ? "Continuar" : "Pausar";
        String pauseAction = isPaused ? ACTION_RESUME : ACTION_PAUSE;
        Intent pauseIntent = new Intent(this, WorkoutTimerService.class).setAction(pauseAction);
        PendingIntent pausePi = PendingIntent.getService(
            this, 1, pauseIntent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        Intent stopIntent = new Intent(this, WorkoutTimerService.class).setAction(ACTION_STOP);
        PendingIntent stopPi = PendingIntent.getService(
            this, 2, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        NotificationCompat.Builder b = new NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(routineName)
            .setContentIntent(openPi)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(0, pauseLabel, pausePi)
            .addAction(0, "Finalizar", stopPi);

        if (isPaused) {
            b.setContentText("En pausa · " + formatMs(pausedElapsedMs));
            b.setShowWhen(false);
            b.setUsesChronometer(false);
        } else {
            b.setContentText("Entrenando…");
            b.setWhen(startedAtMs);
            b.setShowWhen(true);
            b.setUsesChronometer(true);
        }

        return b.build();
    }

    private void updateNotification() {
        getSystemService(NotificationManager.class).notify(NOTIFICATION_ID, buildNotification());
    }

    private String formatMs(long ms) {
        long total = ms / 1000;
        return String.format("%d:%02d", total / 60, total % 60);
    }

    @Override
    public IBinder onBind(Intent intent) { return null; }
}
