package com.mimigo.frontend.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.text.ClickableText
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import com.mimigo.frontend.ui.components.BackgroundDecor
import com.mimigo.frontend.ui.components.MimiGoHeader
import com.mimigo.frontend.ui.components.pressScale
import com.mimigo.frontend.ui.theme.MimiBlue
import com.mimigo.frontend.ui.theme.MimiGoTheme
import com.mimigo.frontend.ui.theme.MimiNavyText
import com.mimigo.frontend.ui.theme.MimiPink
import com.mimigo.frontend.ui.theme.TextSecondary
import com.mimigo.frontend.ui.theme.TextSubtle

private val FieldBorder = Color(0xFFE3E8F0)
private val ErrorRed = Color(0xFFE53935)

/**
 * Màn hình "Tạo tài khoản phụ huynh" - hiện ra sau khi bấm "Đăng ký ngay".
 */
@Composable
fun RegisterScreen(
    onBackClick: () -> Unit = {},
    onSubmit: (email: String, password: String, parentName: String) -> Unit = { _, _, _ -> },
    onLoginClick: () -> Unit = {},
    onTermsClick: () -> Unit = {},
    onPrivacyClick: () -> Unit = {},
    isLoading: Boolean = false,
    serverError: String? = null,
    modifier: Modifier = Modifier
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var parentName by remember { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }
    var showConfirmPassword by remember { mutableStateOf(false) }
    var agreed by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    // Lỗi từ server chỉ hiện đến khi người dùng sửa lại ô nhập
    var showServerError by remember(serverError) { mutableStateOf(true) }

    // Hiệu ứng: ảnh nền hiện ra trước, sau đó form trượt từ dưới lên
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
            password.length < 6 -> "Mật khẩu cần ít nhất 6 ký tự"
            confirmPassword != password -> "Mật khẩu nhập lại không khớp"
            parentName.isBlank() -> "Vui lòng nhập họ và tên phụ huynh"
            !agreed -> "Bạn cần đồng ý với điều khoản để tiếp tục"
            else -> null
        }
        if (errorMessage == null) onSubmit(email.trim(), password, parentName.trim())
    }

    BackgroundDecor(modifier = modifier) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .systemBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
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

            MimiGoHeader()

            Spacer(modifier = Modifier.height(20.dp))

            AnimatedVisibility(
                visible = contentVisible,
                enter = fadeIn(tween(500)) +
                        slideInVertically(animationSpec = tween(600)) { fullHeight -> fullHeight / 3 }
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    // Card form
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .shadow(8.dp, RoundedCornerShape(28.dp))
                            .clip(RoundedCornerShape(28.dp))
                            .background(Color.White.copy(alpha = 0.92f))
                            .padding(horizontal = 18.dp, vertical = 22.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "Tạo tài khoản phụ huynh",
                            color = MimiNavyText,
                            fontSize = 22.sp,
                            fontWeight = FontWeight.ExtraBold,
                            textAlign = TextAlign.Center
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Chỉ cần một tài khoản, bạn có thể tạo nhiều\nhồ sơ cho các con.",
                            color = TextSecondary,
                            fontSize = 13.sp,
                            textAlign = TextAlign.Center,
                            lineHeight = 18.sp
                        )

                        Spacer(modifier = Modifier.height(18.dp))

                        RegisterField(
                            value = email,
                            onValueChange = { email = it; showServerError = false },
                            placeholder = "Email của bạn",
                            icon = Icons.Filled.Email,
                            iconTint = MimiPink,
                            keyboardType = KeyboardType.Email
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        RegisterField(
                            value = password,
                            onValueChange = { password = it; showServerError = false },
                            placeholder = "Tạo mật khẩu",
                            icon = Icons.Filled.Lock,
                            iconTint = Color(0xFF9C27B0),
                            keyboardType = KeyboardType.Password,
                            isPassword = true,
                            passwordVisible = showPassword,
                            onToggleVisibility = { showPassword = !showPassword }
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        RegisterField(
                            value = confirmPassword,
                            onValueChange = { confirmPassword = it; showServerError = false },
                            placeholder = "Nhập lại mật khẩu",
                            icon = Icons.Filled.Lock,
                            iconTint = Color(0xFF9C27B0),
                            keyboardType = KeyboardType.Password,
                            isPassword = true,
                            passwordVisible = showConfirmPassword,
                            onToggleVisibility = { showConfirmPassword = !showConfirmPassword }
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        RegisterField(
                            value = parentName,
                            onValueChange = { parentName = it; showServerError = false },
                            placeholder = "Họ và tên phụ huynh",
                            icon = Icons.Filled.Person,
                            iconTint = MimiBlue,
                            keyboardType = KeyboardType.Text
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        // Checkbox điều khoản
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Checkbox(
                                checked = agreed,
                                onCheckedChange = { agreed = it },
                                colors = CheckboxDefaults.colors(
                                    checkedColor = MimiPink,
                                    uncheckedColor = TextSubtle,
                                    checkmarkColor = Color.White
                                )
                            )
                            val legalText = buildAnnotatedString {
                                    append("Tôi đồng ý với ")
                                    pushStringAnnotation(tag = "LEGAL", annotation = "TERMS")
                                    withStyle(
                                        SpanStyle(
                                            color = MimiBlue,
                                            fontWeight = FontWeight.SemiBold,
                                            textDecoration = TextDecoration.Underline
                                        )
                                    ) { append("Điều khoản sử dụng") }
                                    pop()
                                    append(" và ")
                                    pushStringAnnotation(tag = "LEGAL", annotation = "PRIVACY")
                                    withStyle(
                                        SpanStyle(
                                            color = MimiBlue,
                                            fontWeight = FontWeight.SemiBold,
                                            textDecoration = TextDecoration.Underline
                                        )
                                    ) { append("Chính sách bảo mật") }
                                    pop()
                                    append(" của MimiGo.")
                                }
                            ClickableText(
                                text = legalText,
                                modifier = Modifier.weight(1f),
                                style = TextStyle(color = MimiNavyText, fontSize = 12.sp, lineHeight = 17.sp),
                                onClick = { offset ->
                                    legalText.getStringAnnotations("LEGAL", offset, offset).firstOrNull()?.let { link ->
                                        if (link.item == "TERMS") onTermsClick() else onPrivacyClick()
                                    }
                                }
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

                        Spacer(modifier = Modifier.height(14.dp))

                        CreateAccountButton(onClick = { validateAndSubmit() },
                            isLoading = isLoading)

                        Spacer(modifier = Modifier.height(14.dp))

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "Đã có tài khoản? ",
                                color = TextSecondary,
                                fontSize = 13.sp
                            )
                            Text(
                                text = "Đăng nhập",
                                color = MimiBlue,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold,
                                textDecoration = TextDecoration.Underline,
                                modifier = Modifier.clickable { onLoginClick() }
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    // 3 lợi ích: An toàn / Một tài khoản / Cá nhân hóa
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .shadow(6.dp, RoundedCornerShape(20.dp))
                            .clip(RoundedCornerShape(20.dp))
                            .background(Color.White.copy(alpha = 0.95f))
                            .padding(vertical = 12.dp, horizontal = 8.dp),
                        horizontalArrangement = Arrangement.SpaceEvenly
                    ) {
                        BenefitItem(
                            modifier = Modifier.weight(1f),
                            icon = Icons.Filled.Shield,
                            tint = Color(0xFFFFB300),
                            background = Color(0xFFFFF3CD),
                            title = "An toàn",
                            subtitle = "Bảo vệ thông tin\ncủa gia đình bạn"
                        )
                        BenefitItem(
                            modifier = Modifier.weight(1f),
                            icon = Icons.Filled.Group,
                            tint = MimiPink,
                            background = Color(0xFFFFE0EB),
                            title = "Một tài khoản",
                            subtitle = "Tạo nhiều hồ sơ\ncho các con"
                        )
                        BenefitItem(
                            modifier = Modifier.weight(1f),
                            icon = Icons.Filled.Favorite,
                            tint = MimiBlue,
                            background = Color(0xFFDDF1FF),
                            title = "Cá nhân hóa",
                            subtitle = "Lộ trình phù hợp\ntừng độ tuổi"
                        )
                    }

                }
            }

            Spacer(modifier = Modifier.height(12.dp))
        }
    }
}

@Composable
internal fun RegisterField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    icon: ImageVector,
    iconTint: Color,
    keyboardType: KeyboardType,
    modifier: Modifier = Modifier,
    isPassword: Boolean = false,
    passwordVisible: Boolean = false,
    onToggleVisibility: () -> Unit = {}
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier.fillMaxWidth(),
        singleLine = true,
        shape = RoundedCornerShape(16.dp),
        placeholder = { Text(placeholder, color = TextSubtle, fontSize = 15.sp) },
        leadingIcon = {
            Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(24.dp))
        },
        trailingIcon = if (isPassword) {
            {
                Icon(
                    imageVector = if (passwordVisible) Icons.Filled.Visibility else Icons.Filled.VisibilityOff,
                    contentDescription = if (passwordVisible) "Ẩn mật khẩu" else "Hiện mật khẩu",
                    tint = TextSubtle,
                    modifier = Modifier
                        .size(24.dp)
                        .clickable { onToggleVisibility() }
                )
            }
        } else null,
        visualTransformation = if (isPassword && !passwordVisible)
            PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = MimiPink,
            unfocusedBorderColor = FieldBorder,
            focusedContainerColor = Color.White,
            unfocusedContainerColor = Color.White,
            focusedTextColor = MimiNavyText,
            unfocusedTextColor = MimiNavyText,
            cursorColor = MimiPink
        )
    )
}

@Composable
internal fun CreateAccountButton(
    onClick: () -> Unit,
    text: String = "Tạo tài khoản",
    isLoading: Boolean = false
) {
    val interactionSource = remember { MutableInteractionSource() }
    Box(
        modifier = Modifier
            .pressScale(interactionSource)
            .fillMaxWidth()
            .height(54.dp)
            .shadow(
                elevation = 8.dp,
                shape = CircleShape,
                ambientColor = MimiPink,
                spotColor = MimiPink
            )
            .clip(CircleShape)
            .background(
                Brush.horizontalGradient(listOf(Color(0xFFFF6FA5), Color(0xFFFF3D8B)))
            )
            .clickable(
                enabled = !isLoading,
                interactionSource = interactionSource,
                indication = ripple(),
                onClick = onClick
            ),
        contentAlignment = Alignment.Center
    ) {
        if (isLoading) {
            // Đang gọi server: hiện vòng xoay, nút bị khóa để không bấm trùng
            CircularProgressIndicator(
                color = Color.White,
                strokeWidth = 3.dp,
                modifier = Modifier.size(26.dp)
            )
        } else {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = text,
                    color = Color.White,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                Spacer(modifier = Modifier.width(10.dp))
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(22.dp)
                )
            }
        }
    }
}

@Composable
private fun BenefitItem(
    icon: ImageVector,
    tint: Color,
    background: Color,
    title: String,
    subtitle: String,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.padding(horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(CircleShape)
                .background(background),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
        }
        Spacer(modifier = Modifier.width(5.dp))
        Column {
            Text(
                text = title,
                color = MimiNavyText,
                fontSize = 11.sp,
                fontWeight = FontWeight.ExtraBold,
                lineHeight = 13.sp
            )
            Text(
                text = subtitle,
                color = TextSubtle,
                fontSize = 8.5.sp,
                lineHeight = 11.sp
            )
        }
    }
}

@Preview(showBackground = true, showSystemUi = true, device = "id:pixel_7")
@Composable
fun RegisterScreenPreview() {
    MimiGoTheme {
        RegisterScreen()
    }
}
