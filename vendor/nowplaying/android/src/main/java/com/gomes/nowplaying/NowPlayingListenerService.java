package com.gomes.nowplaying;

import android.app.Notification;
import android.content.Intent;
import android.media.session.MediaController;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.os.Build;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;

import java.util.HashMap;
import java.util.Map;

/**
 * MIT License
 *
 * Copyright (c) 2020 Nic Ford
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
public class NowPlayingListenerService extends NotificationListenerService {
    public static final String FIELD_ACTION = "com.gomes.nowplaying.action";
    public static final String FIELD_TOKEN = "com.gomes.nowplaying.token";
    public static final String FIELD_ICON = "com.gomes.nowplaying.icon";
    public static final String ACTION_POSTED = "posted";
    public static final String ACTION_REMOVED = "removed";

    private final Map<String, MediaSession.Token> tokens = new HashMap<>();

    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        SbnAndToken sbnAndToken = findTokenForState();
        if (sbnAndToken != null) {
            tokens.put(sbnAndToken.sbn.getKey(), sbnAndToken.token);
            sendData(sbnAndToken.token, sbnAndToken.sbn, ACTION_POSTED);
        }
    }

    private SbnAndToken findTokenForState() {
        SbnAndToken playingToken = null;
        SbnAndToken pausedToken = null;

        for (StatusBarNotification sbn : this.getActiveNotifications()) {
            final MediaSession.Token token = getTokenIfAvailable(sbn);
            if (token != null) {
                final MediaController controller = new MediaController(this, token);
                PlaybackState playbackState = controller.getPlaybackState();
                if (playbackState != null) {
                    final int playbackStateNum = playbackState.getState();
                    if (playbackStateNum == PlaybackState.STATE_PLAYING)
                        playingToken = new SbnAndToken(sbn, token);
                    if (playbackStateNum == PlaybackState.STATE_PAUSED)
                        pausedToken = new SbnAndToken(sbn, token);
                }
            }
        }

        if (playingToken != null)
            return playingToken;
        return pausedToken; // may also be null
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        final MediaSession.Token token = getTokenIfAvailable(sbn);
        if (token != null) {
            tokens.put(sbn.getKey(), token);
            sendData(token, sbn, ACTION_POSTED);
        }
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        final MediaSession.Token token = tokens.remove(sbn.getKey());
        if (token != null)
            sendData(token, sbn, ACTION_REMOVED);
    }

    private void sendData(MediaSession.Token token, StatusBarNotification sbn, String action) {
        final Intent intent = new Intent(NowPlayingPlugin.ACTION);
        intent.putExtra(FIELD_ACTION, action);
        intent.putExtra(FIELD_TOKEN, token);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            intent.putExtra(FIELD_ICON, sbn.getNotification().getSmallIcon());
        }
        sendBroadcast(intent);
    }

    private MediaSession.Token getTokenIfAvailable(StatusBarNotification sbn) {
        final Notification notif = sbn.getNotification();
        final Bundle bundle = notif.extras;
        return bundle.getParcelable("android.mediaSession");
    }

    private static class SbnAndToken {
        protected final StatusBarNotification sbn;
        protected final MediaSession.Token token;

        public SbnAndToken(StatusBarNotification sbn, MediaSession.Token token) {
            this.sbn = sbn;
            this.token = token;
        }
    }
}
