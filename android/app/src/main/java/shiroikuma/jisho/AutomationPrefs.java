package shiroikuma.jisho;

import android.content.Context;
import android.content.SharedPreferences;

import java.security.MessageDigest;
import java.security.SecureRandom;

/**
 * Token infrastructure for the 保存復元 automation contract
 * (renrakusaki pattern): a device-local SharedPreferences file that is
 * deliberately NOT part of any export (exports read the Hive box and
 * app documents; this file lives in shared_prefs), holding the master
 * switch (default OFF) and a lazily-generated 24-byte hex token.
 */
final class AutomationPrefs {
    private static final String FILE = "automation_prefs";
    private static final String KEY_ENABLED = "automation_enabled";
    private static final String KEY_TOKEN = "automation_token";

    private AutomationPrefs() {}

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(FILE, Context.MODE_PRIVATE);
    }

    static boolean isEnabled(Context context) {
        return prefs(context).getBoolean(KEY_ENABLED, false);
    }

    static void setEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply();
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
        prefs(context).edit().putString(KEY_TOKEN, token).apply();
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
}
