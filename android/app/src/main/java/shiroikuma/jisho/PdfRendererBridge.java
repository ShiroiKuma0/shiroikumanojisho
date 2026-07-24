package shiroikuma.jisho;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.pdf.PdfRenderer;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;

import androidx.annotation.NonNull;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/**
 * MethodChannel bridge exposing Android's built-in {@link PdfRenderer}
 * to Dart, so scanned PDFs can be rasterised to page JPEGs for OCR
 * without adding a Flutter PDF plugin (which would demand a newer
 * AGP/Gradle toolchain than this project pins).
 *
 * Channel: {@code shiroikuma.jisho/pdf}
 * Methods:
 *   open(path)                       -> int pageCount
 *   renderPage(index, maxWidth, quality)
 *       -> {bytes: byte[] JPEG, width: int, height: int}
 *   close()                          -> null
 *
 * Rendering runs on a single background thread; PdfRenderer is not
 * thread-safe, so the serial executor doubles as its lock. Results are
 * posted back on the main looper as the platform channel requires.
 */
public class PdfRendererBridge {
    private static final String PDF_CHANNEL = "shiroikuma.jisho/pdf";

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private ParcelFileDescriptor fileDescriptor;
    private PdfRenderer renderer;

    void register(@NonNull FlutterEngine flutterEngine) {
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), PDF_CHANNEL)
            .setMethodCallHandler(
                (call, result) -> {
                    switch (call.method) {
                        case "open": {
                            final String path = call.argument("path");
                            executor.execute(() -> open(path, result));
                            break;
                        }
                        case "renderPage": {
                            final Integer index = call.argument("index");
                            final Integer maxWidth = call.argument("maxWidth");
                            final Integer quality = call.argument("quality");
                            executor.execute(() -> renderPage(
                                index == null ? 0 : index,
                                maxWidth == null ? 2000 : maxWidth,
                                quality == null ? 85 : quality,
                                result));
                            break;
                        }
                        case "close": {
                            executor.execute(() -> {
                                closeQuietly();
                                succeed(result, null);
                            });
                            break;
                        }
                        default:
                            result.notImplemented();
                    }
                });
    }

    private void open(String path, MethodChannel.Result result) {
        try {
            closeQuietly();
            fileDescriptor = ParcelFileDescriptor.open(
                new File(path), ParcelFileDescriptor.MODE_READ_ONLY);
            renderer = new PdfRenderer(fileDescriptor);
            succeed(result, renderer.getPageCount());
        } catch (Exception e) {
            closeQuietly();
            fail(result, "open", e);
        }
    }

    private void renderPage(int index, int maxWidth, int quality,
                            MethodChannel.Result result) {
        try {
            if (renderer == null) {
                throw new IllegalStateException("No PDF is open");
            }
            PdfRenderer.Page page = renderer.openPage(index);
            try {
                // Page dimensions are in PDF points (1/72 inch). Scale so
                // the bitmap is maxWidth wide (never downscale below the
                // page's own point size — tiny pages stay legible, huge
                // pages are capped for memory).
                float scale = Math.max(1f, (float) maxWidth / page.getWidth());
                int width = Math.round(page.getWidth() * scale);
                int height = Math.round(page.getHeight() * scale);

                Bitmap bitmap = Bitmap.createBitmap(
                    width, height, Bitmap.Config.ARGB_8888);
                // PDFs may have transparent backgrounds; JPEG has no
                // alpha, and OCR needs dark-on-light — fill white first.
                Canvas canvas = new Canvas(bitmap);
                canvas.drawColor(Color.WHITE);
                page.render(bitmap, null, null,
                    PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);

                ByteArrayOutputStream out = new ByteArrayOutputStream();
                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out);
                bitmap.recycle();
                java.util.Map<String, Object> payload = new java.util.HashMap<>();
                payload.put("bytes", out.toByteArray());
                payload.put("width", width);
                payload.put("height", height);
                succeed(result, payload);
            } finally {
                page.close();
            }
        } catch (Exception e) {
            fail(result, "renderPage", e);
        }
    }

    private void closeQuietly() {
        try {
            if (renderer != null) {
                renderer.close();
            }
        } catch (Exception ignored) {
        }
        try {
            if (fileDescriptor != null) {
                fileDescriptor.close();
            }
        } catch (Exception ignored) {
        }
        renderer = null;
        fileDescriptor = null;
    }

    private void succeed(MethodChannel.Result result, Object value) {
        mainHandler.post(() -> result.success(value));
    }

    private void fail(MethodChannel.Result result, String op, Exception e) {
        mainHandler.post(() ->
            result.error("PdfRendererBridge", op + " failed: " + e, null));
    }
}
