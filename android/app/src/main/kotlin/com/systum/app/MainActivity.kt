package com.systum.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.systum.app/android_intent"
        private const val BACKUP_CHANNEL = "com.systum.app/backup_export"
        private const val REQUEST_CREATE_DOCUMENT = 4101
    }

    private var pendingIntent: Intent? = null
    private var channel: MethodChannel? = null
    private var pendingDocumentResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "acknowledge" -> result.success(null)
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKUP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "selectDocument" -> selectDocument(call.argument("fileName"), result)
                    "writeDocument" -> writeDocument(call.argument("uri"), call.argument("bytes"), result)
                    "readDocument" -> readDocument(call.argument("uri"), result)
                    else -> result.notImplemented()
                }
            }
        // Deliver any intent buffered during cold start, once the channel is ready.
        pendingIntent?.let { deliverIntent(it) }
        pendingIntent = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingIntent = intent
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        pendingIntent = intent
        deliverIntent(intent)
    }

    /// Dispatches an incoming Android intent (launcher shortcut, deep link, or
    /// share) to the Dart layer via the method channel so the UI can route to
    /// the existing app flow.
    private fun deliverIntent(intent: Intent) {
        val action = intent.action
        val data = intent.data
        when {
            (action == Intent.ACTION_SEND || action == Intent.ACTION_SEND_MULTIPLE) -> {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (text?.isNotBlank() == true) {
                    channel?.invokeMethod("sharedText", text.trim())
                }
            }
            data != null && data.scheme == "systum" -> {
                channel?.invokeMethod("deepLink", data.toString())
            }
            else -> {
                // Unknown or unsupported intent; ignore gracefully.
            }
        }
    }

    private fun selectDocument(fileName: String?, result: MethodChannel.Result) {
        if (pendingDocumentResult != null) {
            result.error("busy", "A document picker is already open.", null)
            return
        }
        pendingDocumentResult = result
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, fileName ?: "systum-backup.json")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        startActivityForResult(intent, REQUEST_CREATE_DOCUMENT)
    }

    private fun writeDocument(uriValue: String?, bytes: ByteArray?, result: MethodChannel.Result) {
        if (uriValue == null || bytes == null) {
            result.error("invalid_argument", "A destination URI and bytes are required.", null)
            return
        }
        try {
            val uri = Uri.parse(uriValue)
            contentResolver.openOutputStream(uri, "wt")?.use { output ->
                output.write(bytes)
                output.flush()
            } ?: throw IllegalStateException("The provider did not open a writable stream.")
            result.success(null)
        } catch (error: Exception) {
            result.error("write_failed", error.message, null)
        }
    }

    private fun readDocument(uriValue: String?, result: MethodChannel.Result) {
        if (uriValue == null) {
            result.error("invalid_argument", "A destination URI is required.", null)
            return
        }
        try {
            val bytes = contentResolver.openInputStream(Uri.parse(uriValue))?.use { it.readBytes() }
                ?: throw UnsupportedOperationException("The provider does not expose readback.")
            result.success(bytes)
        } catch (error: SecurityException) {
            result.error("readback_unavailable", error.message, null)
        } catch (error: UnsupportedOperationException) {
            result.error("readback_unavailable", error.message, null)
        } catch (error: Exception) {
            result.error("readback_failed", error.message, null)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_CREATE_DOCUMENT) return
        val result = pendingDocumentResult ?: return
        pendingDocumentResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        val uri = data.data!!
        try {
            val takeFlags = data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            contentResolver.takePersistableUriPermission(uri, takeFlags)
        } catch (_: SecurityException) {
            // A transient grant is sufficient for the current operation.
        }
        result.success(uri.toString())
    }

    override fun onDestroy() {
        pendingDocumentResult?.error("cancelled", "The document picker was closed.", null)
        pendingDocumentResult = null
        super.onDestroy()
    }
}
