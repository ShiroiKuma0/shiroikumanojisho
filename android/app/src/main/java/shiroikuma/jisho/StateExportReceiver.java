package shiroikuma.jisho;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * Exported receiver for the 保存復元 state-export automation contract:
 * {@code shiroikuma.jisho.action.EXPORT_STATE} and
 * {@code shiroikuma.jisho.action.LIST_CATEGORIES}. Token-gated; the
 * reply is always a fresh broadcast (never a Binder — EMUI drops
 * those between third-party apps; verified on 白い熊's Mate XT,
 * 2026-07-23).
 *
 * LIST_CATEGORIES answers instantly from a static table.
 * EXPORT_STATE hands off to {@link StateExportService} (a foreground
 * service hosting a headless Flutter engine), which does the work and
 * sends the terminal reply — exports can exceed a receiver's budget.
 */
public class StateExportReceiver extends BroadcastReceiver {
    private static final String TAG = "StateExportReceiver";

    static final String ACTION_EXPORT = "shiroikuma.jisho.action.EXPORT_STATE";
    static final String ACTION_LIST = "shiroikuma.jisho.action.LIST_CATEGORIES";

    /**
     * Mirror of the Dart StateExport.categories table (id, label,
     * optional parent). Kept in Java so LIST_CATEGORIES needs no
     * engine spin-up; the Dart side is the source of truth for ids.
     */
    static final String CATEGORIES_LISTING =
        "ui_theme\tUI theme (colours · fonts · shapes)\n" +
        "player\tPlayer & subtitles\n" +
        "reader\tReader & audio toolbar\n" +
        "dictionary\tDictionary & search\n" +
        "creator\tCreator & Anki\n" +
        "other\tOther settings\n" +
        "artifacts\tGenerated artifacts\n" +
        "artifacts.pdf\tScanned-PDF OCR volumes\tartifacts\n" +
        "artifacts.ocr\tSubtitle OCR bitmaps\tartifacts\n" +
        "artifacts.fonts\tImported fonts\tartifacts";

    static void sendReply(Context context, String replyAction,
                          String replyPackage, String replyId,
                          String result) {
        if (replyAction == null || replyPackage == null) {
            return;
        }
        Intent reply = new Intent(replyAction);
        reply.setPackage(replyPackage);
        reply.addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES);
        reply.putExtra("reply_id", replyId);
        reply.putExtra("result", result);
        context.sendBroadcast(reply);
        // E-priority on purpose: this device (EMUI) suppresses
        // info-level logging, and this line is the checklist's
        // observability channel.
        Log.e(TAG, "reply " + replyId + ": "
            + (result.length() > 120 ? result.substring(0, 120) + "…" : result));
    }

    private void replySync(Context context, String replyAction,
                           String replyPackage, String replyId,
                           String result) {
        sendReply(context, replyAction, replyPackage, replyId, result);
        if (isOrderedBroadcast()) {
            setResultData(result);
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        final String action = intent.getAction();
        final String token = intent.getStringExtra("token");
        final String replyAction = intent.getStringExtra("reply_action");
        final String replyPackage = intent.getStringExtra("reply_package");
        final String replyId = intent.getStringExtra("reply_id");

        if (!ACTION_EXPORT.equals(action) && !ACTION_LIST.equals(action)) {
            return;
        }

        // Gate: switch first, then token — distinct errors by design.
        // Synchronous outcomes also go into the ordered-broadcast
        // result data: correct-but-never-sufficient AOSP behaviour
        // (EMUI severs it between third-party apps; the broadcast
        // reply is the real channel) — and it makes `adb shell am
        // broadcast` print the outcome directly.
        if (!AutomationPrefs.isEnabled(context)) {
            replySync(context, replyAction, replyPackage, replyId,
                "ERROR:automation disabled");
            return;
        }
        if (!AutomationPrefs.tokenMatches(context, token)) {
            replySync(context, replyAction, replyPackage, replyId,
                "ERROR:bad token");
            return;
        }

        if (ACTION_LIST.equals(action)) {
            replySync(context, replyAction, replyPackage, replyId,
                "OK:" + CATEGORIES_LISTING);
            return;
        }
        if (isOrderedBroadcast()) {
            setResultData("OK:export started");
        }

        // EXPORT_STATE → foreground service; it replies when done.
        Intent service = new Intent(context, StateExportService.class);
        service.putExtra("path", intent.getStringExtra("path"));
        service.putExtra("items", intent.getStringExtra("items"));
        service.putExtra("progress_action",
            intent.getStringExtra("progress_action"));
        service.putExtra("reply_action", replyAction);
        service.putExtra("reply_package", replyPackage);
        service.putExtra("reply_id", replyId);
        try {
            context.startForegroundService(service);
        } catch (Exception e) {
            sendReply(context, replyAction, replyPackage, replyId,
                "ERROR:" + e.getMessage());
        }
    }
}
