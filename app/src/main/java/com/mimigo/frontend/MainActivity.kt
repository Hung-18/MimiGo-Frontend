package com.mimigo.frontend

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.Modifier
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import com.mimigo.frontend.data.MimiGoApi
import com.mimigo.frontend.ui.screens.*
import com.mimigo.frontend.ui.theme.MimiGoTheme
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.json.JSONArray
import java.io.IOException

private enum class Screen { Welcome, Register, RegisterSuccess, Verify, Login, Forgot, ResetPassword, ChildProfile, Home, Lessons, Learning, Progress, ParentProfile, Premium, Checkout, Notifications, Settings, Terms, Favorites, GatePin, GateSetup, GateChange }

class MainActivity : ComponentActivity() {
    private var incomingResetToken by mutableStateOf<String?>(null)

    private fun handleDeepLink(intent: Intent?) {
        val data = intent?.data ?: return
        if (data.scheme == "mimigo" && data.host == "reset-password") incomingResetToken = data.getQueryParameter("token").orEmpty()
    }

    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); setIntent(intent); handleDeepLink(intent) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        if (savedInstanceState == null) handleDeepLink(intent)
        setContent {
            MimiGoTheme {
                val api = remember { MimiGoApi(applicationContext) }
                val backStack = remember { mutableStateListOf(Screen.Welcome) }
                val current = backStack.last()
                var selectedTab by rememberSaveable { mutableStateOf("HOME") }
                val scope = rememberCoroutineScope()
                var pendingEmail by rememberSaveable { mutableStateOf("") }
                var resetToken by rememberSaveable { mutableStateOf("") }
                var resetSuccess by rememberSaveable { mutableStateOf(false) }
                var childName by rememberSaveable { mutableStateOf("") }
                var childId by rememberSaveable { mutableStateOf("") }
                var selectedLessonId by rememberSaveable { mutableStateOf("") }
                var selectedPlan by remember { mutableStateOf<JSONObject?>(null) }
                var useEnglish by rememberSaveable { mutableStateOf(getSharedPreferences("mimigo_preferences", MODE_PRIVATE).getBoolean("english", false)) }
                var childRoster by remember { mutableStateOf(emptyList<ChildHomeProfile>()) }
                var childAttempt by remember { mutableStateOf<JSONObject?>(null) }
                var childIdempotencyKey by rememberSaveable { mutableStateOf("") }
                var childNoticeSummaries by remember { mutableStateOf(emptyList<String>()) }
                var isLoading by remember { mutableStateOf(false) }
                var serverError by remember { mutableStateOf<String?>(null) }
                var gateError by remember { mutableStateOf<String?>(null) }
                var registrationDocument by remember { mutableStateOf<String?>(null) }

                fun navigate(screen: Screen) { backStack.add(screen) }
                fun switch(screen: Screen) { backStack[backStack.lastIndex] = screen }
                fun selectTab(tab: String) {
                    selectedTab = tab
                    val destination = when (tab) {
                        "LESSONS" -> Screen.Lessons
                        "FAVORITES" -> Screen.Favorites
                        "PROGRESS" -> Screen.Progress
                        "PROFILE" -> Screen.ParentProfile
                        else -> Screen.Home
                    }
                    backStack.clear(); backStack.add(destination)
                }
                fun welcome() { backStack.clear(); backStack.add(Screen.Welcome); api.clearSession() }
                fun logoutToWelcome() {
                    scope.launch {
                        try {
                            api.logout()
                        } catch (_: Exception) {
                            Toast.makeText(this@MainActivity, "Đã xóa phiên trên thiết bị; máy chủ chưa xác nhận thu hồi do mất kết nối.", Toast.LENGTH_LONG).show()
                        } finally {
                            welcome()
                        }
                    }
                }
                fun back() { if (backStack.size > 1) backStack.removeAt(backStack.lastIndex) }
                fun backFromTab() {
                    if (backStack.size > 1) back() else selectTab("HOME")
                }
                fun home(name: String?, id: String = "", roster: List<ChildHomeProfile> = emptyList()) {
                    childName = name.orEmpty(); childId = id
                    childRoster = roster.ifEmpty { if (id.isBlank()) emptyList() else listOf(ChildHomeProfile(id, name.orEmpty())) }
                    selectedTab = "HOME"
                    backStack.clear(); backStack.add(Screen.Home)
                }
                fun request(block: suspend () -> Unit) {
                    if (isLoading) return
                    isLoading = true
                    serverError = null
                    scope.launch {
                        try { block() }
                        catch (error: Exception) {
                            serverError = when (error) {
                                is IOException -> error.message ?: "Không thể kết nối máy chủ. Hãy kiểm tra API và thử lại."
                                else -> "Dữ liệu máy chủ chưa đúng định dạng. Vui lòng thử lại sau."
                            }
                        } finally { isLoading = false }
                    }
                }
                LaunchedEffect(current) { serverError = null; gateError = null }
                BackHandler(enabled = backStack.size > 1) { back() }
                LaunchedEffect(incomingResetToken) {
                    incomingResetToken?.let {
                        resetToken = it; resetSuccess = false
                        backStack.clear(); backStack.add(Screen.Welcome); backStack.add(Screen.ResetPassword)
                        incomingResetToken = null
                    }
                }

                val tabOrder = listOf("HOME", "LESSONS", "FAVORITES", "PROGRESS", "PROFILE")
                val tabScreens = setOf(Screen.Home, Screen.Lessons, Screen.Favorites, Screen.Progress, Screen.ParentProfile)
                Column(Modifier.fillMaxSize()) {
                AnimatedContent(
                    targetState = current,
                    modifier = Modifier.weight(1f).pointerInput(current, selectedTab) {
                        var horizontalDistance = 0f
                        detectHorizontalDragGestures(
                            onHorizontalDrag = { change, amount ->
                                horizontalDistance += amount
                                change.consume()
                            },
                            onDragEnd = {
                                if (current in tabScreens && kotlin.math.abs(horizontalDistance) > 80f) {
                                    val direction = if (horizontalDistance < 0) 1 else -1
                                    val next = tabOrder.getOrNull(tabOrder.indexOf(selectedTab) + direction)
                                    if (next != null) selectTab(next)
                                }
                                horizontalDistance = 0f
                            },
                            onDragCancel = { horizontalDistance = 0f }
                        )
                    },
                    transitionSpec = { fadeIn(tween(280)) togetherWith fadeOut(tween(220)) },
                    label = "screen_transition"
                ) { screen ->
                    when (screen) {
                        Screen.Welcome -> WelcomeScreen(
                            onRegisterClick = { navigate(Screen.Register) },
                            onGoogleSignInClick = { Toast.makeText(this@MainActivity, "Đăng nhập Google chưa được backend hỗ trợ.", Toast.LENGTH_LONG).show() },
                            onAppleSignInClick = { Toast.makeText(this@MainActivity, "Đăng nhập Apple chưa được backend hỗ trợ.", Toast.LENGTH_LONG).show() },
                            onLoginClick = { navigate(Screen.Login) }
                        )
                        Screen.Register -> RegisterScreen(
                            isLoading = isLoading, serverError = serverError, onBackClick = { back() },
                            onTermsClick = { registrationDocument = "terms" },
                            onPrivacyClick = { registrationDocument = "privacy" },
                            onSubmit = { email, password, name ->
                                request {
                                    api.register(email, password, name)
                                    pendingEmail = email; switch(Screen.RegisterSuccess)
                                }
                            },
                            onLoginClick = { switch(Screen.Login) }
                        )
                        Screen.RegisterSuccess -> RegisterSuccessScreen(
                            email = pendingEmail,
                            onContinueClick = { navigate(Screen.Verify) },
                            onResendClick = {
                                scope.launch {
                                    runCatching { api.resendVerification(pendingEmail) }
                                    Toast.makeText(this@MainActivity, "Nếu email đang chờ xác minh và giới hạn cho phép, mã mới sẽ được gửi.", Toast.LENGTH_LONG).show()
                                }
                            }
                        )
                        Screen.Verify -> VerifyCodeScreen(
                            email = pendingEmail, isLoading = isLoading, serverError = serverError, onBackClick = { back() },
                            onSubmit = { code -> request {
                                api.verify(pendingEmail, code)
                                Toast.makeText(this@MainActivity, "Email đã xác minh. Đăng nhập để tiếp tục.", Toast.LENGTH_LONG).show()
                                backStack.clear(); backStack.add(Screen.Welcome); backStack.add(Screen.Login)
                            } },
                            onResendClick = {
                                scope.launch {
                                    runCatching { api.resendVerification(pendingEmail) }
                                    Toast.makeText(this@MainActivity, "Nếu email đang chờ xác minh và giới hạn cho phép, mã mới sẽ được gửi.", Toast.LENGTH_LONG).show()
                                }
                            }
                        )
                        Screen.Login -> LoginScreen(
                            isLoading = isLoading, serverError = serverError, onBackClick = { back() },
                            onSubmit = { email, password -> request {
                                api.login(email, password)
                                val children = api.children()
                                if (children.length() > 0) {
                                    val child = children.getJSONObject(0)
                                    val roster = (0 until children.length()).mapNotNull { index ->
                                        children.optJSONObject(index)?.let { profile ->
                                            ChildHomeProfile(
                                                profile.optString("childId"),
                                                profile.optString("childAlias"),
                                                if (profile.has("ageYears") && !profile.isNull("ageYears")) profile.optInt("ageYears") else null,
                                                profile.optString("stockAvatarKey").takeIf { it.isNotBlank() && it != "null" }
                                            )
                                        }
                                    }
                                    home(child.optString("childAlias"), child.optString("childId"), roster)
                                }
                                else {
                                    childIdempotencyKey = ""
                                    childAttempt = api.beginChildOnboarding()
                                    childNoticeSummaries = api.onboardingNoticeSummaries(childAttempt!!)
                                    backStack.clear(); backStack.add(Screen.ChildProfile)
                                }
                            } },
                            onForgotPasswordClick = { navigate(Screen.Forgot) },
                            onGoogleSignInClick = { Toast.makeText(this@MainActivity, "Đăng nhập Google chưa được backend hỗ trợ.", Toast.LENGTH_LONG).show() },
                            onAppleSignInClick = { Toast.makeText(this@MainActivity, "Đăng nhập Apple chưa được backend hỗ trợ.", Toast.LENGTH_LONG).show() },
                            onRegisterClick = { switch(Screen.Register) }
                        )
                        Screen.Forgot -> ForgotPasswordScreen(
                            isLoading = false, serverError = "Backend hiện chưa có endpoint quên mật khẩu / gửi liên kết đặt lại.",
                            onHomeClick = { welcome() }, onSubmit = { }, onBackToLoginClick = { back() }
                        )
                        Screen.ChildProfile -> ChildProfileScreen(
                            isLoading = isLoading, serverError = serverError,
                            requiredNotices = childNoticeSummaries.ifEmpty { childAttempt?.optJSONArray("notices").toPurposeSummaries().orEmpty() },
                            onSubmit = { profile -> request {
                                try {
                                    val attempt = childAttempt ?: api.beginChildOnboarding().also { childAttempt = it }
                                    if (childNoticeSummaries.isEmpty()) childNoticeSummaries = api.onboardingNoticeSummaries(attempt)
                                    if (childIdempotencyKey.isBlank()) childIdempotencyKey = java.util.UUID.randomUUID().toString()
                                val createdChild = api.createChild(profile.name, profile.dateOfBirth, attempt, childIdempotencyKey)
                                childId = createdChild.optString("childId")
                                } catch (error: IOException) {
                                    if (error.message?.contains("hết hạn", ignoreCase = true) == true) {
                                        childAttempt = null
                                        childNoticeSummaries = emptyList()
                                        childIdempotencyKey = ""
                                    }
                                    throw error
                                }
                                childIdempotencyKey = ""
                                childNoticeSummaries = emptyList()
                                val rosterResponse = runCatching { api.children() }.getOrNull()
                                val roster = if (rosterResponse == null) listOf(ChildHomeProfile(childId, profile.name)) else
                                    (0 until rosterResponse.length()).mapNotNull { index ->
                                        rosterResponse.optJSONObject(index)?.let { childProfile ->
                                            ChildHomeProfile(
                                                childProfile.optString("childId"),
                                                childProfile.optString("childAlias"),
                                                if (childProfile.has("ageYears") && !childProfile.isNull("ageYears")) childProfile.optInt("ageYears") else null,
                                                childProfile.optString("stockAvatarKey").takeIf { it.isNotBlank() && it != "null" }
                                            )
                                        }
                                    }
                                home(profile.nickname.ifBlank { profile.name }, childId, roster)
                            } },
                            onSkip = { home(null) }
                        )
                        Screen.Home -> HomeScreen(
                            childId = childId,
                            childName = childName,
                            children = childRoster,
                            api = api,
                            onChildSelect = { profile -> childId = profile.id; childName = profile.name },
                            onAddChildClick = {
                                request {
                                    childIdempotencyKey = ""
                                    childAttempt = api.beginChildOnboarding()
                                    childNoticeSummaries = api.onboardingNoticeSummaries(childAttempt!!)
                                    navigate(Screen.ChildProfile)
                                }
                            },
                            onLessonClick = { lessonId -> selectedLessonId = lessonId; navigate(Screen.Learning) },
                            onNotificationsClick = { navigate(Screen.Notifications) },
                            onSettingsClick = { navigate(Screen.Settings) }
                        )
                        Screen.Lessons -> HomeScreen(
                            childId = childId,
                            childName = childName,
                            children = childRoster,
                            api = api,
                            lessonsOnly = true,
                            onChildSelect = { profile -> childId = profile.id; childName = profile.name },
                            onAddChildClick = {
                                request {
                                    childIdempotencyKey = ""
                                    childAttempt = api.beginChildOnboarding()
                                    childNoticeSummaries = api.onboardingNoticeSummaries(childAttempt!!)
                                    navigate(Screen.ChildProfile)
                                }
                            },
                            onLessonClick = { lessonId -> selectedLessonId = lessonId; navigate(Screen.Learning) },
                            onNotificationsClick = { navigate(Screen.Notifications) },
                            onSettingsClick = { navigate(Screen.Settings) }
                        )
                        Screen.Learning -> LearningScreen(childId = childId, lessonId = selectedLessonId, api = api, onExit = { back() })
                        Screen.Progress -> ProgressScreen(childId = childId, api = api, onExit = { backFromTab() }, onLessonClick = { lessonId -> selectedLessonId = lessonId; navigate(Screen.Learning) })
                        Screen.ParentProfile -> ParentProfileScreen(
                            api = api, children = childRoster, onBack = { backFromTab() },
                            onPremium = { navigate(Screen.Premium) },
                            onAddChild = {
                                request {
                                    childIdempotencyKey = ""
                                    childAttempt = api.beginChildOnboarding()
                                    childNoticeSummaries = api.onboardingNoticeSummaries(childAttempt!!)
                                    navigate(Screen.ChildProfile)
                                }
                            },
                            onLogout = { logoutToWelcome() }
                        )
                        Screen.Premium -> PremiumPlansScreen(
                            childId = childId, childName = childName, api = api, onBack = { back() },
                            onBuy = { plan -> selectedPlan = plan; navigate(Screen.Checkout) }
                        )
                        Screen.Checkout -> PremiumCheckoutScreen(
                            childName = childName, plan = selectedPlan, onBack = { back() },
                            onPay = { Toast.makeText(this@MainActivity, "Thanh toán đang chờ Parent Gate và module Billing simulator được bật trên backend.", Toast.LENGTH_LONG).show() }
                        )
                        Screen.Notifications -> NotificationsScreen(onBack = { back() })
                        Screen.Settings -> SettingsScreen(
                            english = useEnglish,
                            onEnglishChange = { value -> useEnglish = value; getSharedPreferences("mimigo_preferences", MODE_PRIVATE).edit().putBoolean("english", value).apply() },
                            onBack = { back() }, onTerms = { navigate(Screen.Terms) },
                            onPremium = { navigate(Screen.Premium) }, onParentGate = { navigate(Screen.GatePin) }, onLogout = { logoutToWelcome() }
                        )
                        Screen.Terms -> TermsScreen(api = api, onBack = { back() })
                        Screen.Favorites -> FavoritesScreen(onBack = { backFromTab() })
                        Screen.GatePin -> ParentGatePinScreen(
                            onBack = { back() },
                            onVerify = { gateError = "API Parent Gate chưa bật trên backend; PIN chưa được xác minh." },
                            onSetupPin = { navigate(Screen.GateSetup) },
                            onChangePin = { navigate(Screen.GateChange) },
                            error = gateError
                        )
                        Screen.GateSetup -> ParentGateSetupScreen(
                            onBack = { back() },
                            onSubmit = { _, _, _ -> gateError = "API thiết lập Parent Gate là candidate mặc định tắt; chưa gửi thông tin PIN/mật khẩu." },
                            error = gateError
                        )
                        Screen.GateChange -> ParentGateChangeScreen(
                            onBack = { back() },
                            onSubmit = { _, _, _ -> gateError = "API đổi PIN Parent Gate chưa được bật; chưa gửi PIN lên backend." },
                            error = gateError
                        )
                        Screen.ResetPassword -> ResetPasswordScreen(
                            showSuccessDialog = resetSuccess, isLoading = false,
                            serverError = "Backend hiện chưa có endpoint đặt lại mật khẩu.",
                            onHomeClick = { welcome() }, onSubmit = { },
                            onLoginClick = { resetSuccess = false; resetToken = ""; backStack.clear(); backStack.add(Screen.Welcome); backStack.add(Screen.Login) }
                        )
                }
                if (current in tabScreens) {
                    MainBottomBar(selectedTab = selectedTab, onTabClick = { tab -> selectTab(tab) })
                }
                }
                registrationDocument?.let { document ->
                    RegistrationLegalDialog(
                        api = api,
                        showPrivacy = document == "privacy",
                        onDismiss = { registrationDocument = null }
                    )
                }
            }
        }
    }
}

private fun JSONArray?.toPurposeSummaries(): List<String> {
    if (this == null) return emptyList()
    return (0 until length()).mapNotNull { index ->
        optJSONObject(index)?.let { notice ->
            val code = notice.optString("purposeCode")
            val purpose = when (code) {
                "CHILD_PROFILE_AGE" -> "Tạo và sử dụng hồ sơ độ tuổi của trẻ"
                else -> code.replace('_', ' ').lowercase().replaceFirstChar { it.uppercase() }
            }
            "$purpose · phiên bản ${notice.optString("versionLabel", "hiện hành")}"
        }
    }
}}
