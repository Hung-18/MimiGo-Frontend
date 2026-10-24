package com.mimigo.mimigo_frontend

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.view.WindowManager
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import java.io.File
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    companion object {
        private const val alias = "mimigo.refresh.v1"
        // Survives Activity recreation; a late release cannot clear another form.
        private val secureOwners = mutableSetOf<String>()
    }
    private val storageWorker = Executors.newSingleThreadExecutor()
    private val keyStore: KeyStore get() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private val refreshFile: AtomicFile get() = AtomicFile(File(noBackupFilesDir, "refresh.v1"))
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (secureOwners.isNotEmpty()) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mimigo/security").setMethodCallHandler { call, result ->
            if (call.method == "secureScreen") {
                val owner = call.argument<String>("owner")
                if (owner == null) { result.error("INVALID_REQUEST", "Missing screen lease.", null); return@setMethodCallHandler }
                if (call.argument<Boolean>("enabled") == true) secureOwners.add(owner) else secureOwners.remove(owner)
                if (secureOwners.isEmpty()) window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                else window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                result.success(null)
            } else if (call.method == "screenProtected") {
                result.success(window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0)
            } else if (call.method in setOf("readRefresh", "writeRefresh", "clearRefresh")) {
                storageWorker.execute {
                    try {
                        val value: String? = when (call.method) {
                            "readRefresh" -> readRefresh()
                            "writeRefresh" -> { writeRefresh(call.arguments as String); null }
                            else -> { keyStore.deleteEntry(alias); refreshFile.delete(); null }
                        }
                        runOnUiThread { result.success(value) }
                    } catch (_: Exception) {
                        runOnUiThread { result.error("SECURE_STORAGE_UNAVAILABLE", "Secure session storage unavailable.", null) }
                    }
                }
            } else result.notImplemented()
        }
    }
    private fun writeRefresh(value: String) {
        val store = keyStore
        val key = (store.getKey(alias, null) as? SecretKey) ?: KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true).build())
            generateKey()
        }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        require(cipher.iv.size == 12)
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val file = refreshFile
        val output = file.startWrite()
        try { output.write(byteArrayOf(1)); output.write(cipher.iv); output.write(encrypted); file.finishWrite(output) }
        catch (error: Exception) { file.failWrite(output); throw error }
    }
    private fun readRefresh(): String? {
        val file = refreshFile
        if (!file.baseFile.exists()) return null
        val bytes = file.readFully()
        require(bytes.size >= 30 && bytes[0].toInt() == 1)
        val key = keyStore.getKey(alias, null) as? SecretKey ?: error("Unavailable key")
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, bytes.copyOfRange(1,13)))
        return String(cipher.doFinal(bytes.copyOfRange(13,bytes.size)), Charsets.UTF_8)
    }
    override fun onDestroy() { storageWorker.shutdown(); super.onDestroy() }
}
