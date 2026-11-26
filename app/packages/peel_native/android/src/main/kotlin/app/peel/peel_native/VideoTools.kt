package app.peel.peel_native

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
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
            val us = timeMs * 1000
            // Android 8.1+ decodes straight to the small size: no full-size frame.
            val frame = (if (Build.VERSION.SDK_INT >= 27) {
                r.getScaledFrameAtTime(us, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, maxSide, maxSide)
            } else {
                r.getFrameAtTime(us, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            }) ?: throw IllegalStateException("No frame at $timeMs ms")
            val upright = upright(frame, r)
            val scaled = BitmapLoader.scaleTo(upright, maxSide)
            try {
                return ByteArrayOutputStream().use {
                    scaled.compress(Bitmap.CompressFormat.JPEG, 85, it)
                    it.toByteArray()
                }
            } finally {
                if (scaled !== upright) scaled.recycle()
                if (upright !== frame) upright.recycle()
                frame.recycle()
            }
        } finally {
            r.release()
        }
    }

    /**
     * Writes one raw RGBA file per frame. On Android 9+ frames are decoded in
     * order (getFramesAtIndex), which is far faster than seeking per frame.
     *
     * Memory: frames are decoded as RGB_565 (video has no alpha) in runs
     * capped at ~24 MB, and each is drawn once, rotated, cropped and scaled,
     * into one reused sticker-sized bitmap.
     */
    fun extractFrames(job: FrameJob): Int {
        val outDir = File(job.outDir).apply { mkdirs() }
        val r = retriever(job.videoPath)
        val out = job.outSize.toInt()
        val target = Bitmap.createBitmap(out, out, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(target)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG)
        try {
            val count = max(1, (job.durationMs * job.fps / 1000.0).roundToInt())
            val times = LongArray(count) { i -> job.startMs + (i * 1000.0 / job.fps).roundToLong() }
            val buffer = ByteBuffer.allocateDirect(out * out * 4)
            val draw = { bmp: Bitmap, k: Int ->
                drawFrame(bmp, r, job, canvas, paint)
                buffer.clear()
                target.copyPixelsToBuffer(buffer) // RGBA byte order.
                buffer.flip()
                FileOutputStream(File(outDir, name(k))).channel.use { it.write(buffer) }
            }

            val frameCount = r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT)
            val durationMs = r.int(MediaMetadataRetriever.METADATA_KEY_DURATION)
            if (Build.VERSION.SDK_INT >= 28 && frameCount > 0 && durationMs > 0) {
                val srcFps = frameCount * 1000.0 / durationMs
                val indices = IntArray(count) { i ->
                    min(frameCount - 1, (times[i] / 1000.0 * srcFps).roundToInt())
                }
                val w = max(1, r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH))
                val h = max(1, r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT))
                val maxRun = max(1, (24_000_000L / (w.toLong() * h * 2)).toInt())
                val params = MediaMetadataRetriever.BitmapParams().apply {
                    preferredConfig = Bitmap.Config.RGB_565
                }
                var i = 0
                while (i < count) {
                    val first = indices[i]
                    var j = i
                    while (j + 1 < count && indices[j + 1] - first < maxRun) j++
                    val run = r.getFramesAtIndex(first, indices[j] - first + 1, params)
                    try {
                        for (k in i..j) draw(run[indices[k] - first], k)
                    } finally {
                        run.forEach { it.recycle() }
                    }
                    i = j + 1
                }
            } else {
                for (k in 0 until count) {
                    val bmp = r.getFrameAtTime(times[k] * 1000, MediaMetadataRetriever.OPTION_CLOSEST)
                        ?: continue
                    try {
                        draw(bmp, k)
                    } finally {
                        bmp.recycle()
                    }
                }
            }
            return count
        } finally {
            target.recycle()
            r.release()
        }
    }

    private fun name(i: Int) = "frame_%05d.rgba".format(i)

    /** How far a raw frame must turn to be upright (some devices pre-rotate). */
    private fun turnFor(frame: Bitmap, r: MediaMetadataRetriever): Int {
        val rotation = r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
        if (rotation == 0) return 0
        val w = r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
        val h = r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
        val frameIsRaw = (frame.width > frame.height) == (w > h) && (rotation == 90 || rotation == 270)
        return if (frameIsRaw || rotation == 180) rotation else 0
    }

    /** Some devices return frames unrotated; rotate if the shape doesn't match. */
    private fun upright(frame: Bitmap, r: MediaMetadataRetriever): Bitmap {
        val turn = turnFor(frame, r)
        if (turn == 0) return frame
        val m = Matrix().apply { postRotate(turn.toFloat()) }
        return Bitmap.createBitmap(frame, 0, 0, frame.width, frame.height, m, true)
    }

    /** Draws the cropped square of [frame], upright, filling [canvas]. */
    private fun drawFrame(frame: Bitmap, r: MediaMetadataRetriever, job: FrameJob, canvas: Canvas, paint: Paint) {
        val turn = turnFor(frame, r)
        val fw = frame.width.toFloat()
        val fh = frame.height.toFloat()
        val shownW = if (turn == 90 || turn == 270) fh else fw
        val shownH = if (turn == 90 || turn == 270) fw else fh
        val side = max(1f, (job.crop.size * min(shownW, shownH)).toFloat())
        val left = (job.crop.left * shownW).toFloat().coerceIn(0f, shownW - side)
        val top = (job.crop.top * shownH).toFloat().coerceIn(0f, shownH - side)
        val k = canvas.width / side
        val m = Matrix().apply {
            when (turn) {
                90 -> { postRotate(90f); postTranslate(fh, 0f) }
                180 -> { postRotate(180f); postTranslate(fw, fh) }
                270 -> { postRotate(270f); postTranslate(0f, fw) }
            }
            postTranslate(-left, -top)
            postScale(k, k)
        }
        canvas.drawColor(Color.BLACK)
        canvas.drawBitmap(frame, m, paint)
    }
}
