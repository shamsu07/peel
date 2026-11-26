package app.peel.peel_native

import android.graphics.Bitmap
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import android.os.Build
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.roundToLong

/** Reads video info, thumbnails and square sticker frames. */
object VideoTools {

    private fun retriever(path: String) = MediaMetadataRetriever().apply { setDataSource(path) }

    private fun MediaMetadataRetriever.int(key: Int) = extractMetadata(key)?.toIntOrNull() ?: 0

    fun info(path: String): VideoInfo {
        val r = retriever(path)
        try {
            val rotation = r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            val w = r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val h = r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            val swap = rotation == 90 || rotation == 270
            return VideoInfo(
                durationMs = r.int(MediaMetadataRetriever.METADATA_KEY_DURATION).toLong(),
                width = (if (swap) h else w).toLong(),
                height = (if (swap) w else h).toLong(),
                hasAudio = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) == "yes",
            )
        } finally {
            r.release()
        }
    }

    fun thumbnail(path: String, timeMs: Long, maxSide: Int): ByteArray {
        val r = retriever(path)
        try {
            val frame = r.getFrameAtTime(timeMs * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                ?: throw IllegalStateException("No frame at $timeMs ms")
            val scaled = BitmapLoader.scaleTo(upright(frame, r), maxSide)
            return ByteArrayOutputStream().use {
                scaled.compress(Bitmap.CompressFormat.JPEG, 85, it)
                it.toByteArray()
            }
        } finally {
            r.release()
        }
    }

    /**
     * Writes one raw RGBA file per frame. On Android 9+ frames are decoded in
     * order (getFramesAtIndex), which is far faster than seeking per frame.
     */
    fun extractFrames(job: FrameJob): Int {
        val outDir = File(job.outDir).apply { mkdirs() }
        val r = retriever(job.videoPath)
        try {
            val count = max(1, (job.durationMs * job.fps / 1000.0).roundToInt())
            val times = LongArray(count) { i -> job.startMs + (i * 1000.0 / job.fps).roundToLong() }
            val buffer = ByteBuffer.allocateDirect(job.outSize.toInt() * job.outSize.toInt() * 4)

            val frameCount = r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT)
            val durationMs = r.int(MediaMetadataRetriever.METADATA_KEY_DURATION)
            if (Build.VERSION.SDK_INT >= 28 && frameCount > 0 && durationMs > 0) {
                val srcFps = frameCount * 1000.0 / durationMs
                val indices = IntArray(count) { i ->
                    min(frameCount - 1, (times[i] / 1000.0 * srcFps).roundToInt())
                }
                // Decode in small runs so only a few full-size frames are in memory.
                var i = 0
                while (i < count) {
                    val first = indices[i]
                    var last = first
                    var j = i
                    while (j + 1 < count && indices[j + 1] - first < 6) {
                        j++
                        last = indices[j]
                    }
                    val run = r.getFramesAtIndex(first, last - first + 1)
                    for (k in i..j) {
                        val bmp = run[indices[k] - first]
                        writeFrame(upright(bmp, r), job, buffer, File(outDir, name(k)))
                    }
                    run.forEach { it.recycle() }
                    i = j + 1
                }
            } else {
                for (k in 0 until count) {
                    val bmp = r.getFrameAtTime(times[k] * 1000, MediaMetadataRetriever.OPTION_CLOSEST)
                        ?: continue
                    writeFrame(upright(bmp, r), job, buffer, File(outDir, name(k)))
                    bmp.recycle()
                }
            }
            return count
        } finally {
            r.release()
        }
    }

    private fun name(i: Int) = "frame_%05d.rgba".format(i)

    /** Some devices return frames unrotated; rotate if the shape doesn't match. */
    private fun upright(frame: Bitmap, r: MediaMetadataRetriever): Bitmap {
        val rotation = r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
        if (rotation == 0) return frame
        val w = r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
        val h = r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
        val frameIsRaw = (frame.width > frame.height) == (w > h) && (rotation == 90 || rotation == 270)
        if (!frameIsRaw && rotation != 180) return frame
        val m = Matrix().apply { postRotate(rotation.toFloat()) }
        return Bitmap.createBitmap(frame, 0, 0, frame.width, frame.height, m, true)
    }

    private fun writeFrame(frame: Bitmap, job: FrameJob, buffer: ByteBuffer, file: File) {
        val side = (job.crop.size * min(frame.width, frame.height)).roundToInt().coerceAtLeast(1)
        val left = (job.crop.left * frame.width).roundToInt().coerceIn(0, frame.width - side)
        val top = (job.crop.top * frame.height).roundToInt().coerceIn(0, frame.height - side)
        val square = Bitmap.createBitmap(frame, left, top, side, side)
        val out = job.outSize.toInt()
        val scaled = Bitmap.createScaledBitmap(square, out, out, true)
        val argb = if (scaled.config == Bitmap.Config.ARGB_8888) scaled
        else scaled.copy(Bitmap.Config.ARGB_8888, false)
        buffer.clear()
        argb.copyPixelsToBuffer(buffer) // RGBA byte order.
        buffer.flip()
        FileOutputStream(file).channel.use { it.write(buffer) }
    }
}
