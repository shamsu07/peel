package app.peel.peel

import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "peel/whatsapp"
        const val ADD_PACK_REQUEST = 200
        const val ACTION_ENABLE_STICKER_PACK = "com.whatsapp.intent.action.ENABLE_STICKER_PACK"
        const val EXTRA_PACK_ID = "sticker_pack_id"
        const val EXTRA_PACK_AUTHORITY = "sticker_pack_authority"
        const val EXTRA_PACK_NAME = "sticker_pack_name"
        const val EXTRA_VALIDATION_ERROR = "validation_error"
    }

    /** The Dart call waiting for WhatsApp's answer. One at a time. */
    private var pendingAdd: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(status(call.argument<String>("identifier")))
                    "addPack" -> addPack(
                        call.argument<String>("identifier")!!,
                        call.argument<String>("name")!!,
                        result,
                    )
                    "openWhatsApp" -> result.success(openWhatsApp())
                    else -> result.notImplemented()
                }
            }
    }

    private fun openWhatsApp(): Boolean {
        val pkg = listOf(WhatsAppApps.CONSUMER, WhatsAppApps.BUSINESS)
            .firstOrNull { WhatsAppApps.isInstalled(this, it) } ?: return false
        val launch = packageManager.getLaunchIntentForPackage(pkg) ?: return false
        startActivity(launch)
        return true
    }

    private fun status(identifier: String?): Map<String, Any?> = mapOf(
        "consumerInstalled" to WhatsAppApps.isInstalled(this, WhatsAppApps.CONSUMER),
        "businessInstalled" to WhatsAppApps.isInstalled(this, WhatsAppApps.BUSINESS),
        "consumerHasPack" to identifier?.let {
            WhatsAppApps.hasPack(this, WhatsAppApps.CONSUMER, it)
        },
        "businessHasPack" to identifier?.let {
            WhatsAppApps.hasPack(this, WhatsAppApps.BUSINESS, it)
        },
    )

    /**
     * Sends the ENABLE_STICKER_PACK intent. Same target rules as WhatsApp's
     * sample: if both apps are installed and neither has the pack, let the
     * user choose; otherwise go to the app that is missing it. If every app
     * already has it, we still send to WhatsApp so the pack can refresh
     * (Phase 0 question Q-E5).
     */
    private fun addPack(identifier: String, name: String, result: MethodChannel.Result) {
        if (pendingAdd != null) {
            result.error("busy", "Already waiting for WhatsApp", null)
            return
        }
        val consumer = WhatsAppApps.isInstalled(this, WhatsAppApps.CONSUMER)
        val business = WhatsAppApps.isInstalled(this, WhatsAppApps.BUSINESS)
        if (!consumer && !business) {
            result.success(mapOf("outcome" to "notInstalled"))
            return
        }
        val consumerHas = consumer && WhatsAppApps.hasPack(this, WhatsAppApps.CONSUMER, identifier) == true
        val businessHas = business && WhatsAppApps.hasPack(this, WhatsAppApps.BUSINESS, identifier) == true

        val intent = Intent(ACTION_ENABLE_STICKER_PACK)
            .putExtra(EXTRA_PACK_ID, identifier)
            .putExtra(EXTRA_PACK_AUTHORITY, StickerContentProvider.authorityFor(packageName))
            .putExtra(EXTRA_PACK_NAME, name)

        val launch = when {
            consumer && business && !consumerHas && !businessHas ->
                Intent.createChooser(intent, "Add to WhatsApp")
            consumer && !consumerHas -> intent.setPackage(WhatsAppApps.CONSUMER)
            business && !businessHas -> intent.setPackage(WhatsAppApps.BUSINESS)
            consumer -> intent.setPackage(WhatsAppApps.CONSUMER)
            else -> intent.setPackage(WhatsAppApps.BUSINESS)
        }

        try {
            pendingAdd = result
            @Suppress("DEPRECATION")
            startActivityForResult(launch, ADD_PACK_REQUEST)
        } catch (e: ActivityNotFoundException) {
            pendingAdd = null
            result.success(mapOf("outcome" to "notInstalled"))
        }
    }

    @Deprecated("Activity result API; FlutterActivity still routes results here")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != ADD_PACK_REQUEST) return
        val result = pendingAdd ?: return
        pendingAdd = null
        when {
            resultCode == RESULT_OK -> result.success(mapOf("outcome" to "added"))
            data != null -> result.success(
                mapOf(
                    "outcome" to "rejected",
                    "message" to data.getStringExtra(EXTRA_VALIDATION_ERROR),
                )
            )
            else -> result.success(mapOf("outcome" to "cancelled"))
        }
    }
}
