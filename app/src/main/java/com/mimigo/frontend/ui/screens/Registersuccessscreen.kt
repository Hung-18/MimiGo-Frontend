
package com.mimigo.frontend.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Pin
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mimigo.frontend.R
import com.mimigo.frontend.ui.components.BackgroundDecor
import com.mimigo.frontend.ui.theme.MimiBlue
import com.mimigo.frontend.ui.theme.MimiGoTheme
import com.mimigo.frontend.ui.theme.MimiNavyText
import com.mimigo.frontend.ui.theme.MimiPink
import com.mimigo.frontend.ui.theme.TextSecondary
import com.mimigo.frontend.ui.theme.TextSubtle
import kotlinx.coroutines.delay

private val SuccessGreen = Color(0xFF4CAF50)
private const val RESEND_COOLDOWN_SECONDS = 60

/**
 * Màn hình "Tạo tài khoản thành công!" - hiện sau khi đăng ký.
 * Hướng dẫn phụ huynh kiểm tra email để lấy mã xác nhận 6 số.
 */
@Composable
fun RegisterSuccessScreen(
    email: String,
    onContinueClick: () -> Unit = {},
    onResendClick: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    // Đếm ngược để cho phép gửi lại mã (giá trị thật nên do server quyết định)
    var resendKey by remember { mutableStateOf(0) }
    var secondsLeft by remember { mutableStateOf(RESEND_COOLDOWN_SECONDS) }
    LaunchedEffect(resendKey) {
        secondsLeft = RESEND_COOLDOWN_SECONDS
        while (secondsLeft > 0) {
            delay(1000)
            secondsLeft--
        }
    }

    var contentVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(350)
        contentVisible = true
    }

    BackgroundDecor(
        modifier = modifier,
        backgroundRes = R.drawable.verify_bg
    ) {
        // Bố cục vừa khít một màn hình: card nằm sát đáy, phần trống phía trên
        // dành cho con ong. Chỉ màn quá nhỏ mới phải cuộn.
        // Đo chiều cao vùng hiển thị để ép nội dung tối thiểu bằng đúng một màn hình
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
                        .padding(start = 16.dp, end = 16.dp, bottom = 12.dp),
                    verticalArrangement = Arrangement.Bottom,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    AnimatedVisibility(
                        visible = contentVisible,
                        enter = fadeIn(tween(500)) +
                                slideInVertically(animationSpec = tween(600)) { fullHeight -> fullHeight / 3 }
                    ) {
                        Box(modifier = Modifier.fillMaxWidth()) {
                            // Card nội dung (chừa 28dp phía trên cho nửa dưới của dấu tick)
                            Column(
                                modifier = Modifier
                                    .padding(top = 28.dp)
                                    .fillMaxWidth()
                                    .shadow(8.dp, RoundedCornerShape(28.dp))
                                    .clip(RoundedCornerShape(28.dp))
                                    .background(Color.White.copy(alpha = 0.95f))
                                    .padding(start = 18.dp, end = 18.dp, top = 36.dp, bottom = 12.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    text = "Tạo tài khoản thành công!",
                                    color = MimiBlue,
                                    fontSize = 21.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    textAlign = TextAlign.Center
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = "Chúng tôi đã gửi mã xác nhận đến email của bạn",
                                    color = TextSecondary,
                                    fontSize = 13.sp,
                                    textAlign = TextAlign.Center
                                )

                                Spacer(modifier = Modifier.height(10.dp))

                                // Email đã đăng ký
                                Row(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(14.dp))
                                        .background(Color(0xFFFFEAF2))
                                        .padding(horizontal = 18.dp, vertical = 10.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.Center
                                ) {
                                    Icon(
                                        imageVector = Icons.Filled.Email,
                                        contentDescription = null,
                                        tint = MimiPink,
                                        modifier = Modifier.size(22.dp)
                                    )
                                    Spacer(modifier = Modifier.width(10.dp))
                                    Text(
                                        text = email,
                                        color = MimiPink,
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.ExtraBold
                                    )
                                }

                                Spacer(modifier = Modifier.height(6.dp))

                                Text(
                                    text = "Vui lòng kiểm tra hộp thư (hoặc thư rác) và lấy mã xác nhận\nđể tiếp tục hoàn tất đăng ký tài khoản.",
                                    color = TextSecondary,
                                    fontSize = 11.5.sp,
                                    textAlign = TextAlign.Center,
                                    lineHeight = 15.sp
                                )

                                Spacer(modifier = Modifier.height(8.dp))

                                // Các bước tiếp theo
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(18.dp))
                                        .background(Color(0xFFEAF4FF))
                                        .padding(12.dp)
                                ) {
                                    Text(
                                        text = "Các bước tiếp theo",
                                        color = MimiNavyText,
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.ExtraBold
                                    )
                                    Spacer(modifier = Modifier.height(7.dp))
                                    NextStepItem(
                                        number = 1,
                                        icon = Icons.Filled.Email,
                                        iconTint = MimiPink,
                                        iconBg = Color(0xFFFFE0EB),
                                        title = "Kiểm tra email",
                                        description = "Mở hộp thư đến (hoặc thư rác) trong email $email để nhận mã xác nhận."
                                    )
                                    Spacer(modifier = Modifier.height(7.dp))
                                    NextStepItem(
                                        number = 2,
                                        icon = Icons.Filled.Pin,
                                        iconTint = MimiBlue,
                                        iconBg = Color(0xFFDDF1FF),
                                        title = "Lấy mã xác nhận",
                                        description = "Mã xác nhận gồm 6 chữ số."
                                    )
                                    Spacer(modifier = Modifier.height(7.dp))
                                    NextStepItem(
                                        number = 3,
                                        icon = Icons.Filled.TouchApp,
                                        iconTint = MimiBlue,
                                        iconBg = Color(0xFFDDF1FF),
                                        title = "Nhập mã ở bước tiếp theo",
                                        description = "Nhập mã xác nhận để hoàn tất đăng ký."
                                    )
                                }

                                Spacer(modifier = Modifier.height(10.dp))

                                CreateAccountButton(
                                    text = "Đã kiểm tra email, nhận được mã",
                                    onClick = onContinueClick
                                )

                                Spacer(modifier = Modifier.height(6.dp))

                                // Gửi lại mã (có thời gian chờ)
                                val canResend = secondsLeft == 0
                                Text(
                                    text = "Gửi lại mã xác nhận",
                                    color = if (canResend) MimiBlue else TextSubtle,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold,
                                    textDecoration = TextDecoration.Underline,
                                    modifier = Modifier.clickable(enabled = canResend) {
                                        onResendClick()
                                        resendKey++
                                    }
                                )
                                Text(
                                    text = if (canResend) "(Bạn có thể gửi lại ngay bây giờ)"
                                    else "(Bạn có thể gửi lại sau $secondsLeft giây)",
                                    color = TextSubtle,
                                    fontSize = 11.sp
                                )
                            }

                            // Dấu tick xanh nằm đè lên mép trên của card
                            Box(
                                modifier = Modifier
                                    .align(Alignment.TopCenter)
                                    .size(56.dp)
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
                                    modifier = Modifier.size(30.dp)
                                )
                            }
                        }
                    }

                }
            }
        }
    }
}

@Composable
private fun NextStepItem(
    number: Int,
    icon: ImageVector,
    iconTint: Color,
    iconBg: Color,
    title: String,
    description: String
) {
    Row(verticalAlignment = Alignment.Top) {
        // Số thứ tự
        Box(
            modifier = Modifier
                .padding(top = 5.dp)
                .size(20.dp)
                .clip(CircleShape)
                .background(Color.White)
                .border(1.5.dp, MimiPink, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = number.toString(),
                color = MimiPink,
                fontSize = 12.sp,
                fontWeight = FontWeight.ExtraBold
            )
        }
        Spacer(modifier = Modifier.width(10.dp))
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(iconBg),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(20.dp))
        }
        Spacer(modifier = Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                color = MimiNavyText,
                fontSize = 13.sp,
                fontWeight = FontWeight.ExtraBold
            )
            Text(
                text = description,
                color = TextSecondary,
                fontSize = 11.sp,
                lineHeight = 14.sp
            )
        }
    }
}

@Preview(showBackground = true, showSystemUi = true, device = "id:pixel_7")
@Composable
fun RegisterSuccessScreenPreview() {
    MimiGoTheme {
        RegisterSuccessScreen(email = "hienle88@gmail.com")
    }
}
