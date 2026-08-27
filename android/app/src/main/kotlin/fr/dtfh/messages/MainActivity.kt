package fr.dtfh.messages

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var bridge: SmsBridge? = null
    private var audio: AudioBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        bridge = SmsBridge(this, messenger).also { it.attach() }
        // La lecture des vocaux a son propre canal : elle ne parle pas au
        // stock, et son lecteur vit sur le fil principal.
        audio = AudioBridge(this, messenger).also { it.attach() }
    }

    // Notification touchée, lien `sms:` ouvert : l'activité étant `singleTop`,
    // l'intent arrive ici plutôt que dans un nouveau `onCreate`.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        bridge?.onNewIntent(intent)
    }

    // La demande de rôle « app SMS par défaut » repasse par ici.
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (bridge?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        bridge?.detach()
        bridge = null
        audio?.detach()
        audio = null
        super.onDestroy()
    }
}
