package app.peel.peel

import android.content.ContentProvider
import android.content.ContentValues
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * Serves the app's sticker packs to WhatsApp.
 *
 * The packs are written by Dart (lib/whatsapp/pack_store.dart) into
 * `filesDir/sticker_packs/`, with `packs.json` as the index. This provider only
 * reads them. Column names and paths come from WhatsApp's official sample
 * (WhatsApp/stickers, StickerContentProvider.java) and must not change.
 *
 * Only WhatsApp can read it: the manifest guards it with WhatsApp's
 * `com.whatsapp.sticker.READ` permission.
 */
class StickerContentProvider : ContentProvider() {

    companion object {
        private const val TAG = "PeelStickers"

        const val METADATA = "metadata"
        const val STICKERS = "stickers"
        const val STICKERS_ASSET = "stickers_asset"

        // Metadata columns, in WhatsApp's order.
        const val STICKER_PACK_IDENTIFIER = "sticker_pack_identifier"
        const val STICKER_PACK_NAME = "sticker_pack_name"
        const val STICKER_PACK_PUBLISHER = "sticker_pack_publisher"
        const val STICKER_PACK_ICON = "sticker_pack_icon"
        const val ANDROID_PLAY_STORE_LINK = "android_play_store_link"
        const val IOS_APP_DOWNLOAD_LINK = "ios_app_download_link"
        const val PUBLISHER_EMAIL = "sticker_pack_publisher_email"
        const val PUBLISHER_WEBSITE = "sticker_pack_publisher_website"
        const val PRIVACY_POLICY_WEBSITE = "sticker_pack_privacy_policy_website"
        const val LICENSE_AGREEMENT_WEBSITE = "sticker_pack_license_agreement_website"
        const val IMAGE_DATA_VERSION = "image_data_version"
        const val AVOID_CACHE = "whatsapp_will_not_cache_stickers"
        const val ANIMATED_STICKER_PACK = "animated_sticker_pack"

        // Sticker columns.
        const val STICKER_FILE_NAME = "sticker_file_name"
        const val STICKER_EMOJI = "sticker_emoji"
        const val STICKER_ACCESSIBILITY_TEXT = "sticker_accessibility_text"

        fun authorityFor(packageName: String) = "$packageName.stickercontentprovider"
    }

    private data class Sticker(val file: String, val emojis: List<String>, val alt: String)

    private data class Pack(
        val identifier: String,
        val name: String,
        val publisher: String,
        val trayFile: String,
        val version: String,
        val animated: Boolean,
        val stickers: List<Sticker>,
    )

    private data class Manifest(val packs: List<Pack>, val playLink: String, val iosLink: String)

    private val authority: String
        get() = authorityFor(context!!.packageName)

    private val packsDir: File
        get() = File(context!!.filesDir, "sticker_packs")

    override fun onCreate(): Boolean = true

    /** Re-read on every request: the file is small and Dart may have changed it. */
    private fun loadManifest(): Manifest {
        val file = File(packsDir, "packs.json")
        if (!file.exists()) return Manifest(emptyList(), "", "")
        return try {
            val root = JSONObject(file.readText())
            val packs = root.getJSONArray("packs")
            Manifest(
                packs = (0 until packs.length()).map { i ->
                    val p = packs.getJSONObject(i)
                    val s = p.getJSONArray("stickers")
                    Pack(
                        identifier = p.getString("identifier"),
                        name = p.getString("name"),
                        publisher = p.getString("publisher"),
                        trayFile = p.getString("tray_image_file"),
                        version = p.getString("image_data_version"),
                        animated = p.getBoolean("animated_sticker_pack"),
                        stickers = (0 until s.length()).map { j ->
                            val st = s.getJSONObject(j)
                            val e = st.getJSONArray("emojis")
                            Sticker(
                                file = st.getString("image_file"),
                                emojis = (0 until e.length()).map { k -> e.getString(k) },
                                alt = st.optString("accessibility_text", ""),
                            )
                        },
                    )
                },
                playLink = root.optString("android_play_store_link", ""),
                iosLink = root.optString("ios_app_store_link", ""),
            )
        } catch (e: Exception) {
            Log.e(TAG, "Could not read packs.json", e)
            Manifest(emptyList(), "", "")
        }
    }

    private fun checkAuthority(uri: Uri) {
        require(uri.authority == authority) { "Unknown authority ${uri.authority}" }
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        checkAuthority(uri)
        val segments = uri.pathSegments
        val manifest = loadManifest()
        return when {
            segments.size == 1 && segments[0] == METADATA ->
                metadataCursor(manifest, manifest.packs)
            segments.size == 2 && segments[0] == METADATA ->
                metadataCursor(manifest, manifest.packs.filter { it.identifier == segments[1] })
            segments.size == 2 && segments[0] == STICKERS ->
                stickersCursor(manifest.packs.firstOrNull { it.identifier == segments[1] })
            else -> throw IllegalArgumentException("Unknown URI: $uri")
        }.apply { setNotificationUri(context!!.contentResolver, uri) }
    }

    private fun metadataCursor(manifest: Manifest, packs: List<Pack>): MatrixCursor {
        val cursor = MatrixCursor(
            arrayOf(
                STICKER_PACK_IDENTIFIER, STICKER_PACK_NAME, STICKER_PACK_PUBLISHER,
                STICKER_PACK_ICON, ANDROID_PLAY_STORE_LINK, IOS_APP_DOWNLOAD_LINK,
                PUBLISHER_EMAIL, PUBLISHER_WEBSITE, PRIVACY_POLICY_WEBSITE,
                LICENSE_AGREEMENT_WEBSITE, IMAGE_DATA_VERSION, AVOID_CACHE,
                ANIMATED_STICKER_PACK,
            )
        )
        for (p in packs) {
            cursor.newRow()
                .add(STICKER_PACK_IDENTIFIER, p.identifier)
                .add(STICKER_PACK_NAME, p.name)
                .add(STICKER_PACK_PUBLISHER, p.publisher)
                .add(STICKER_PACK_ICON, p.trayFile)
                .add(ANDROID_PLAY_STORE_LINK, manifest.playLink)
                .add(IOS_APP_DOWNLOAD_LINK, manifest.iosLink)
                .add(PUBLISHER_EMAIL, "")
                .add(PUBLISHER_WEBSITE, "")
                .add(PRIVACY_POLICY_WEBSITE, "")
                .add(LICENSE_AGREEMENT_WEBSITE, "")
                .add(IMAGE_DATA_VERSION, p.version)
                .add(AVOID_CACHE, 0)
                .add(ANIMATED_STICKER_PACK, if (p.animated) 1 else 0)
        }
        return cursor
    }

    private fun stickersCursor(pack: Pack?): MatrixCursor {
        val cursor = MatrixCursor(
            arrayOf(STICKER_FILE_NAME, STICKER_EMOJI, STICKER_ACCESSIBILITY_TEXT)
        )
        pack?.stickers?.forEach { s ->
            cursor.addRow(arrayOf(s.file, s.emojis.joinToString(","), s.alt))
        }
        return cursor
    }

    override fun getType(uri: Uri): String? {
        val segments = uri.pathSegments
        return when {
            segments.size == 1 && segments[0] == METADATA ->
                "vnd.android.cursor.dir/vnd.$authority.$METADATA"
            segments.size == 2 && segments[0] == METADATA ->
                "vnd.android.cursor.item/vnd.$authority.$METADATA"
            segments.size == 2 && segments[0] == STICKERS ->
                "vnd.android.cursor.dir/vnd.$authority.$STICKERS"
            segments.size == 3 && segments[0] == STICKERS_ASSET ->
                if (segments[2].endsWith(".png")) "image/png" else "image/webp"
            else -> throw IllegalArgumentException("Unknown URI: $uri")
        }
    }

    /** Serves `stickers_asset/<identifier>/<file>` for stickers and the tray icon. */
    override fun openAssetFile(uri: Uri, mode: String): AssetFileDescriptor? {
        checkAuthority(uri)
        val segments = uri.pathSegments
        if (segments.size != 3 || segments[0] != STICKERS_ASSET) return null
        val identifier = segments[1]
        val fileName = segments[2]

        // Only files listed in the index, so no path tricks can reach other files.
        val pack = loadManifest().packs.firstOrNull { it.identifier == identifier } ?: return null
        val listed = fileName == pack.trayFile || pack.stickers.any { it.file == fileName }
        if (!listed) return null

        val file = File(File(packsDir, identifier), fileName)
        if (!file.exists()) {
            Log.e(TAG, "Missing sticker file $identifier/$fileName")
            return null
        }
        val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        return AssetFileDescriptor(pfd, 0, file.length())
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? =
        throw UnsupportedOperationException("Read-only")

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int =
        throw UnsupportedOperationException("Read-only")

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = throw UnsupportedOperationException("Read-only")
}
