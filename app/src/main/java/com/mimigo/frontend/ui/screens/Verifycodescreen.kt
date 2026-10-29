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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Refresh
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mimigo.frontend.R
import com.mimigo.frontend.ui.components.BackgroundDecor
import com.mimigo.frontend.ui.components.MimiGoHeader
import com.mimigo.frontend.ui.components.pressScale
import com.mimigo.frontend.ui.theme.MimiBlue
import com.mimigo.frontend.ui.theme.MimiGoTheme
import com.mimigo.frontend.ui.theme.MimiNavyText
import com.mimigo.frontend.ui.theme.MimiPink
import com.mimigo.frontend.ui.theme.TextSecondary
import com.mimigo.frontend.ui.theme.TextSubtle
import kotlinx.coroutines.delay

private val ErrorRed = Color(0xFFE53935)
private const val CODE_LENGTH = 6
private const val CODE_VALID_SECONDS = 5 * 60
private const val RESEND_COOLDOWN_SECONDS = 60

/**
 * Màn hình "Nhập mã xác nhận": nhập mã 6 số được gửi qua email.
 */
@Composable
fun VerifyCodeScreen(
    email: String,
    onBackClick: () -> Unit = {},
    onSubmit: (code: String) -> Unit = {},
    onResendClick: () -> Unit = {},
    isLoading: Boolean = false,
    serverError: String? = null,
    modifier: Modifier = Modifier
) {
    var code by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    // Lỗi từ server chỉ hiện đến khi người dùng sửa lại ô nhập
    var showServerError by remember(serverError) { mutableStateOf(true) }

    // Mã có hiệu lực 5 phút, gửi lại sau 60 giây (giá trị thật nên do server quyết định)
    var timerKey by remember { mutableStateOf(0) }
    var validSeconds by remember { mutableStateOf(CODE_VALID_SECONDS) }
    var resendSeconds by remember { mutableStateOf(RESEND_COOLDOWN_SECONDS) }
    LaunchedEffect(timerKey) {
        validSeconds = CODE_VALID_SECONDS
        resendSeconds = RESEND_COOLDOWN_SECONDS
        while (validSeconds > 0) {
            delay(1000)
            validSeconds--
            if (resendSeconds > 0) resendSeconds--
        }
    }

    var contentVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(350)
        contentVisible = true
    }

    fun validateAndSubmit() {
        if (isLoading) return
        errorMessage = when {
            validSeconds == 0 -> "Mã đã hết hạn, vui lòng gửi lại mã mới"
            code.length < CODE_LENGTH -> "Vui lòng nhập đủ $CODE_LENGTH chữ số"
            else -> null
        }
        if (errorMessage == null) onSubmit(code)
    }

    fun resend() {
        code = ""
        errorMessage = null
        showServerError = false
        onResendClick()
        timerKey++
    }

    BackgroundDecor(
        modifier = modifier,
        backgroundRes = R.drawable.verify_bg
    ) {
        // Bố cục vừa khít một màn hình: logo ở trên, các khung ở dưới,
        // phần trống ở giữa dành cho con ong. Màn quá nhỏ mới phải cuộn.
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

                        // Logo "MimiGo" + slogan giống các màn trước
                        MimiGoHeader()
                    }

                    AnimatedVisibility(
                        visible = contentVisible,
                        enter = fadeIn(tween(500)) +
                                slideInVertically(animationSpec = tween(600)) { fullHeight -> fullHeight / 3 }
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            // Card nhập mã
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .shadow(8.dp, RoundedCornerShape(28.dp))
                                    .clip(RoundedCornerShape(28.dp))
                                    .background(Color.White.copy(alpha = 0.95f))
                                    .padding(horizontal = 18.dp, vertical = 14.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    text = "Nhập mã xác nhận",
                                    color = MimiBlue,
                                    fontSize = 22.sp,
                                    fontWeight = FontWeight.ExtraBold
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = "Chúng tôi đã gửi mã xác nhận gồm $CODE_LENGTH chữ số đến email",
                                    color = TextSecondary,
                                    fontSize = 12.sp,
                                    textAlign = TextAlign.Center
                                )
                                Text(
                                    text = email,
                                    color = MimiPink,
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.ExtraBold
                                )
                                Text(
                                    text = "Vui lòng kiểm tra hộp thư (hoặc thư rác) và nhập mã bên dưới.",
                                    color = TextSecondary,
                                    fontSize = 12.sp,
                                    textAlign = TextAlign.Center
                                )

                                Spacer(modifier = Modifier.height(10.dp))

                                OtpInput(
                                    code = code,
                                    length = CODE_LENGTH,
                                    onCodeChange = {
                                        code = it
                                        errorMessage = null
                                        showServerError = false
                                    }
                                )

                                Spacer(modifier = Modifier.height(6.dp))

                                Row {
                                    Text(
                                        text = "Mã xác nhận có hiệu lực trong ",
                                        color = TextSecondary,
                                        fontSize = 11.5.sp
                                    )
                                    Text(
                                        text = formatTime(validSeconds),
                                        color = if (validSeconds == 0) ErrorRed else MimiPink,
                                        fontSize = 11.5.sp,
                                        fontWeight = FontWeight.ExtraBold
                                    )
                                }

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
                                    text = "Xác nhận",
                                    onClick = { validateAndSubmit() },
                                    isLoading = isLoading
                                )
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            // Chưa nhận được email?
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(20.dp))
                                    .background(Color(0xFFEAF4FF).copy(alpha = 0.95f))
                                    .padding(10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(36.dp)
                                        .clip(CircleShape)
                                        .background(Color(0xFFDDF1FF)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        imageVector = Icons.Filled.Email,
                                        contentDescription = null,
                                        tint = MimiBlue,
                                        modifier = Modifier.size(24.dp)
                                    )
                                }
                                Spacer(modifier = Modifier.width(10.dp))
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = "Chưa nhận được email?",
                                        color = MimiNavyText,
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.ExtraBold
                                    )
                                    Text(
                                        text = "Hãy kiểm tra thư rác (Spam) hoặc yêu cầu gửi lại mã xác nhận.",
                                        color = TextSecondary,
                                        fontSize = 11.sp,
                                        lineHeight = 14.sp
                                    )
                                }
                                Spacer(modifier = Modifier.width(8.dp))
                                ResendButton(
                                    secondsLeft = resendSeconds,
                                    onClick = { resend() }
                                )
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            // Mẹo nhỏ
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(20.dp))
                                    .background(Color(0xFFFFF3CD).copy(alpha = 0.95f))
                                    .padding(10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Filled.Lightbulb,
                                    contentDescription = null,
                                    tint = Color(0xFFFFB300),
                                    modifier = Modifier.size(30.dp)
                                )
                                Spacer(modifier = Modifier.width(10.dp))
                                Column {
                                    Text(
                                        text = "Mẹo nhỏ",
                                        color = MimiNavyText,
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.ExtraBold
                                    )
                                    Text(
                                        text = "Nếu không thấy email, hãy thử kiểm tra trong mục Spam/Thư rác hoặc thêm email no-reply@mimigo.edu.vn vào danh bạ nhé!",
                                        color = TextSecondary,
                                        fontSize = 11.sp,
                                        lineHeight = 14.sp
                                    )
                                }
                            }
                        }
                    }

                }
            }
        }
    }
}

/**
 * Ô nhập mã 6 số. Dùng một BasicTextField ẩn để nhận bàn phím số / dán mã,
 * còn các ô vuông chỉ để hiển thị từng chữ số.
 */
@Composable
private fun OtpInput(
    code: String,
    length: Int,
    onCodeChange: (String) -> Unit
) {
    var hasFocus by remember { mutableStateOf(false) }

    BasicTextField(
        value = code,
        onValueChange = { input -> onCodeChange(input.filter { it.isDigit() }.take(length)) },
        modifier = Modifier.onFocusChanged { hasFocus = it.isFocused },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
        textStyle = TextStyle(color = Color.Transparent),
        cursorBrush = SolidColor(Color.Transparent),
        decorationBox = { innerTextField ->
            Box {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    repeat(length) { index ->
                        val digit = code.getOrNull(index)?.toString().orEmpty()
                        val isCurrent = hasFocus && index == code.length.coerceAtMost(length - 1)
                        val isFilled = digit.isNotEmpty()
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(50.dp)
                                .clip(RoundedCornerShape(14.dp))
                                .background(if (isFilled) Color(0xFFFFF0F6) else Color(0xFFF4F6FA))
                                .border(
                                    width = if (isFilled || isCurrent) 1.5.dp else 1.dp,
                                    color = if (isFilled || isCurrent) MimiPink else Color(0xFFE3E8F0),
                                    shape = RoundedCornerShape(14.dp)
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            when {
                                isFilled -> Text(
                                    text = digit,
                                    color = MimiBlue,
                                    fontSize = 24.sp,
                                    fontWeight = FontWeight.ExtraBold
                                )
                                isCurrent -> Text(
                                    text = "|",
                                    color = MimiPink,
                                    fontSize = 24.sp,
                                    fontWeight = FontWeight.Light
                                )
                            }
                        }
                    }
                }
                // Ô nhập thật nằm trong suốt, phủ lên các ô vuông để bấm vào là nhập được
                Box(
                    modifier = Modifier
                        .matchParentSize()
                        .alpha(0f)
                ) {
                    innerTextField()
                }
            }
        }
    )
}

@Composable
private fun ResendButton(secondsLeft: Int, onClick: () -> Unit) {
    val canResend = secondsLeft == 0
    val interactionSource = remember { MutableInteractionSource() }
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Row(
            modifier = Modifier
                .pressScale(interactionSource)
                .clip(CircleShape)
                .background(Color.White)
                .border(
                    1.dp,
                    if (canResend) MimiBlue else Color(0xFFE3E8F0),
                    CircleShape
                )
                .clickable(
                    enabled = canResend,
                    interactionSource = interactionSource,
                    indication = ripple(),
                    onClick = onClick
                )
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Gửi lại mã",
                color = if (canResend) MimiBlue else TextSubtle,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.width(4.dp))
            Icon(
                imageVector = Icons.Filled.Refresh,
                contentDescription = null,
                tint = if (canResend) MimiBlue else TextSubtle,
                modifier = Modifier.size(14.dp)
            )
        }
        Text(
            text = if (canResend) "(Sẵn sàng)" else "(Sau $secondsLeft giây)",
            color = TextSubtle,
            fontSize = 10.sp
        )
    }
}

private fun formatTime(totalSeconds: Int): String =
    "%02d:%02d".format(totalSeconds / 60, totalSeconds % 60)

@Preview(showBackground = true, showSystemUi = true, device = "id:pixel_7")
@Composable
fun VerifyCodeScreenPreview() {
    MimiGoTheme {
        VerifyCodeScreen(email = "hienle88@gmail.com")
    }
}