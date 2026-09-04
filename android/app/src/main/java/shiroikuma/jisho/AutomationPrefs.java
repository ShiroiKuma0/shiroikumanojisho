package shiroikuma.jisho;

import android.content.Context;
import android.content.SharedPreferences;

import java.security.MessageDigest;
import java.security.SecureRandom;

/**
 * The gate for the 保存復元 automation contract (v2): a device-local
 * SharedPreferences file that is deliberately NOT part of any export
 * (exports read the Hive box and app documents; this file lives in
 * shared_prefs).
 *
 * <h3>What changed in v2, and why it had to</h3>
 *
 * v1 shipped closed: {@code automation_enabled} defaulted to false and
 * every caller had to present a secret 白い熊 had pasted from this app's
 * settings into the caller's. That is the wrong shape for the case this
 * family now exists to serve — 応用管理 restoring apps <em>and their
 * data</em> onto a clean phone, where nothing has been configured yet
 * and nobody has pasted anything. A pasted secret cannot survive a
 * wipe, so a gate that only works once the phone is already set up is
 * no gate for setting the phone up.
 *
 * So the switch now defaults ON, the token is opt-in via
 * {@code automation_require_token} (default OFF), and the real identity
 * check moved to {@link AutomationCallers} on the provider — which asks
 * the framework who is calling instead of asking the caller to prove it
 * knows a string.
 *
 * <h3>Why every write here is {@code commit()}, not {@code apply()}</h3>
 *
 * 応用管理 force-stops this app the instant it replies success to an
 * import — deliberately, because a process shutting down orderly writes
 * its cached preferences back out and would silently undo the import.
 * That SIGKILL can also land before an {@code apply()} has reached
 * disk, and each of these three writes is one that must not evaporate:
 *
 * <ul>
 *   <li>a lost {@code setEnabled(false)} silently REOPENS automation,
 *       because v2's default is ON — it would undo the one action
 *       白い熊 has for closing this app off;</li>
 *   <li>a lost {@code setTokenRequired(true)} stops the door asking for
 *       the token that was just turned on;</li>
 *   <li>a lost token is worse still: 白い熊 may already have pasted the
 *       generated value into a caller, and it would no longer match.</li>
 * </ul>
 *
 * These are three tiny, infrequent writes. Synchronous is the right
 * trade for every one of them.
 */
final class AutomationPrefs {
    private static final String FILE = "automation_prefs";
    private static final String KEY_ENABLED = "automation_enabled";
    private static final String KEY_REQUIRE_TOKEN = "automation_require_token";
    private static final String KEY_TOKEN = "automation_token";

    private AutomationPrefs() {}

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(FILE, Context.MODE_PRIVATE);
    }

    /** v2: default ON — see the class comment. */
    static boolean isEnabled(Context context) {
        return prefs(context).getBoolean(KEY_ENABLED, true);
    }

    static void setEnabled(Context context, boolean enabled) {
        // commit(), not apply() — see the note on writes below.
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).commit();
    }

    /** v2: default OFF — the token is opt-in, not the primary gate. */
    static boolean isTokenRequired(Context context) {
        return prefs(context).getBoolean(KEY_REQUIRE_TOKEN, false);
    }

    static void setTokenRequired(Context context, boolean required) {
        prefs(context).edit().putBoolean(KEY_REQUIRE_TOKEN, required).commit();
    }

    /** Lazily generates on first read so the settings row always shows a value. */
    static String getToken(Context context) {
        String token = prefs(context).getString(KEY_TOKEN, null);
        if (token == null || token.isEmpty()) {
            token = regenerateToken(context);
        }
        return token;
    }

    static String regenerateToken(Context context) {
        byte[] bytes = new byte[24];
        new SecureRandom().nextBytes(bytes);
        StringBuilder builder = new StringBuilder(bytes.length * 2);
        for (byte b : bytes) {
            builder.append(String.format("%02x", b));
        }
        String token = builder.toString();
        prefs(context).edit().putString(KEY_TOKEN, token).commit();
        return token;
    }

    /** Constant-time comparison against the stored token. */
    static boolean tokenMatches(Context context, String candidate) {
        if (candidate == null) {
            return false;
        }
        String stored = getToken(context);
        return MessageDigest.isEqual(
            candidate.getBytes(), stored.getBytes());
    }

    /**
     * The whole gate, in ONE place — {@code null} means proceed,
     * otherwise the exact {@code ERROR:} line to answer with.
     *
     * Written once rather than at each entry point because two copies
     * of "disabled" and "bad token" are how the two drift apart across
     * forty-two apps.
     *
     * <p><b>A token handed to an app that does not require one is
     * IGNORED, never an error.</b> Tokens live in task arguments and
     * workspace variables that outlive the setting they were pasted
     * for; a caller still sending one — because it was configured last
     * year, or because another app in the same batch does want one —
     * must be served. Refusing it would turn "白い熊 turned a switch
     * off" into "half the batch mysteriously fails", which is exactly
     * the friction the switch exists to remove.
     */
    static String refuse(Context context, String candidate) {
        if (!isEnabled(context)) {
            return "ERROR:automation disabled";
        }
        if (isTokenRequired(context) && !tokenMatches(context, candidate)) {
            return "ERROR:bad token";
        }
        return null;
    }
}
