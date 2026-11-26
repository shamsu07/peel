package app.peel.peel_native

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.Crop
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.TextureOverlay
import com.google.common.collect.ImmutableList
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Makes the square MP4 (H.264 + AAC, 720x720) that the user turns into a
 * sound sticker in WhatsApp's own "Create sticker" (spec P0-5).
 */
@OptIn(UnstableApi::class)
object HandoffExporter {
    private const val SIZE = 720

    suspend fun export(context: Context, job: HandoffJob): String = withContext(Dispatchers.Main) {
        val composition = buildComposition(job)
        File(job.outPath).delete()
        suspendCancellableCoroutine { cont ->
            val transformer = Transformer.Builder(context)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        if (cont.isActive) cont.resume(job.outPath)
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException,
                    ) {
                        if (cont.isActive) cont.resumeWithException(exportException)
                    }
                })
                .build()
            transformer.start(composition, job.outPath)
            cont.invokeOnCancellation { transformer.cancel() }
        }
    }

    private fun buildComposition(job: HandoffJob): Composition {
        val square = Presentation.createForWidthAndHeight(
            SIZE, SIZE, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP,
        )
        val imagePath = job.imagePath
        val video: EditedMediaItem = if (imagePath != null) {
            val item = MediaItem.Builder()
                .setUri(Uri.fromFile(File(imagePath)))
                .setImageDurationMs(job.durationMs)
                .build()
            EditedMediaItem.Builder(item)
                .setFrameRate(30)
                .setEffects(Effects(listOf(), listOf(square)))
                .build()
        } else {
            val path = requireNotNull(job.videoPath) { "Need imagePath or videoPath" }
            val clip = MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs(job.videoStartMs)
                .setEndPositionMs(job.videoStartMs + job.durationMs)
                .build()
            val item = MediaItem.Builder()
                .setUri(Uri.fromFile(File(path)))
                .setClippingConfiguration(clip)
                .build()
            val effects = mutableListOf<androidx.media3.common.Effect>()
            job.crop?.let { effects.add(cropEffect(path, it)) }
            effects.add(square)
            // Draw the sticker's white edge, corners and text over the video.
            job.overlayPath?.let { overlayPath ->
                BitmapFactory.decodeFile(overlayPath)?.let { bitmap ->
                    val sized = Bitmap.createScaledBitmap(bitmap, SIZE, SIZE, true)
                    val overlay = BitmapOverlay.createStaticBitmapOverlay(sized)
                    effects.add(OverlayEffect(ImmutableList.of<TextureOverlay>(overlay)))
                }
            }
            EditedMediaItem.Builder(item)
                .setRemoveAudio(job.audioMode != "original")
                .setEffects(Effects(listOf(), effects))
                .build()
        }

        val sequences = mutableListOf(EditedMediaItemSequence(listOf(video)))
        val audioPath = job.audioPath
        if (job.audioMode == "replace" && audioPath != null) {
            val clip = MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs(job.audioStartMs)
                .setEndPositionMs(job.audioStartMs + job.durationMs)
                .build()
            val audio = MediaItem.Builder()
                .setUri(Uri.fromFile(File(audioPath)))
                .setClippingConfiguration(clip)
                .build()
            sequences.add(EditedMediaItemSequence(listOf(EditedMediaItem.Builder(audio).build())))
        }
        return Composition.Builder(sequences)
            .experimentalSetForceAudioTrack(true)
            .build()
    }

    /** Converts our crop (fractions of the shown frame) to Media3's -1..1 space. */
    private fun cropEffect(path: String, crop: SquareCrop): Crop {
        val info = VideoTools.info(path)
        val w = info.width.toFloat()
        val h = info.height.toFloat()
        val side = crop.size.toFloat() * minOf(w, h)
        val left = -1f + 2f * crop.left.toFloat()
        val right = left + 2f * side / w
        val top = 1f - 2f * crop.top.toFloat()
        val bottom = top - 2f * side / h
        return Crop(left, right, bottom, top)
    }
}
