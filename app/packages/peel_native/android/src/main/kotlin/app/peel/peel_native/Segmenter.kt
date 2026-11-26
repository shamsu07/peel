package app.peel.peel_native

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.Rect
import android.util.Log
import androidx.exifinterface.media.ExifInterface
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.android.gms.tasks.Task
import com.google.mlkit.common.MlKitException
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.math.max
import kotlin.math.roundToInt

/** Cuts the main subject out of a photo with ML Kit Subject Segmentation. */
object Segmenter {
    private const val TAG = "PeelSegmenter"

    private val options = SubjectSegmenterOptions.Builder()
        .enableForegroundBitmap()
        .build()

    /** Asks Google Play services to download the model ahead of first use. */
    fun prepare(context: Context) {
        try {
            val client = SubjectSegmentation.getClient(options)
            val request = ModuleInstallRequest.newBuilder().addApi(client).build()
            ModuleInstall.getClient(context).installModules(request)
                .addOnFailureListener { Log.w(TAG, "Model download request failed", it) }
        } catch (e: Exception) {
            Log.w(TAG, "Could not request model download", e)
        }
    }

    suspend fun segment(imagePath: String, outPath: String, maxSide: Int): SegmentResult =
        withContext(Dispatchers.Default) {
            val bitmap = BitmapLoader.load(imagePath, maxSide)
                ?: return@withContext SegmentResult(status = "error", width = 0, height = 0)
            val client = SubjectSegmentation.getClient(options)
            // Every bitmap made here is freed in finally: photos are big.
            var foreground: Bitmap? = null
            var cropped: Bitmap? = null
            try {
                val result = client.process(InputImage.fromBitmap(bitmap, 0)).await()
                foreground = result.foregroundBitmap
                    ?: return@withContext SegmentResult(status = "noSubject", width = 0, height = 0)
                val bounds = opaqueBounds(foreground)
                if (bounds == null ||
                    bounds.width().toLong() * bounds.height() < foreground.width.toLong() * foreground.height / 100
                ) {
                    return@withContext SegmentResult(status = "noSubject", width = 0, height = 0)
                }
                val crop = Bitmap.createBitmap(
                    foreground, bounds.left, bounds.top, bounds.width(), bounds.height(),
                )
                cropped = crop
                FileOutputStream(File(outPath)).use { crop.compress(Bitmap.CompressFormat.PNG, 100, it) }
                SegmentResult(
                    status = "ok",
                    path = outPath,
                    width = crop.width.toLong(),
                    height = crop.height.toLong(),
                )
            } catch (e: MlKitException) {
                Log.w(TAG, "Segmentation failed", e)
                if (e.errorCode == MlKitException.UNAVAILABLE) {
                    SegmentResult(status = "modelDownloading", width = 0, height = 0)
                } else {
                    SegmentResult(status = "error", width = 0, height = 0)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Segmentation failed", e)
                SegmentResult(status = "error", width = 0, height = 0)
            } finally {
                client.close()
                if (cropped !== foreground) cropped?.recycle()
                foreground?.recycle()
                bitmap.recycle()
            }
        }

    /** Smallest rectangle holding every pixel that is clearly visible. */
    private fun opaqueBounds(bitmap: Bitmap): Rect? {
        val w = bitmap.width
        val h = bitmap.height
        val row = IntArray(w)
        var left = w
        var top = h
        var right = -1
        var bottom = -1
        for (y in 0 until h) {
            bitmap.getPixels(row, 0, w, 0, y, w, 1)
            for (x in 0 until w) {
                if ((row[x] ushr 24) > 16) {
                    if (x < left) left = x
                    if (x > right) right = x
                    if (y < top) top = y
                    bottom = y
                }
            }
        }
        return if (right < 0) null else Rect(left, top, right + 1, bottom + 1)
    }
}

/** Loads a photo upright (EXIF applied), with its longest side at most [maxSide]. */
object BitmapLoader {
    fun load(path: String, maxSide: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxSide) sample *= 2
        val decoded = BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.ARGB_8888
            },
        ) ?: return null

        val matrix = Matrix()
        when (ExifInterface(path).getAttributeInt(
            ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL,
        )) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
        }
        val longest = max(decoded.width, decoded.height)
        if (longest > maxSide) {
            val s = maxSide.toFloat() / longest
            matrix.postScale(s, s)
        }
        if (matrix.isIdentity) return decoded
        val out = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        if (out !== decoded) decoded.recycle()
        return out
    }

    fun scaleTo(bitmap: Bitmap, maxSide: Int): Bitmap {
        val longest = max(bitmap.width, bitmap.height)
        if (longest <= maxSide) return bitmap
        val s = maxSide.toFloat() / longest
        return Bitmap.createScaledBitmap(
            bitmap, (bitmap.width * s).roundToInt(), (bitmap.height * s).roundToInt(), true,
        )
    }
}

suspend fun <T> Task<T>.await(): T = suspendCancellableCoroutine { cont ->
    addOnSuccessListener { cont.resume(it) }
    addOnFailureListener { cont.resumeWithException(it) }
    addOnCanceledListener { cont.cancel() }
}
