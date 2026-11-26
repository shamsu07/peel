package app.peel.peel

import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Log

/** Which WhatsApp apps are installed, and whether they already have a pack. */
object WhatsAppApps {
    const val CONSUMER = "com.whatsapp"
    const val BUSINESS = "com.whatsapp.w4b"

    fun isInstalled(context: Context, packageName: String): Boolean = try {
        val info = if (Build.VERSION.SDK_INT >= 33) {
            context.packageManager.getApplicationInfo(
                packageName,
                PackageManager.ApplicationInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getApplicationInfo(packageName, 0)
        }
        info.enabled
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    /**
     * Asks WhatsApp's own provider whether our pack is in its tray.
     * Null if that WhatsApp app is not installed; false if it is too old to
     * answer.
     */
    fun hasPack(context: Context, packageName: String, identifier: String): Boolean? {
        if (!isInstalled(context, packageName)) return null
        val whitelistAuthority = "$packageName.provider.sticker_whitelist_check"
        if (context.packageManager.resolveContentProvider(whitelistAuthority, 0) == null) {
            return false
        }
        val uri = Uri.Builder()
            .scheme("content")
            .authority(whitelistAuthority)
            .appendPath("is_whitelisted")
            .appendQueryParameter(
                "authority",
                StickerContentProvider.authorityFor(context.packageName),
            )
            .appendQueryParameter("identifier", identifier)
            .build()
        return try {
            context.contentResolver.query(uri, null, null, null, null)?.use { c ->
                c.moveToFirst() && c.getInt(c.getColumnIndexOrThrow("result")) == 1
            } ?: false
        } catch (e: Exception) {
            Log.w("PeelStickers", "Whitelist check failed for $packageName", e)
            false
        }
    }
}
