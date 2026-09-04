package shiroikuma.jisho;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.content.pm.PackageInfo;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;

/**
 * The data door: export this app's own state, and put it back, for a
 * caller we can identify. The v2 half of the 保存復元 contract; it sits
 * <em>alongside</em> {@link StateExportReceiver}, it does not replace
 * it.
 *
 * <h3>Why a provider and not the broadcast receiver next to it</h3>
 *
 * <b>A broadcast cannot tell you who sent it.</b> v1's answer to that
 * was a shared secret, which cannot survive the wipe this feature
 * exists to recover from. A provider gets the caller's identity from
 * the framework for free — see {@link AutomationCallers} for what is
 * actually checked, and why a package-name prefix would have been worse
 * than the token it replaced.
 *
 * <b>And a list needs a synchronous answer.</b> 応用管理 draws a row per
 * installed app before any export exists; a broadcast round trip per
 * app to fill a list is the wrong shape entirely.
 *
 * <h3>What does NOT happen here</h3>
 *
 * The payload. {@code call()} validates, starts a foreground service
 * and returns — tens of megabytes over minutes inside a binder call
 * would block the caller, report no progress, refuse cancellation and
 * die silently if this process were killed. The bytes go through a file
 * descriptor the caller opened, and the terminal answer comes back on
 * the broadcast the family already proved on EMUI.
 *
 * <h3>Why a descriptor and not a path</h3>
 *
 * Because a backup is not a stable directory while it is being
 * assembled. 応用管理 writes into a temporary path and renames on
 * commit; it encrypts and checksums <b>per file it knows about</b>. A
 * file this app dropped into that directory itself would be renamed out
 * from under it, would sit in plaintext inside an otherwise encrypted
 * backup, and would be unverified rather than verified-and-failing. A
 * descriptor is also a capability that <b>expires when it is closed</b>.
 *
 * <p>It also means this app no longer needs
 * {@code MANAGE_EXTERNAL_STORAGE} for the automation path — that
 * permission was only ever required because v1 handed apps an absolute
 * path.
 */
public class AutomationProvider extends ContentProvider {

    static final String METHOD_DESCRIBE = "describe";
    static final String METHOD_EXPORT = "export";
    static final String METHOD_IMPORT = "import";
    static final String METHOD_CANCEL = "cancel";

    static final String KEY_RESULT = "result";
    static final String KEY_FD = "fd";
    static final String KEY_TOKEN = "token";
    static final String KEY_JOB_ID = "job_id";
    static final String KEY_ITEMS = "items";
    static final String KEY_REPLY_ACTION = "reply_action";
    static final String KEY_REPLY_PACKAGE = "reply_package";
    static final String KEY_PROGRESS_ACTION = "progress_action";

    /**
     * This app's archive format — the same {@code StateExport.version}
     * the ZIP's manifest carries. Bumped when an older build could no
     * longer read what we write.
     */
    static final int FORMAT = 1;

    /**
     * The oldest archive this build can still read.
     *
     * Version skew has a direction: old data into a newer app is
     * normally fine, because an app migrates its own storage; newer
     * data into an older app is not. This field is what lets a caller
     * refuse the second case at discovery time, before anything is
     * streamed.
     */
    static final int MIN_FORMAT_READABLE = 1;

    @Override
    public boolean onCreate() {
        return true;
    }

    /**
     * Every method answers a {@link Bundle} with {@link #KEY_RESULT} —
     * {@code OK…} or {@code ERROR:…}, the same vocabulary the broadcast
     * contract uses, so a caller has one grammar to parse rather than
     * two.
     *
     * <p>A refusal is <b>returned, never thrown</b>: an exception
     * across a binder reaches the caller as a {@code RuntimeException}
     * carrying our stack trace, which tells 白い熊 nothing and tells a
     * misbehaving caller rather more than it should.
     */
    @Override
    public Bundle call(String method, String arg, Bundle extras) {
        Context context = getContext();
        if (context == null) {
            return fail("ERROR:not ready");
        }
        try {
            // WHO, before WHAT. A caller we cannot identify gets the
            // same answer whatever it asked for.
            String refusal = AutomationCallers.verify(context, getCallingPackage());
            if (refusal != null) {
                return fail(refusal);
            }
            // Then this app's own switches — a token is ignored unless
            // this app asks for one (see AutomationPrefs#refuse).
            String gated = AutomationPrefs.refuse(context,
                extras == null ? null : extras.getString(KEY_TOKEN));
            if (gated != null) {
                return fail(gated);
            }

            if (METHOD_DESCRIBE.equals(method)) {
                return ok(describe(context));
            }
            if (METHOD_EXPORT.equals(method)) {
                return start(context, extras, false);
            }
            if (METHOD_IMPORT.equals(method)) {
                return start(context, extras, true);
            }
            if (METHOD_CANCEL.equals(method)) {
                String jobId = extras == null ? null : extras.getString(KEY_JOB_ID);
                if (jobId == null) {
                    AutomationJobs.cancelAll();
                } else {
                    AutomationJobs.cancel(jobId);
                }
                AutomationDataService.requestCancel(context, jobId);
                return ok("OK:cancelled");
            }
            return fail("ERROR:unknown method: " + method);
        } catch (Throwable t) {
            // The no-throw rule applies to our own bugs too.
            return fail("ERROR:" + t.getClass().getSimpleName()
                + ": " + t.getMessage());
        }
    }

    /**
     * What this app would export, answered without exporting anything.
     *
     * Returned from the call rather than written into the archive,
     * deliberately: 応用管理 must draw a row before an export exists,
     * and at restore must judge compatibility <b>before</b> streaming
     * tens of megabytes into an app that would reject them — which it
     * cannot do if the header is buried inside an encrypted archive.
     *
     * <p>{@code requires_launch_first} is false: the import path writes
     * the Hive box and the app-documents tree directly through a
     * headless engine, which does not need a prior UI launch.
     */
    private String describe(Context context) throws Exception {
        PackageInfo info = context.getPackageManager()
            .getPackageInfo(context.getPackageName(), 0);
        @SuppressWarnings("deprecation")
        int versionCode = info.versionCode;
        StringBuilder contains = new StringBuilder();
        for (String label : StateExportReceiver.topLevelLabels()) {
            if (contains.length() > 0) {
                contains.append(',');
            }
            contains.append('"').append(label).append('"');
        }
        return "OK:{\"app_id\":\"" + context.getPackageName() + "\","
            + "\"version_code\":" + versionCode + ","
            + "\"version_name\":\"" + info.versionName + "\","
            + "\"format\":" + FORMAT + ","
            + "\"min_format_readable\":" + MIN_FORMAT_READABLE + ","
            + "\"requires_launch_first\":false,"
            + "\"contains\":[" + contains + "]}";
    }

    /**
     * Hand the descriptor to a foreground service and get out of the
     * way.
     *
     * The descriptor is <b>duplicated</b> before it leaves this method.
     * The one in {@code extras} belongs to the binder transaction and
     * is closed the moment {@code call()} returns; a service reading it
     * afterwards would find it shut. That is a bug you only see under
     * load, so it is not left to the service to remember.
     */
    private Bundle start(Context context, Bundle extras, boolean importing) {
        if (extras == null) {
            return fail("ERROR:no descriptor");
        }
        @SuppressWarnings("deprecation")
        ParcelFileDescriptor supplied = extras.getParcelable(KEY_FD);
        if (supplied == null) {
            return fail("ERROR:no descriptor");
        }
        ParcelFileDescriptor duplicate;
        try {
            duplicate = supplied.dup();
        } catch (Exception e) {
            return fail("ERROR:descriptor unusable");
        }
        String jobId = AutomationJobs.begin();
        try {
            AutomationDataService.start(context, jobId, duplicate, importing, extras);
        } catch (Exception e) {
            AutomationJobs.finish(jobId);
            try {
                duplicate.close();
            } catch (Exception ignored) {
                // Nothing useful to do; the caller's copy is its own.
            }
            return fail("ERROR:" + e.getMessage());
        }
        return ok("OK:" + jobId);
    }

    private Bundle ok(String result) {
        Bundle bundle = new Bundle();
        bundle.putString(KEY_RESULT, result);
        return bundle;
    }

    private Bundle fail(String why) {
        Bundle bundle = new Bundle();
        bundle.putString(KEY_RESULT, why);
        return bundle;
    }

    // A provider that is only ever call()ed still has to answer these.
    // Refusing loudly beats returning an empty cursor, which reads
    // downstream as "there is no data" rather than "wrong door".
    @Override
    public Cursor query(Uri uri, String[] projection, String selection,
                        String[] selectionArgs, String sortOrder) {
        throw new UnsupportedOperationException("automation is call() only");
    }

    @Override
    public String getType(Uri uri) {
        return null;
    }

    @Override
    public Uri insert(Uri uri, ContentValues values) {
        throw new UnsupportedOperationException("automation is call() only");
    }

    @Override
    public int delete(Uri uri, String selection, String[] selectionArgs) {
        throw new UnsupportedOperationException("automation is call() only");
    }

    @Override
    public int update(Uri uri, ContentValues values, String selection,
                      String[] selectionArgs) {
        throw new UnsupportedOperationException("automation is call() only");
    }
}
