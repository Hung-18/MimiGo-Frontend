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
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Home
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
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.mimigo.frontend.R
import com.mimigo.frontend.ui.components.BackgroundDecor
import com.mimigo.frontend.ui.components.MimiGoHeader
import com.mimigo.frontend.ui.components.pressScale
import com.mimigo.frontend.ui.theme.MimiBlue
import com.mimigo.frontend.ui.theme.MimiGoTheme
import com.mimigo.frontend.ui.theme.MimiNavyText
import com.mimigo.frontend.ui.theme.TextSecondary
import kotlinx.coroutines.delay

private val ErrorRed = Color(0xFFE53935)
private val SuccessGreen = Color(0xFF4CAF50)
private const val MIN_PASSWORD_LENGTH = 6

/**
 * Màn hình "Mật khẩu mới": mở ra khi người dùng bấm vào liên kết đặt lại mật khẩu trong email.
 *
 * @param showSuccessDialog true thì hiện pop-up "Tạo mật khẩu mới thành công".
 *        Biến này do bên ngoài điều khiển để sau này chỉ bật khi API trả về thành công.
 * @param serverError lỗi từ server (ví dụ liên kết đã hết hạn), hiện dưới ô nhập.
 */
@Composable
fun ResetPasswordScreen(
    showSuccessDialog: Boolean = false,
    serverError: String? = null,
    onHomeClick: () -> Unit = {},
    onSubmit: (newPassword: String) -> Unit = {},
    onLoginClick: () -> Unit = {},
    isLoading: Boolean = false,
    modifier: Modifier = Modifier
) {
    var newPassword by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var showNewPassword by remember { mutableStateOf(false) }
    var showConfirmPassword by remember { mutableStateOf(false) }
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
        errorMessage = when {
            newPassword.length < MIN_PASSWORD_LENGTH ->
                "Mật khẩu cần ít nhất $MIN_PASSWORD_LENGTH ký tự"
            confirmPassword != newPassword -> "Mật khẩu xác nhận không khớp"
            else -> null
        }
        if (errorMessage == null) onSubmit(newPassword)
    }

    BackgroundDecor(
        modifier = modifier,
        backgroundRes = R.drawable.login_bg
    ) {
        // Bố cục vừa khít một màn hình: logo ở trên, form ở dưới, con ong ở giữa
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
                        // Nút Home: về màn đầu tiên
                        Row(modifier = Modifier.fillMaxWidth()) {
                            val homeInteraction = remember { MutableInteractionSource() }
                            Box(
                                modifier = Modifier
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
                        }

                        // Logo "MimiGo" + slogan giống các màn trước
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
                                .padding(horizontal = 18.dp, vertical = 18.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Mật khẩu mới",
                                color = MimiNavyText,
                                fontSize = 22.sp,
                                fontWeight = FontWeight.ExtraBold
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "Tạo mật khẩu mới (ít nhất $MIN_PASSWORD_LENGTH ký tự)\nđể tiếp tục sử dụng MimiGo.",
                                color = TextSecondary,
                                fontSize = 12.5.sp,
                                textAlign = TextAlign.Center,
                                lineHeight = 17.sp
                            )

                            Spacer(modifier = Modifier.height(14.dp))

                            RegisterField(
                                value = newPassword,
                                onValueChange = {
                                    newPassword = it
                                    errorMessage = null
                                    showServerError = false
                                },
                                placeholder = "Mật khẩu mới",
                                icon = Icons.Filled.Lock,
                                iconTint = Color(0xFF9C27B0),
                                keyboardType = KeyboardType.Password,
                                isPassword = true,
                                passwordVisible = showNewPassword,
                                onToggleVisibility = { showNewPassword = !showNewPassword }
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            RegisterField(
                                value = confirmPassword,
                                onValueChange = {
                                    confirmPassword = it
                                    errorMessage = null
                                    showServerError = false
                                },
                                placeholder = "Nhập lại mật khẩu mới",
                                icon = Icons.Filled.Lock,
                                iconTint = Color(0xFF9C27B0),
                                keyboardType = KeyboardType.Password,
                                isPassword = true,
                                passwordVisible = showConfirmPassword,
                                onToggleVisibility = { showConfirmPassword = !showConfirmPassword }
                            )

                            (errorMessage ?: serverError.takeIf { showServerError })?.let {
                                Spacer(modifier = Modifier.height(8.dp))
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
                                text = "Đổi mật khẩu",
                                onClick = { validateAndSubmit() },
                                isLoading = isLoading
                            )
                        }
                    }
                }
            }
        }

        if (showSuccessDialog) {
            ResetSuccessDialog(onLoginClick = onLoginClick)
        }
    }
}

/**
 * Pop-up "Tạo mật khẩu mới thành công" với nút Đăng nhập bên dưới.
 * Không đóng được bằng cách bấm ra ngoài / nút Back, người dùng phải bấm Đăng nhập.
 */
@Composable
private fun ResetSuccessDialog(onLoginClick: () -> Unit) {
    Dialog(
        onDismissRequest = {},
        properties = DialogProperties(
            dismissOnBackPress = false,
            dismissOnClickOutside = false
        )
    ) {
        Box(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier
                    .padding(top = 32.dp)
                    .fillMaxWidth()
                    .shadow(12.dp, RoundedCornerShape(28.dp))
                    .clip(RoundedCornerShape(28.dp))
                    .background(Color.White)
                    .padding(start = 20.dp, end = 20.dp, top = 44.dp, bottom = 22.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "Tạo mật khẩu mới\nthành công!",
                    color = MimiBlue,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.ExtraBold,
                    textAlign = TextAlign.Center,
                    lineHeight = 28.sp
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Mật khẩu của bạn đã được cập nhật.\nHãy đăng nhập để tiếp tục cùng Mimi nhé!",
                    color = TextSecondary,
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                    lineHeight = 18.sp
                )
                Spacer(modifier = Modifier.height(18.dp))
                CreateAccountButton(
                    text = "Đăng nhập",
                    onClick = onLoginClick
                )
            }

            // Dấu tick xanh đè lên mép trên của pop-up
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .size(64.dp)
                    .shadow(6.dp, CircleShape)
                    .clip(CircleShape)
                    .background(Color.White)
                    .padding(5.dp)
                    .clip(CircleShape)
                    .background(SuccessGreen),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = "Thành công",
                    tint = Color.White,
                    modifier = Modifier.size(34.dp)
                )
            }
        }
    }
}

@Preview(showBackground = true, showSystemUi = true, device = "id:pixel_7")
@Composable
fun ResetPasswordScreenPreview() {
    MimiGoTheme {
        ResetPasswordScreen()
    }
}

@Preview(showBackground = true, showSystemUi = true, device = "id:pixel_7")
@Composable
fun ResetPasswordSuccessPreview() {
    MimiGoTheme {
        ResetPasswordScreen(showSuccessDialog = true)
    }
}