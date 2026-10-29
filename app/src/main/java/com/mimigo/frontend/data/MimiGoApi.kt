package com.mimigo.frontend.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import com.mimigo.frontend.BuildConfig
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** HTTP client for the ordinary Parent API (baseline /api/v1 contract). */
class MimiGoApi(context: Context) {
    private val preferences = context.getSharedPreferences("mimigo_session", Context.MODE_PRIVATE)
    private val baseUrl = BuildConfig.API_BASE_URL.trimEnd('/')

    var accessToken: String?
        get() = runCatching {
            val encoded = preferences.getString("access_token", null) ?: return null
            val parts = encoded.split(":", limit = 2)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, tokenKey(), GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)))
            String(cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), Charsets.UTF_8)
        }.getOrElse { clearSession(); null }
        private set(value) {
            if (value == null) { preferences.edit().remove("access_token").apply(); return }
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, tokenKey())
            val iv = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
            val encrypted = Base64.encodeToString(cipher.doFinal(value.toByteArray(Charsets.UTF_8)), Base64.NO_WRAP)
            preferences.edit().putString("access_token", "$iv:$encrypted").apply()
        }

    fun clearSession() { preferences.edit().clear().apply() }

    private fun tokenKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey("mimigo_parent_access", null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(KeyGenParameterSpec.Builder("mimigo_parent_access", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
            generateKey()
        }
    }

    suspend fun onboardingReference(): JSONObject = request("GET", "/privacy/onboarding-reference")

    suspend fun register(email: String, password: String, name: String): JSONObject {
        val reference = onboardingReference()
        val termsId = reference.getJSONObject("terms").getString("termsVersionId")
        return request("POST", "/auth/register", JSONObject()
            .put("email", email).put("password", password).put("displayName", name)
            .put("termsVersionId", termsId).put("termsAccepted", true))
    }

    suspend fun verify(email: String, otp: String): JSONObject =
        request("POST", "/auth/mock-email/verify", JSONObject().put("email", email).put("otp", otp))

    suspend fun resendVerification(email: String): JSONObject =
        request("POST", "/auth/mock-email/resend", JSONObject().put("email", email))

    suspend fun login(email: String, password: String): JSONObject {
        val result = request("POST", "/auth/login", JSONObject().put("email", email).put("password", password))
        accessToken = result.getString("accessToken")
        return result
    }

    suspend fun children(): JSONArray = request("GET", "/children").getJSONArray("items")

    suspend fun parentProfile(): JSONObject = request("GET", "/parents/me")

    suspend fun premiumPlans(): JSONObject = request("GET", "/billing/premium-plans")

    suspend fun premiumEligibility(childId: String): JSONObject =
        request("GET", "/children/$childId/premium-eligibility")

    suspend fun premiumEntitlement(childId: String): JSONObject =
        request("GET", "/children/$childId/premium-entitlement")

    suspend fun createPremiumCheckout(childId: String, planId: String, proof: String, idempotencyKey: String): JSONObject =
        request("POST", "/billing/premium-checkouts", JSONObject()
            .put("idempotencyKey", idempotencyKey)
            .put("items", JSONArray().put(JSONObject().put("childId", childId).put("planId", planId))),
            mapOf("MimiGo-Parent-Proof" to proof))

    suspend fun settleSyntheticCheckout(checkoutId: String, outcome: String, proof: String): JSONObject =
        request("POST", "/billing/premium-checkouts/$checkoutId/synthetic-settlement", JSONObject().put("outcome", outcome),
            mapOf("MimiGo-Parent-Proof" to proof))

    suspend fun premiumCheckout(checkoutId: String): JSONObject =
        request("GET", "/billing/premium-checkouts/$checkoutId")

    suspend fun lessons(childId: String): JSONObject = request("GET", "/children/$childId/lessons")

    suspend fun lesson(childId: String, lessonId: String): JSONObject =
        request("GET", "/children/$childId/lessons/$lessonId")

    suspend fun startLearningSession(childId: String, lessonId: String): JSONObject =
        request("POST", "/children/$childId/learning-sessions", JSONObject().put("lessonId", lessonId))

    suspend fun learningSession(childId: String, sessionId: String): JSONObject =
        request("GET", "/children/$childId/learning-sessions/$sessionId")

    suspend fun learningHistory(childId: String, limit: Int = 20): JSONArray =
        request("GET", "/children/$childId/learning-sessions?limit=${limit.coerceIn(1, 100)}")
            .optJSONArray("items") ?: JSONArray()

    suspend fun submitAnswer(
        childId: String,
        sessionId: String,
        cueId: String,
        optionId: String,
        clientEventId: String
    ): JSONObject = request(
        "POST", "/children/$childId/learning-sessions/$sessionId/answers",
        JSONObject().put("clientEventId", clientEventId).put("cueId", cueId)
            .put("optionId", optionId).put("usedHint", false)
    )

    suspend fun completeLearningSession(childId: String, sessionId: String): JSONObject =
        request("POST", "/children/$childId/learning-sessions/$sessionId/complete")

    suspend fun beginChildOnboarding(): JSONObject = request("POST", "/children/onboarding-attempts")

    suspend fun onboardingNoticeSummaries(attempt: JSONObject): List<String> {
        val reference = onboardingReference()
        val referenceNotices = reference.optJSONArray("notices") ?: JSONArray()
        val attemptNotices = attempt.optJSONArray("notices") ?: JSONArray()
        return (0 until attemptNotices.length()).mapNotNull { index ->
            val snapshot = attemptNotices.optJSONObject(index) ?: return@mapNotNull null
            val purpose = snapshot.optString("purposeCode")
            val current = (0 until referenceNotices.length()).asSequence()
                .mapNotNull { referenceNotices.optJSONObject(it) }
                .firstOrNull { it.optString("purposeCode") == purpose }
                ?.optJSONObject("currentVersion")
            val body = listOf("noticeText", "text", "contentText", "content")
                .firstNotNullOfOrNull { key -> current?.optString(key)?.takeIf { it.isNotBlank() && it != "null" } }
            val label = when (purpose) {
                "CHILD_PROFILE_AGE" -> "Tạo và sử dụng hồ sơ độ tuổi của trẻ"
                else -> purpose.replace('_', ' ').lowercase().replaceFirstChar { it.uppercase() }
            }
            val version = snapshot.optString("versionLabel", "hiện hành")
            if (body == null) "$label · phiên bản $version" else "$label · phiên bản $version\n$body"
        }
    }

    suspend fun createChild(alias: String, dateOfBirth: String, attempt: JSONObject, idempotencyKey: String): JSONObject {
        val notices = attempt.optJSONArray("notices") ?: JSONArray()
        val purposes = JSONArray()
        for (index in 0 until notices.length()) {
            val notice = notices.getJSONObject(index)
            purposes.put(JSONObject()
                .put("purposeCode", notice.getString("purposeCode"))
                .put("noticeVersionId", notice.getString("noticeVersionId"))
                .put("affirmed", true))
        }
        return request("POST", "/children", JSONObject()
            .put("attemptId", attempt.getString("attemptId"))
            .put("idempotencyKey", idempotencyKey)
            .put("childAlias", alias).put("dateOfBirth", dateOfBirth)
            .put("stockAvatarKey", JSONObject.NULL).put("guardianAffirmed", true)
            .put("relationshipCode", "PARENT").put("purposeChoices", purposes))
    }

    private suspend fun request(
        method: String,
        path: String,
        body: JSONObject? = null,
        headers: Map<String, String> = emptyMap()
    ): JSONObject =
        withContext(Dispatchers.IO) {
            val connection = (URL(baseUrl + path).openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 15000
                readTimeout = 20000
                setRequestProperty("Accept", "application/json")
                accessToken?.let { setRequestProperty("Authorization", "Bearer $it") }
                headers.forEach { (name, value) -> setRequestProperty(name, value) }
                if (body != null) {
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json; charset=utf-8")
                }
            }
            try {
                if (body != null) connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
                val status = connection.responseCode
                val stream = if (status in 200..299) connection.inputStream else connection.errorStream
                val text = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
                val json = if (text.isBlank()) JSONObject() else JSONObject(text)
                if (status !in 200..299) {
                    val code = json.optString("code")
                    val message = json.optString("message")
                    throw IOException(when (code) {
                        "EMAIL_ALREADY_REGISTERED" -> "Email này đã được đăng ký. Hãy đăng nhập hoặc dùng email khác."
                        "INVALID_CREDENTIALS", "UNAUTHENTICATED" -> "Email hoặc mật khẩu không đúng."
                        "INVALID_OTP" -> "Mã xác nhận không đúng hoặc đã hết hạn. Vui lòng thử lại."
                        "ATTEMPT_EXPIRED" -> "Phiên tạo hồ sơ đã hết hạn. Vui lòng thử lại."
                        "CORE_PERMISSION_REQUIRED" -> "Bạn cần xác nhận đầy đủ các mục đồng ý để tạo hồ sơ."
                        "DB_NOT_CONFIGURED" -> "Dịch vụ dữ liệu hiện chưa sẵn sàng. Vui lòng thử lại sau."
                        else -> message.takeIf { it.isNotBlank() } ?: "Yêu cầu thất bại ($status${if (code.isBlank()) "" else ": $code"})."
                    })
                }
                json
            } finally { connection.disconnect() }
        }
}
