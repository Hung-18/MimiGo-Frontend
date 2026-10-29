package com.mimigo.frontend.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Home
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
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mimigo.frontend.R
import com.mimigo.frontend.ui.components.BackgroundDecor
import com.mimigo.frontend.ui.components.pressScale
import com.mimigo.frontend.ui.theme.MimiBlue
import com.mimigo.frontend.ui.theme.MimiGoTheme
import com.mimigo.frontend.ui.theme.MimiNavyText
import com.mimigo.frontend.ui.theme.MimiPink
import com.mimigo.frontend.ui.theme.TextSecondary
import kotlinx.coroutines.delay

private val ErrorRed = Color(0xFFE53935)

/**
 * Màn hình Quên mật khẩu: nhập email để nhận liên kết đặt lại mật khẩu.
 * - Góc trái trên: nút Home về màn đầu tiên (Welcome).
 * - Tiêu đề "Quên mật khẩu" (khung trắng, chữ navy) thay cho logo + slogan.
 * - Dưới nút Tiếp tục có nút "Quay lại đăng nhập".
 */
@Composable
fun ForgotPasswordScreen(
    onHomeClick: () -> Unit = {},
    onSubmit: (email: String) -> Unit = {},
    onBackToLoginClick: () -> Unit = {},
    isLoading: Boolean = false,
    serverError: String? = null,
    modifier: Modifier = Modifier
) {
    var email by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    // Lỗi từ server chỉ hiện đến khi người dùng sửa lại ô nhập
    var showServerError by remember(serverError) { mutableStateOf(true) }

    var contentVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(350)
        contentVisible = true
    }

    fun validateAndSubmit() {
        if (isLoading) return
        errorMessage =
            if (!android.util.Patterns.EMAIL_ADDRESS.matcher(email.trim()).matches())
                "Email chưa hợp lệ" else null
        if (errorMessage == null) onSubmit(email.trim())
    }

    // Chừa chỗ cho con ong ở phần trên của ảnh nền
    val screenHeight = LocalConfiguration.current.screenHeightDp
    val spacerForBee = (screenHeight * 0.55f - 70f).coerceAtLeast(8f).dp

    BackgroundDecor(
        modifier = modifier,
        backgroundRes = R.drawable.forgot_bg
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .systemBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Hàng trên cùng: nút Home (trái) + tiêu đề "Quên mật khẩu" (giữa)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp),
                contentAlignment = Alignment.Center
            ) {
                val homeInteraction = remember { MutableInteractionSource() }
                Box(
                    modifier = Modifier
                        .align(Alignment.CenterStart)
                        .pressScale(homeInteraction, pressedScale = 0.85f)
                        .size(40.dp)
                        .shadow(4.dp, CircleShape)
                        .clip(CircleShape)
                        .background(Color.White)
                        .clickable(
                            interactionSource = homeInteraction,
                            indication = ripple(),
                            onClick = onHomeClick
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Filled.Home,
                        contentDescription = "Về trang chủ",
                        tint = MimiBlue,
                        modifier = Modifier.size(22.dp)
                    )
                }

                // Tiêu đề trong khung trắng bo tròn (giống khung slogan ở các màn trước)
                // để dễ đọc trên mọi nền ảnh
                Box(
                    modifier = Modifier
                        .shadow(4.dp, CircleShape)
                        .clip(CircleShape)
                        .background(Color.White)
                        .padding(horizontal = 22.dp, vertical = 8.dp)
                ) {
                    Text(
                        text = "Quên mật khẩu",
                        color = MimiNavyText,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.ExtraBold,
                        letterSpacing = 0.3.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(spacerForBee))

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
                        .padding(horizontal = 18.dp, vertical = 20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "Nhập email đã đăng ký, Mimi sẽ gửi\nliên kết giúp bạn đặt lại mật khẩu.",
                        color = TextSecondary,
                        fontSize = 13.sp,
                        textAlign = TextAlign.Center,
                        lineHeight = 18.sp
                    )

                    Spacer(modifier = Modifier.height(14.dp))

                    RegisterField(
                        value = email,
                        onValueChange = { email = it; showServerError = false },
                        placeholder = "Email của bạn",
                        icon = Icons.Filled.Email,
                        iconTint = MimiPink,
                        keyboardType = KeyboardType.Email
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

                    Spacer(modifier = Modifier.height(14.dp))

                    CreateAccountButton(
                        text = "Tiếp tục",
                        onClick = { validateAndSubmit() },
                        isLoading = isLoading
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    BackToLoginButton(onClick = onBackToLoginClick)
                }
            }

            Spacer(modifier = Modifier.height(12.dp))
        }
    }
}

/**
 * Nút phụ: viền hồng, nền trắng - "Quay lại đăng nhập"
 */
@Composable
private fun BackToLoginButton(onClick: () -> Unit) {
    val interactionSource = remember { MutableInteractionSource() }
    Box(
        modifier = Modifier
            .pressScale(interactionSource)
            .fillMaxWidth()
            .height(50.dp)
            .clip(CircleShape)
            .background(Color.White)
            .border(1.5.dp, MimiPink, CircleShape)
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(),
                onClick = onClick
            ),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = null,
                tint = MimiPink,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = "Quay lại đăng nhập",
                color = MimiPink,
                fontSize = 16.sp,
                fontWeight = FontWeight.ExtraBold
            )
        }
    }
}

@Preview(showBackground = true, showSystemUi = true, device = "id:pixel_7")
@Composable
fun ForgotPasswordScreenPreview() {
    MimiGoTheme {
        ForgotPasswordScreen()
    }
}