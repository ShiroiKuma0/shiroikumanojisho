package shiroikuma.jisho;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;

import androidx.core.app.NotificationCompat;

/**
 * Foreground service that keeps the process alive and unfrozen during
 * a long in-app import (scanned-PDF OCR: hundreds of pages, minutes of
 * CPU). Without it, EMUI and friends freeze the app the moment it is
 * backgrounded and the import silently stalls.
 *
 * Driven over the {@code shiroikuma.jisho/import_fg} MethodChannel in
 * {@link MainActivity}: "start"/"update" (re)post the notification with
 * the given title/text; "stop" ends the service. A partial wakelock is
 * held for the service's lifetime so page rendering and ML Kit keep
 * the CPU while the screen is off; it is released on stop -- finite,
 * user-initiated work only.
 */
public class ImportForegroundService extends Service {
    static final String EXTRA_TITLE = "title";
    static final String EXTRA_TEXT = "text";

    private static final String CHANNEL_ID = "shiroikuma.jisho.channel.import";
    private static final int NOTIFICATION_ID = 1044;

    private PowerManager.WakeLock wakeLock;

    @Override
    public void onCreate() {
        super.onCreate();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID, "Import", NotificationManager.IMPORTANCE_LOW);
            channel.setShowBadge(false);
            getSystemService(NotificationManager.class)
                .createNotificationChannel(channel);
        }
        PowerManager powerManager = (PowerManager) getSystemService(POWER_SERVICE);
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK, "shiroikuma.jisho:import");
        wakeLock.setReferenceCounted(false);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String title = intent != null ? intent.getStringExtra(EXTRA_TITLE) : null;
        String text = intent != null ? intent.getStringExtra(EXTRA_TEXT) : null;
        Notification notification = new NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(getApplicationInfo().icon)
            .setContentTitle(title == null ? "Importing" : title)
            .setContentText(text == null ? "" : text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build();
        startForeground(NOTIFICATION_ID, notification);
        if (!wakeLock.isHeld()) {
            // 90-minute ceiling: even if a bug ever skips "stop", the
            // lock cannot pin the CPU indefinitely.
            wakeLock.acquire(90 * 60 * 1000L);
        }
        return START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        if (wakeLock != null && wakeLock.isHeld()) {
            wakeLock.release();
        }
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
