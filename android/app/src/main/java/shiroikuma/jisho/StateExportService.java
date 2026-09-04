package shiroikuma.jisho;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.util.Log;

import androidx.core.app.NotificationCompat;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.plugin.common.MethodChannel;

/**
 * Foreground service running one headless state export for the
 * 保存復元 automation contract. Hosts a background {@link FlutterEngine}
 * whose entrypoint is {@code stateExportMain} (see main.dart); the
 * Dart side asks for the request over the
 * {@code shiroikuma.jisho/state_export} channel, streams progress
 * (real counts) which this service re-broadcasts, and delivers the
 * terminal result which this service replies with. Exactly one
 * terminal reply per request, guarded here.
 *
 * <h3>Cancellation</h3>
 *
 * {@code CANCEL_EXPORT} sets {@link #cancelled} on the running
 * instance. The Dart side polls it between entries — never mid-write —
 * so the archive unwinds at a boundary rather than being torn down
 * half-written; Dart deletes its {@code .part} on the way out, and the
 * terminal reply for the ORIGINAL request is {@code ERROR:cancelled},
 * sent even though 自由作業盤 stopped listening the moment 白い熊
 * pressed 中止 — the reply is what proves the run really ended rather
 * than continuing unseen.
 */
public class StateExportService extends Service {
    private static final String TAG = "StateExportService";
    private static final String CHANNEL_ID =
        "shiroikuma.jisho.channel.state_export";
    private static final int NOTIFICATION_ID = 1045;
    private static final long PROGRESS_THROTTLE_MS = 500;

    private FlutterEngine engine;
    private PowerManager.WakeLock wakeLock;
    private final AtomicBoolean replied = new AtomicBoolean(false);
    private long lastProgressAt = 0;
    private volatile boolean cancelled = false;
    private String replyIdInFlight;

    /** The run a cancel can reach. One export at a time, by contract. */
    private static volatile StateExportService running;

    /**
     * Ask the running export to stop. Silent by contract: a cancel for
     * a run that already finished, or that never started, is a no-op —
     * not an error, not a reply, not a crash.
     *
     * @param replyId the run to stop; null means "the one you are
     *                running", which is unambiguous because the
     *                contract forbids two at once.
     */
    static void requestCancel(Context context, String replyId) {
        StateExportService service = running;
        if (service == null) {
            return;
        }
        if (replyId != null && service.replyIdInFlight != null
            && !replyId.equals(service.replyIdInFlight)) {
            return;
        }
        service.cancelled = true;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID, "State export",
                NotificationManager.IMPORTANCE_LOW);
            channel.setShowBadge(false);
            getSystemService(NotificationManager.class)
                .createNotificationChannel(channel);
        }
        PowerManager powerManager =
            (PowerManager) getSystemService(POWER_SERVICE);
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK, "shiroikuma.jisho:stateExport");
        wakeLock.setReferenceCounted(false);
    }

    private void notifyProgress(String text) {
        Notification notification =
            new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(getApplicationInfo().icon)
                .setContentTitle("保存復元 — 白い熊 辞書")
                .setContentText(text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .build();
        startForeground(NOTIFICATION_ID, notification);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        notifyProgress("Starting…");
        if (!wakeLock.isHeld()) {
            wakeLock.acquire(90 * 60 * 1000L);
        }

        final String pathExtra = intent.getStringExtra("path");
        final String items = intent.getStringExtra("items");
        final String progressAction = intent.getStringExtra("progress_action");
        final String replyAction = intent.getStringExtra("reply_action");
        final String replyPackage = intent.getStringExtra("reply_package");
        final String replyId = intent.getStringExtra("reply_id");
        replyIdInFlight = replyId;
        running = this;

        engine = new FlutterEngine(this);
        MethodChannel channel = new MethodChannel(
            engine.getDartExecutor().getBinaryMessenger(),
            "shiroikuma.jisho/state_export");
        channel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "getRequest": {
                    Map<String, Object> request = new HashMap<>();
                    request.put("path", pathExtra);
                    request.put("items", items);
                    result.success(request);
                    break;
                }
                case "isCancelled": {
                    // Polled at write boundaries, never mid-write.
                    result.success(cancelled);
                    break;
                }
                case "progress": {
                    long now = System.currentTimeMillis();
                    String text = call.argument("text");
                    Number current = call.argument("current");
                    Number total = call.argument("total");
                    String unit = call.argument("unit");
                    Boolean isFinal = call.argument("final");
                    // Throttle both the notification refresh and the
                    // outgoing broadcast to one per 500ms — exports can
                    // report thousands of files. A final-flagged report
                    // always goes out (contract requirement).
                    if (Boolean.TRUE.equals(isFinal)
                        || now - lastProgressAt >= PROGRESS_THROTTLE_MS) {
                        lastProgressAt = now;
                        if (text != null) {
                            notifyProgress(text);
                        }
                        if (progressAction != null) {
                        Intent progress = new Intent(progressAction);
                        progress.setPackage(replyPackage);
                        progress.addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES);
                        progress.putExtra("reply_id", replyId);
                        progress.putExtra("app", "白い熊 辞書");
                        progress.putExtra("text", text);
                        progress.putExtra("current",
                            current == null ? 0L : current.longValue());
                        progress.putExtra("total",
                            total == null ? 0L : total.longValue());
                        progress.putExtra("unit", unit);
                        sendBroadcast(progress);
                        }
                    }
                    result.success(null);
                    break;
                }
                case "done": {
                    String resultLine = call.argument("result");
                    // The same AtomicBoolean guards success and cancel,
                    // so the two can never double-fire.
                    if (replied.compareAndSet(false, true)) {
                        StateExportReceiver.sendReply(this, replyAction,
                            replyPackage, replyId,
                            cancelled ? "ERROR:cancelled" : resultLine);
                    }
                    result.success(null);
                    // Engine teardown must happen on the main thread,
                    // after this handler returns.
                    new Handler(Looper.getMainLooper()).post(this::stopSelf);
                    break;
                }
                default:
                    result.notImplemented();
            }
        });

        Log.e(TAG, "starting headless export, reply_id=" + replyId);
        engine.getDartExecutor().executeDartEntrypoint(
            new DartExecutor.DartEntrypoint(
                io.flutter.FlutterInjector.instance()
                    .flutterLoader()
                    .findAppBundlePath(),
                "stateExportMain"));
        return START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        if (running == this) {
            running = null;
        }
        if (engine != null) {
            engine.destroy();
            engine = null;
        }
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
