package app.peel.peel_native

import android.content.Context
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** FileProvider subclass so our authority never clashes with other plugins. */
class PeelFileProvider : FileProvider()

/**
 * Peel's native features. Pigeon (pigeon/messages.dart) generates the
 * channel code; calls arrive on the main thread, so heavy work switches to a
 * background dispatcher here.
 */
class PeelNativePlugin : FlutterPlugin, PeelNativeApi {
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        PeelNativeApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PeelNativeApi.setUp(binding.binaryMessenger, null)
    }

    override fun prepareSegmenter() = Segmenter.prepare(context)

    override suspend fun segmentSubject(
        imagePath: String,
        outPath: String,
        maxSide: Long,
    ): SegmentResult = Segmenter.segment(imagePath, outPath, maxSide.toInt())

    override suspend fun videoInfo(path: String): VideoInfo =
        withContext(Dispatchers.IO) { VideoTools.info(path) }

    override suspend fun videoThumbnail(path: String, timeMs: Long, maxSide: Long): ByteArray =
        withContext(Dispatchers.IO) { VideoTools.thumbnail(path, timeMs, maxSide.toInt()) }

    override suspend fun extractFrames(job: FrameJob): Long =
        withContext(Dispatchers.Default) { VideoTools.extractFrames(job).toLong() }

    override suspend fun exportHandoffVideo(job: HandoffJob): String =
        HandoffExporter.export(context, job)

    override fun copyStickerToClipboard(webpPath: String, pngPath: String): Boolean =
        ClipboardTools.copy(context, pngPath)
}
