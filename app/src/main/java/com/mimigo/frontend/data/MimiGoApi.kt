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
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** HTTP client for the ordinary Parent API (baseline /api/v1 contract). */
class MimiGoApi(context: Context) {
    private val preferences = context.getSharedPreferences("mimigo_session", Context.MODE_PRIVATE)
    private val baseUrl = BuildConfig.API_BASE_URL.trimEnd('/')
    private val refreshMutex = Mutex()

    var accessToken: String?
        get() = readToken("access_token")
        private set(value) {
            writeToken("access_token", value)
        }

    private var refreshToken: String?
        get() = readToken("refresh_token")
        set(value) = writeToken("refresh_token", value)

    fun clearSession() { preferences.edit().clear().apply() }

    private fun readToken(key: String): String? = runCatching {
        val encoded = preferences.getString(key, null) ?: return null
        val parts = encoded.split(":", limit = 2)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, tokenKey(), GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)))
        String(cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), Charsets.UTF_8)
    }.getOrElse { clearSession(); null }

    private fun encryptToken(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, tokenKey())
        val iv = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
        val encrypted = Base64.encodeToString(cipher.doFinal(value.toByteArray(Charsets.UTF_8)), Base64.NO_WRAP)
        return "$iv:$encrypted"
    }

    private fun writeToken(key: String, value: String?) {
        val editor = preferences.edit()
        if (value == null) editor.remove(key) else editor.putString(key, encryptToken(value))
        editor.apply()
    }

    private fun saveSessionTokens(access: String, refresh: String?) {
        val editor = preferences.edit().putString("access_token", encryptToken(access))
        if (refresh == null) editor.remove("refresh_token")
        else editor.putString("refresh_token", encryptToken(refresh))
        editor.apply()
    }

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

    suspend fun health(): JSONObject = request("GET", "/health", allowRefresh = false)

    suspend fun readiness(): JSONObject = request("GET", "/health/ready", allowRefresh = false)

    suspend fun acceptTerms(termsVersionId: String): JSONObject = request(
        "POST", "/parents/me/terms-acceptances",
        JSONObject().put("termsVersionId", termsVersionId).put("termsAccepted", true)
    )

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
        val access = result.getString("accessToken")
        val refresh = result.optString("refreshToken").takeIf { it.isNotBlank() && it != "null" }
        saveSessionTokens(access, refresh)
        return result
    }

    suspend fun logout() {
        try {
            if (accessToken != null) request("POST", "/auth/logout", allowRefresh = false)
        } finally {
            clearSession()
        }
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

    suspend fun lessons(childId: String, domainCode: String? = null, topicCode: String? = null): JSONObject {
        val query = buildList {
            domainCode?.takeIf { it.isNotBlank() }?.let { add("domainCode=${java.net.URLEncoder.encode(it, "UTF-8")}") }
            topicCode?.takeIf { it.isNotBlank() }?.let { add("topicCode=${java.net.URLEncoder.encode(it, "UTF-8")}") }
        }.joinToString("&").let { if (it.isBlank()) "" else "?$it" }
        return request("GET", "/children/$childId/lessons$query")
    }

    suspend fun curriculum(childId: String): JSONObject = request("GET", "/children/$childId/curriculum")

    suspend fun childDetails(childId: String): JSONObject = request("GET", "/children/$childId")

    suspend fun onboardingAttemptStatus(attemptId: String): JSONObject =
        request("GET", "/children/onboarding-attempts/$attemptId")

    suspend fun learningWorkspace(): JSONObject = request("GET", "/parents/me/learning-workspace")

    suspend fun lesson(childId: String, lessonId: String): JSONObject =
        request("GET", "/children/$childId/lessons/$lessonId")

    suspend fun startLearningSession(childId: String, lessonId: String): JSONObject =
        request("POST", "/children/$childId/learning-sessions", JSONObject().put("lessonId", lessonId))

    suspend fun learningSession(childId: String, sessionId: String): JSONObject =
        request("GET", "/children/$childId/learning-sessions/$sessionId")

    suspend fun learningHistory(childId: String, limit: Int = 20): JSONArray {
        val result = request("GET", "/children/$childId/learning-sessions?limit=$limit")
        return result.optJSONArray("items") ?: JSONArray()
    }

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
        val referenceNotices = reference.optJSONArray("notices")
            ?: reference.optJSONArray("currentNotices")
            ?: JSONArray()
        val attemptNotices = attempt.optJSONArray("notices") ?: JSONArray()
        return (0 until attemptNotices.length()).mapNotNull { index ->
            val snapshot = attemptNotices.optJSONObject(index) ?: return@mapNotNull null
            val purpose = snapshot.optString("purposeCode")
            val current = (0 until referenceNotices.length()).asSequence()
                .mapNotNull { referenceNotices.optJSONObject(it) }
                .firstOrNull { it.optString("purposeCode") == purpose }
                ?.let { notice -> notice.optJSONObject("currentVersion") ?: notice }
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
        val attemptId = attempt.getString("attemptId")
        // Confirm the server-side onboarding attempt is still current before submitting it.
        onboardingAttemptStatus(attemptId)
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
            .put("attemptId", attemptId)
            .put("idempotencyKey", idempotencyKey)
            .put("childAlias", alias).put("dateOfBirth", dateOfBirth)
            .put("stockAvatarKey", JSONObject.NULL).put("guardianAffirmed", true)
            .put("relationshipCode", "PARENT").put("purposeChoices", purposes))
    }

    private suspend fun request(
        method: String,
        path: String,
        body: JSONObject? = null,
        headers: Map<String, String> = emptyMap(),
        allowRefresh: Boolean = true
    ): JSONObject =
        withContext(Dispatchers.IO) {
            val initialToken = accessToken
            var response = executeRequest(method, path, body, headers, initialToken)
            if (response.status == 401 && allowRefresh && path != "/auth/login" &&
                path != "/auth/sessions/refresh" && path != "/auth/logout" && refreshToken != null
            ) {
                try {
                    refreshSession(initialToken)
                    response = executeRequest(method, path, body, headers, accessToken)
                } catch (error: Exception) {
                    clearSession()
                    throw error
                }
            }
            if (response.status == 401 && path != "/auth/login") clearSession()
            decodeResponse(response)
        }

    private data class HttpResponse(val status: Int, val body: String)

    private fun executeRequest(
        method: String,
        path: String,
        body: JSONObject?,
        headers: Map<String, String>,
        bearerToken: String?
    ): HttpResponse {
        val connection = (URL(baseUrl + path).openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 15000
                readTimeout = 20000
                setRequestProperty("Accept", "application/json")
                bearerToken?.let { setRequestProperty("Authorization", "Bearer $it") }
                headers.forEach { (name, value) -> setRequestProperty(name, value) }
                if (body != null) {
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json; charset=utf-8")
                }
            }
        return try {
            if (body != null) connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            HttpResponse(status, stream?.bufferedReader()?.use { it.readText() }.orEmpty())
        } finally { connection.disconnect() }
    }

    private fun decodeResponse(response: HttpResponse): JSONObject {
        val json = if (response.body.isBlank()) JSONObject() else JSONObject(response.body)
        if (response.status !in 200..299) {
            val code = json.optString("code")
            val message = json.optString("message")
            val friendlyMessage = when (code) {
                "EMAIL_ALREADY_REGISTERED" -> "Email này đã được đăng ký. Hãy đăng nhập hoặc dùng email khác."
                "INVALID_CREDENTIALS", "UNAUTHENTICATED" -> "Email hoặc mật khẩu không đúng hoặc phiên đăng nhập đã hết hạn."
                "INVALID_OTP" -> "Mã xác nhận không đúng hoặc đã hết hạn. Vui lòng thử lại."
                "ATTEMPT_EXPIRED" -> "Phiên tạo hồ sơ đã hết hạn. Vui lòng thử lại."
                "CORE_PERMISSION_REQUIRED" -> "Bạn cần xác nhận đầy đủ các mục đồng ý để tạo hồ sơ."
                "DB_NOT_CONFIGURED" -> "Dịch vụ dữ liệu hiện chưa sẵn sàng. Vui lòng thử lại sau."
                "CLOUD_SURFACE_LOCKED" -> "Backend báo route này đang bị khóa."
                else -> message.takeIf { it.isNotBlank() } ?: "Yêu cầu thất bại."
            }
            val diagnostic = buildList {
                add("HTTP ${response.status}")
                code.takeIf { it.isNotBlank() }?.let { add(it) }
                json.optString("requestId").takeIf { it.isNotBlank() && it != "null" }
                    ?.let { add("requestId: $it") }
                if (code == "CLOUD_SURFACE_LOCKED" && message.isNotBlank()) add("Backend: $message")
            }.joinToString(" · ")
            throw IOException("$friendlyMessage\n$diagnostic")
        }
        return json
    }

    private suspend fun refreshSession(failedAccessToken: String?) {
        refreshMutex.withLock {
            if (accessToken != failedAccessToken && accessToken != null) return
            val token = refreshToken ?: throw IOException("Phiên đã hết hạn. Vui lòng đăng nhập lại.")
            val raw = executeRequest(
                "POST", "/auth/sessions/refresh", JSONObject().put("refreshToken", token), emptyMap(), null
            )
            val response = decodeResponse(raw)
            val newAccess = response.optString("accessToken")
            val newRefresh = response.optString("refreshToken")
            if (newAccess.isBlank() || newRefresh.isBlank() || newAccess == "null" || newRefresh == "null") {
                throw IOException("Máy chủ không trả cặp token mới hợp lệ. Vui lòng đăng nhập lại.")
            }
            saveSessionTokens(newAccess, newRefresh)
        }
    }
}
