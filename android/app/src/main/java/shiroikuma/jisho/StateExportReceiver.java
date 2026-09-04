package shiroikuma.jisho;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * Exported receiver for the 保存復元 state-export automation contract:
 * {@code shiroikuma.jisho.action.EXPORT_STATE},
 * {@code shiroikuma.jisho.action.LIST_CATEGORIES} and
 * {@code shiroikuma.jisho.action.CANCEL_EXPORT}. The reply is always a
 * fresh broadcast (never a Binder — EMUI drops those between
 * third-party apps; verified on 白い熊's Mate XT, 2026-07-23).
 *
 * <p>In v2 this receiver is the deliberately <b>unauthenticated</b>
 * half of the surface: it only ever writes where it was told to and
 * reports what it did. Everything that moves data through a
 * caller-supplied descriptor lives behind {@link AutomationProvider},
 * which knows who is calling. The gate here is
 * {@link AutomationPrefs#refuse} — one function, so "disabled" and
 * "bad token" cannot drift apart across the family.
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
    static final String ACTION_CANCEL = "shiroikuma.jisho.action.CANCEL_EXPORT";

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

    /**
     * The human labels of the top-level categories, for the
     * {@code contains} field of {@link AutomationProvider}'s describe
     * header. Parsed from {@link #CATEGORIES_LISTING} so the two
     * cannot drift: a line with a third TAB-separated field is a
     * sub-option and belongs to its parent, not to this list.
     */
    static java.util.List<String> topLevelLabels() {
        java.util.List<String> labels = new java.util.ArrayList<>();
        for (String line : CATEGORIES_LISTING.split("\n")) {
            String[] fields = line.split("\t");
            if (fields.length == 2) {
                labels.add(fields[1]);
            }
        }
        return labels;
    }

    static void sendReply(Context context, String replyAction,
                          String replyPackage, String replyId,
                          String result) {
        sendReply(context, replyAction, replyPackage, replyId, null, result);
    }

    /**
     * As above, but also carrying {@code job_id} — the data door's
     * correlation id, which 応用管理 was handed as {@code OK:<job_id>}
     * from {@link AutomationProvider}. Sent in BOTH {@code job_id} and
     * {@code reply_id} so a caller correlating on either key finds it;
     * the §1 receiver path has no job and passes null.
     */
    static void sendReply(Context context, String replyAction,
                          String replyPackage, String replyId,
                          String jobId, String result) {
        if (replyAction == null || replyPackage == null) {
            return;
        }
        Intent reply = new Intent(replyAction);
        reply.setPackage(replyPackage);
        reply.addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES);
        reply.putExtra("reply_id", replyId);
        if (jobId != null) {
            reply.putExtra("job_id", jobId);
        }
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

        if (!ACTION_EXPORT.equals(action) && !ACTION_LIST.equals(action)
            && !ACTION_CANCEL.equals(action)) {
            return;
        }

        // Gate: one function (AutomationPrefs#refuse) — the switch,
        // then the token only if this app asks for one. A token sent to
        // an app that does not require one is IGNORED, never refused.
        // Synchronous outcomes also go into the ordered-broadcast
        // result data: correct-but-never-sufficient AOSP behaviour
        // (EMUI severs it between third-party apps; the broadcast
        // reply is the real channel) — and it makes `adb shell am
        // broadcast` print the outcome directly.
        final String refusal = AutomationPrefs.refuse(context, token);

        if (ACTION_CANCEL.equals(action)) {
            // Fire-and-forget by contract: no reply of its own, ever.
            // The one terminal reply belongs to the export it stopped,
            // which answers ERROR:cancelled from the service. A cancel
            // arriving when nothing is running — or after the export
            // already finished — is a silent no-op, because 自由作業盤
            // fires it whenever 白い熊 presses 中止 without knowing how
            // far we got.
            if (refusal == null) {
                StateExportService.requestCancel(context, replyId);
                AutomationJobs.cancelAll();
            }
            return;
        }

        if (refusal != null) {
            replySync(context, replyAction, replyPackage, replyId, refusal);
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
