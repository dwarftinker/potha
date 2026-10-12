package dev.potha.potha

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        dropUnreadableFiles(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        dropUnreadableFiles(intent)
        super.onNewIntent(intent)
    }

    // receive_sharing_intent opens shared files on the main thread and crashes the app
    // with a SecurityException when the sending app did not grant read access. Remove
    // such files from the intent first; the app then just opens the library.
    private fun dropUnreadableFiles(intent: Intent?) {
        if (intent == null) return
        val data = intent.data
        if (intent.action == Intent.ACTION_VIEW && data != null && !canRead(data)) {
            intent.action = Intent.ACTION_MAIN
            intent.data = null
        }
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val uri = streamExtra(intent)
                if (uri != null && !canRead(uri)) {
                    intent.removeExtra(Intent.EXTRA_STREAM)
                    intent.action = Intent.ACTION_MAIN
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = streamListExtra(intent) ?: return
                val readable = uris.filter { canRead(it) }
                if (readable.size == uris.size) return
                if (readable.isEmpty()) {
                    intent.removeExtra(Intent.EXTRA_STREAM)
                    intent.action = Intent.ACTION_MAIN
                } else {
                    intent.putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(readable))
                }
            }
        }
    }

    private fun canRead(uri: Uri): Boolean =
        try {
            contentResolver.openInputStream(uri)?.close()
            true
        } catch (e: Exception) {
            Log.w("Potha", "Ignoring a shared file the app cannot read: ${e.javaClass.simpleName}")
            false
        }

    @Suppress("DEPRECATION")
    private fun streamExtra(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    @Suppress("DEPRECATION")
    private fun streamListExtra(intent: Intent): List<Uri>? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        }
}
