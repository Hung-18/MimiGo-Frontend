package com.mimigo.frontend.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mimigo.frontend.R
import com.mimigo.frontend.ui.components.AppleRegisterButton
import com.mimigo.frontend.ui.components.BackgroundDecor
import com.mimigo.frontend.ui.components.GoogleRegisterButton
import com.mimigo.frontend.ui.components.MimiGoHeader
import com.mimigo.frontend.ui.components.pressScale
import com.mimigo.frontend.ui.theme.MimiBlue
import com.mimigo.frontend.ui.theme.MimiGoTheme
import com.mimigo.frontend.ui.theme.MimiNavyText
import com.mimigo.frontend.ui.theme.MimiPink
import com.mimigo.frontend.ui.theme.TextSecondary
import kotlinx.coroutines.delay

private val ErrorRed = Color(0xFFE53935)

/**
 * Màn hình Đăng nhập - hiện ra sau khi bấm "Đăng nhập" ở màn Welcome / Đăng ký.
 * Logo + slogan giống hai màn trước; form nằm bên dưới con ong.
 */
@Composable
fun LoginScreen(
    onBackClick: () -> Unit = {},
    onSubmit: (email: String, password: String) -> Unit = { _, _ -> },
    onForgotPasswordClick: () -> Unit = {},
    onGoogleSignInClick: () -> Unit = {},
    onAppleSignInClick: () -> Unit = {},
    onRegisterClick: () -> Unit = {},
    isLoading: Boolean = false,
    serverError: String? = null,
    modifier: Modifier = Modifier
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    // Lỗi từ server chỉ hiện đến khi người dùng sửa lại ô nhập
    var showServerError by remember(serverError) { mutableStateOf(true) }

    // Form trượt từ dưới lên sau khi ảnh nền hiện ra
    var contentVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(350)
        contentVisible = true
    }

    fun validateAndSubmit() {
        if (isLoading) return
        errorMessage = when {
            !android.util.Patterns.EMAIL_ADDRESS.matcher(email.trim()).matches() ->
                "Email chưa hợp lệ"
            password.isEmpty() -> "Vui lòng nhập mật khẩu"
            else -> null
        }
        if (errorMessage == null) onSubmit(email.trim(), password)
    }

    BackgroundDecor(
        modifier = modifier,
        backgroundRes = R.drawable.login_bg
    ) {
        // Bố cục vừa khít một màn hình: logo ở trên, form ở dưới, con ong ở giữa.
        // Màn quá nhỏ mới phải cuộn.
        var screenMinHeight by remember { mutableStateOf(0.dp) }
        val density = LocalDensity.current
        Box(
            modifier = Modifier
                .fillMaxSize()
                .systemBarsPadding()
                .onSizeChanged { size ->
                    screenMinHeight = with(density) { size.height.toDp() }
                }
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = screenMinHeight)
                        .padding(horizontal = 20.dp, vertical = 10.dp),
                    verticalArrangement = Arrangement.SpaceBetween,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        // Nút quay lại
                        Row(modifier = Modifier.fillMaxWidth()) {
                            val backInteraction = remember { MutableInteractionSource() }
                            Box(
                                modifier = Modifier
                                    .pressScale(backInteraction, pressedScale = 0.85f)
                                    .size(40.dp)
                                    .shadow(4.dp, CircleShape)
                                    .clip(CircleShape)
                                    .background(Color.White)
                                    .clickable(
                                        interactionSource = backInteraction,
                                        indication = ripple(),
                                        onClick = onBackClick
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                    contentDescription = "Quay lại",
                                    tint = MimiBlue,
                                    modifier = Modifier.size(22.dp)
                                )
                            }
                        }

                        // Logo "MimiGo" + slogan giống màn Welcome và Đăng ký
                        MimiGoHeader()
                    }

                    AnimatedVisibility(
                        visible = contentVisible,
                        enter = fadeIn(tween(500)) +
                                slideInVertically(animationSpec = tween(600)) { fullHeight -> fullHeight / 3 }
                    ) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .shadow(8.dp, RoundedCornerShape(28.dp))
                                .clip(RoundedCornerShape(28.dp))
                                .background(Color.White.copy(alpha = 0.92f))
                                .padding(horizontal = 18.dp, vertical = 14.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Đăng nhập",
                                color = MimiNavyText,
                                fontSize = 22.sp,
                                fontWeight = FontWeight.ExtraBold,
                                textAlign = TextAlign.Center
                            )
                            Spacer(modifier = Modifier.height(10.dp))

                            RegisterField(
                                value = email,
                                onValueChange = { email = it; showServerError = false },
                                placeholder = "Email của bạn",
                                icon = Icons.Filled.Email,
                                iconTint = MimiPink,
                                keyboardType = KeyboardType.Email
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            RegisterField(
                                value = password,
                                onValueChange = { password = it; showServerError = false },
                                placeholder = "Mật khẩu",
                                icon = Icons.Filled.Lock,
                                iconTint = Color(0xFF9C27B0),
                                keyboardType = KeyboardType.Password,
                                isPassword = true,
                                passwordVisible = showPassword,
                                onToggleVisibility = { showPassword = !showPassword }
                            )

                            // Quên mật khẩu?
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = "Quên mật khẩu?",
                                color = MimiBlue,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold,
                                textDecoration = TextDecoration.Underline,
                                modifier = Modifier
                                    .align(Alignment.End)
                                    .clickable { onForgotPasswordClick() }
                            )

                            (errorMessage ?: serverError.takeIf { showServerError })?.let {
                                Spacer(modifier = Modifier.height(6.dp))
                                Text(
                                    text = it,
                                    color = ErrorRed,
                                    fontSize = 12.5.sp,
                                    fontWeight = FontWeight.Medium,
                                    textAlign = TextAlign.Center
                                )
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            CreateAccountButton(
                                text = "Đăng nhập",
                                onClick = { validateAndSubmit() },
                                isLoading = isLoading
                            )

                            Spacer(modifier = Modifier.height(10.dp))

                            // Đăng nhập bằng Google / Apple giống màn Welcome
                            Column(
                                modifier = Modifier.fillMaxWidth(),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                GoogleRegisterButton(
                                    text = "Đăng nhập bằng Google",
                                    onClick = onGoogleSignInClick
                                )
                                AppleRegisterButton(
                                    text = "Đăng nhập bằng Apple",
                                    onClick = onAppleSignInClick
                                )
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            // Chưa có tài khoản? -> sang màn Đăng ký
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    text = "Bạn chưa có tài khoản? ",
                                    color = TextSecondary,
                                    fontSize = 13.sp
                                )
                                Text(
                                    text = "Đăng ký",
                                    color = MimiBlue,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold,
                                    textDecoration = TextDecoration.Underline,
                                    modifier = Modifier.clickable { onRegisterClick() }
                                )
                            }
                        }
                    }

                }
            }
        }
    }
}

@Preview(showBackground = true, showSystemUi = true, device = "id:pixel_7")
@Composable
fun LoginScreenPreview() {
    MimiGoTheme {
        LoginScreen()
    }
}