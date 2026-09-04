package shiroikuma.jisho;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * The jobs the data door has started, and the flag each of them watches
 * to stop. Java port of the family reference
 * {@code core/automation/AutomationJobs.kt}.
 *
 * One at a time is not enforced here — what this owns is the mapping
 * from the id a caller was handed to a cancellation it can act on,
 * which must outlive the binder call that created it and be reachable
 * from a service that never saw the caller.
 */
final class AutomationJobs {

    private static final Map<String, Boolean> CANCELLED =
        new ConcurrentHashMap<>();

    private AutomationJobs() {}

    static String begin() {
        String jobId = UUID.randomUUID().toString();
        CANCELLED.put(jobId, Boolean.FALSE);
        return jobId;
    }

    /**
     * Ask a job to stop. A no-op for an id that is finished or was
     * never real.
     *
     * Deliberately silent: a cancel arriving after the work completed
     * is the normal race, not an error, and answering it as one would
     * make every well-behaved caller look broken.
     */
    static void cancel(String jobId) {
        if (jobId != null) {
            CANCELLED.computeIfPresent(jobId, (key, was) -> Boolean.TRUE);
        }
    }

    /**
     * Cancel whatever is running. The §1 receiver's CANCEL_EXPORT may
     * arrive without a {@code reply_id}, which the contract defines as
     * "the export you are running" — unambiguous because the contract
     * forbids two at once.
     */
    static void cancelAll() {
        for (String jobId : CANCELLED.keySet()) {
            CANCELLED.computeIfPresent(jobId, (key, was) -> Boolean.TRUE);
        }
    }

    /**
     * Polled at write boundaries — never mid-write, so a cancelled
     * archive is never half a file.
     */
    static boolean isCancelled(String jobId) {
        return jobId != null && Boolean.TRUE.equals(CANCELLED.get(jobId));
    }

    static void finish(String jobId) {
        if (jobId != null) {
            CANCELLED.remove(jobId);
        }
    }
}
