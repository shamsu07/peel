package app.peel.peel_native

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File

/** Copies a sticker image to the clipboard as a content URI. */
object ClipboardTools {
    fun copy(context: Context, imagePath: String): Boolean = try {
        // Copy into the cache so the shared file is ours and short-lived.
        val src = File(imagePath)
        val shared = File(context.cacheDir, "clipboard_sticker.${src.extension}")
        src.copyTo(shared, overwrite = true)
        val uri = FileProvider.getUriForFile(
            context, "${context.packageName}.peel_native.files", shared,
        )
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newUri(context.contentResolver, "Sticker", uri))
        true
    } catch (e: Exception) {
        Log.w("PeelClipboard", "Copy failed", e)
        false
    }
}
