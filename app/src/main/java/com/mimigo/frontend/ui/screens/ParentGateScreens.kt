package com.mimigo.frontend.ui.screens

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mimigo.frontend.R
import com.mimigo.frontend.ui.components.pressScale
import com.mimigo.frontend.ui.theme.MimiGoTheme

private val GatePink = Color(0xFFEF4E91)
private val GatePinkLight = Color(0xFFFF8DBB)
private val GateNavy = Color(0xFF3B3A7A)
private val GateError = Color(0xFFD13F66)

/* ───────────── Âm thanh (dùng lại sfx_* của màn học) ───────────── */

private class GateSfx(context: Context) {
    private val pool: SoundPool? = runCatching {
        SoundPool.Builder().setMaxStreams(2).setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
        ).build()
    }.getOrNull()
    private val tapId = load(context, R.raw.sfx_tap)
    private val sorryId = load(context, R.raw.sfx_try_again)
    private fun load(c: Context, res: Int): Int = runCatching { pool?.load(c, res, 1) ?: 0 }.getOrDefault(0)
    private fun play(id: Int) { if (id != 0) runCatching { pool?.play(id, 1f, 1f, 1, 0, 1f) } }
    fun tap() = play(tapId)
    fun sorry() = play(sorryId)
    fun release() { runCatching { pool?.release() } }
}

@Composable
private fun rememberGateSfx(): GateSfx? {
    val context = LocalContext.current
    val inspection = LocalInspectionMode.current
    val sfx = remember { if (inspection) null else GateSfx(context) }
    DisposableEffect(sfx) { onDispose { sfx?.release() } }
    return sfx
}

/* ───────────── Khung trang ───────────── */

@Composable
private fun GatePage(
    title: String,
    subtitle: String,
    onBack: () -> Unit,
    mimi: Int = R.drawable.mimi_happy,
    badge: String = "🔒",
    sfx: GateSfx? = null,
    error: String? = null,
    content: @Composable () -> Unit
) {
    val bob = rememberInfiniteTransition(label = "gate-bob")
    val dy by bob.animateFloat(
        0f, -9f, infiniteRepeatable(tween(1100, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "dy"
    )
    val tilt by bob.animateFloat(
        -4f, 4f, infiniteRepeatable(tween(1500, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "tilt"
    )
    // lắc thẻ + tiếng "thử lại" mỗi khi có lỗi mới
    val shake = remember { Animatable(0f) }
    LaunchedEffect(error) {
        if (!error.isNullOrBlank()) {
            sfx?.sorry()
            for (x in listOf(-12f, 12f, -9f, 9f, -4f, 0f)) shake.animateTo(x, tween(55))
        }
    }
    val backSource = remember { MutableInteractionSource() }

    Box(Modifier.fillMaxSize()) {
        Image(painterResource(R.drawable.verify_bg), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color(0x66FFFFFF), Color(0x33FFE3EF), Color(0xB3FFF0F6)))))

        Column(
            Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().imePadding()
                .verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Box(Modifier.fillMaxWidth()) {
                Box(
                    Modifier.pressScale(backSource, pressedScale = .88f)
                        .size(46.dp).shadow(6.dp, CircleShape).clip(CircleShape).background(Color.White)
                        .border(2.dp, GatePinkLight, CircleShape)
                        .clickable(interactionSource = backSource, indication = null) { sfx?.tap(); onBack() },
                    contentAlignment = Alignment.Center
                ) { Icon(Icons.Filled.ArrowBack, "Quay lại", tint = GatePink, modifier = Modifier.size(24.dp)) }
            }

            Box(Modifier.padding(top = 4.dp)) {
                Image(
                    painterResource(mimi), "Ong Mimi",
                    Modifier.size(width = 96.dp, height = 112.dp).graphicsLayer { translationY = dy; rotationZ = tilt },
                    contentScale = ContentScale.Fit
                )
                Text(
                    badge, fontSize = 26.sp,
                    modifier = Modifier.align(Alignment.TopEnd).padding(end = 0.dp)
                        .clip(CircleShape).background(Color.White).border(2.dp, GatePinkLight, CircleShape).padding(5.dp)
                )
            }
            Text(
                "MimiGo",
                style = TextStyle(
                    fontSize = 28.sp, fontWeight = FontWeight.ExtraBold, color = GatePink,
                    shadow = Shadow(Color.White, Offset.Zero, blurRadius = 18f)
                )
            )
            Text(
                "Cùng học tập và khám phá",
                style = TextStyle(
                    fontSize = 11.sp, fontWeight = FontWeight.Bold, color = GateNavy,
                    shadow = Shadow(Color.White, Offset.Zero, blurRadius = 12f)
                )
            )

            Text(
                title, Modifier.padding(top = 14.dp), color = GateNavy, fontSize = 22.sp, fontWeight = FontWeight.ExtraBold,
                textAlign = TextAlign.Center,
                style = TextStyle(shadow = Shadow(Color.White, Offset.Zero, blurRadius = 14f))
            )
            Text(
                subtitle, Modifier.padding(top = 5.dp, bottom = 16.dp), color = Color(0xFF5E6788), fontSize = 13.sp,
                fontWeight = FontWeight.Medium, textAlign = TextAlign.Center, lineHeight = 19.sp
            )

            val shape = RoundedCornerShape(28.dp)
            Column(
                Modifier.fillMaxWidth().graphicsLayer { translationX = shake.value }
                    .shadow(10.dp, shape).clip(shape).background(Color.White.copy(alpha = .96f))
                    .border(2.5.dp, Brush.horizontalGradient(listOf(GatePinkLight, Color(0xFFFFC857))), shape)
                    .padding(18.dp)
            ) { content() }
            Spacer(Modifier.height(8.dp))
        }
    }
}

/* ───────────── Thành phần ───────────── */

@Composable
private fun GateField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    emoji: String = "🔑",
    password: Boolean = true,
    keyboardType: KeyboardType = KeyboardType.NumberPassword
) {
    OutlinedTextField(
        value = value,
        onValueChange = { text -> onValueChange(if (keyboardType == KeyboardType.NumberPassword) text.filter(Char::isDigit) else text) },
        modifier = Modifier.fillMaxWidth(),
        label = { Text(label) },
        leadingIcon = { Text(emoji, fontSize = 20.sp) },
        singleLine = true,
        visualTransformation = if (password) PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        shape = RoundedCornerShape(20.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = GatePink,
            unfocusedBorderColor = Color(0xFFFFC2DA),
            focusedLabelColor = GatePink,
            unfocusedLabelColor = Color(0xFF8A8FB0),
            cursorColor = GatePink,
            focusedContainerColor = Color(0xFFFFF6FA),
            unfocusedContainerColor = Color(0xFFFFFBFD)
        )
    )
}

@Composable
private fun GateError(text: String) {
    Text(
        "😿  $text", Modifier.fillMaxWidth().padding(top = 8.dp).clip(RoundedCornerShape(14.dp))
            .background(Color(0xFFFFEEF2)).padding(horizontal = 12.dp, vertical = 8.dp),
        color = GateError, fontSize = 12.sp, fontWeight = FontWeight.Bold
    )
}

/** Nút hồng mập giống các màn khác; khi chưa đủ điều kiện thì mờ đi. */
@Composable
private fun GatePrimaryButton(label: String, enabled: Boolean, sfx: GateSfx?, onClick: () -> Unit) {
    val source = remember { MutableInteractionSource() }
    val shape = RoundedCornerShape(26.dp)
    Box(
        Modifier.fillMaxWidth().pressScale(source, pressedScale = .96f)
            .shadow(if (enabled) 8.dp else 0.dp, shape).clip(shape)
            .background(
                if (enabled) Brush.verticalGradient(listOf(Color(0xFFFF9CC4), Color(0xFFFF4B8D)))
                else Brush.verticalGradient(listOf(Color(0xFFFFDDEA), Color(0xFFFFC9DE)))
            )
            .border(2.5.dp, Color.White, shape)
            .clickable(enabled = enabled, interactionSource = source, indication = null) { sfx?.tap(); onClick() }
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) { Text(label, color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp) }
}

@Composable
private fun GateTextAction(label: String, sfx: GateSfx?, onClick: () -> Unit) {
    Text(
        label,
        Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp))
            .clickable { sfx?.tap(); onClick() }.padding(vertical = 12.dp),
        color = GatePink, fontSize = 13.sp, fontWeight = FontWeight.ExtraBold, textAlign = TextAlign.Center
    )
}

/* ───────────── Màn hình ───────────── */

@Composable
fun ParentGatePinScreen(
    onBack: () -> Unit,
    onVerify: (String) -> Unit,
    onSetupPin: () -> Unit,
    onChangePin: () -> Unit,
    lockedSeconds: Int? = null,
    error: String? = null
) {
    var pin by remember { mutableStateOf("") }
    val locked = (lockedSeconds ?: 0) > 0
    val sfx = rememberGateSfx()
    GatePage(
        title = if (locked) "Tạm khóa xác minh" else "Khu vực phụ huynh",
        subtitle = if (locked) "Mimi sẽ cho thử lại sau ${lockedSeconds}s. Hãy kiểm tra với ba mẹ nhé." else "Ba mẹ nhập PIN để xem thông tin gia đình và quản lý gói học.",
        onBack = onBack,
        badge = if (locked) "⏳" else "🔒",
        sfx = sfx,
        error = error
    ) {
        GateField(pin, { pin = it }, "PIN phụ huynh")
        if (!error.isNullOrBlank()) GateError(error)
        Spacer(Modifier.height(14.dp))
        GatePrimaryButton(if (locked) "Đang tạm khóa" else "Xác minh", pin.isNotBlank() && !locked, sfx) { onVerify(pin) }
        Spacer(Modifier.height(4.dp))
        GateTextAction("Chưa có PIN? Thiết lập", sfx) { onSetupPin() }
        GateTextAction("Đổi PIN phụ huynh", sfx) { onChangePin() }
    }
}

@Composable
fun ParentGateSetupScreen(onBack: () -> Unit, onSubmit: (password: String, pin: String, confirmation: String) -> Unit, error: String? = null) {
    var password by remember { mutableStateOf("") }
    var pin by remember { mutableStateOf("") }
    var confirmation by remember { mutableStateOf("") }
    val mismatch = confirmation.isNotBlank() && pin != confirmation
    val sfx = rememberGateSfx()
    GatePage(
        "Thiết lập PIN phụ huynh", "Xác nhận mật khẩu tài khoản, sau đó tạo và xác nhận PIN.", onBack,
        mimi = R.drawable.mimi_happy, badge = "🛡️", sfx = sfx, error = error
    ) {
        GateField(password, { password = it }, "Mật khẩu tài khoản", emoji = "🔐", keyboardType = KeyboardType.Password)
        Spacer(Modifier.height(10.dp))
        GateField(pin, { pin = it }, "Tạo PIN")
        Spacer(Modifier.height(10.dp))
        GateField(confirmation, { confirmation = it }, "Nhập lại PIN", emoji = "✅")
        if (mismatch) GateError("Hai lần nhập PIN chưa khớp.")
        if (!error.isNullOrBlank()) GateError(error)
        Spacer(Modifier.height(14.dp))
        GatePrimaryButton("Tạo PIN", password.isNotBlank() && pin.isNotBlank() && pin == confirmation, sfx) { onSubmit(password, pin, confirmation) }
        Text(
            "PIN chỉ được xác minh ở backend; ứng dụng không lưu PIN.",
            Modifier.fillMaxWidth().padding(top = 12.dp), color = Color(0xFF8991A8), fontSize = 11.sp, textAlign = TextAlign.Center
        )
    }
}

@Composable
fun ParentGateChangeScreen(onBack: () -> Unit, onSubmit: (oldPin: String, newPin: String, confirmation: String) -> Unit, error: String? = null) {
    var oldPin by remember { mutableStateOf("") }
    var newPin by remember { mutableStateOf("") }
    var confirmation by remember { mutableStateOf("") }
    val mismatch = confirmation.isNotBlank() && newPin != confirmation
    val sfx = rememberGateSfx()
    GatePage(
        "Đổi PIN phụ huynh", "Nhập PIN hiện tại và đặt PIN mới cho khu vực phụ huynh.", onBack,
        mimi = R.drawable.mimi_happy, badge = "🔄", sfx = sfx, error = error
    ) {
        GateField(oldPin, { oldPin = it }, "PIN hiện tại")
        Spacer(Modifier.height(10.dp))
        GateField(newPin, { newPin = it }, "PIN mới", emoji = "✨")
        Spacer(Modifier.height(10.dp))
        GateField(confirmation, { confirmation = it }, "Nhập lại PIN mới", emoji = "✅")
        if (mismatch) GateError("Hai lần nhập PIN mới chưa khớp.")
        if (!error.isNullOrBlank()) GateError(error)
        Spacer(Modifier.height(14.dp))
        GatePrimaryButton("Cập nhật PIN", oldPin.isNotBlank() && newPin.isNotBlank() && newPin == confirmation, sfx) { onSubmit(oldPin, newPin, confirmation) }
    }
}

@Preview(showBackground = true, showSystemUi = true, name = "Parent Gate · Nhập PIN")
@Composable
fun ParentGatePinPreview() { MimiGoTheme { ParentGatePinScreen({}, {}, {}, {}) } }

@Preview(showBackground = true, showSystemUi = true, name = "Parent Gate · Thiết lập PIN")
@Composable
fun ParentGateSetupPreview() { MimiGoTheme { ParentGateSetupScreen({}, { _, _, _ -> }) } }

@Preview(showBackground = true, showSystemUi = true, name = "Parent Gate · Đổi PIN")
@Composable
fun ParentGateChangePreview() { MimiGoTheme { ParentGateChangeScreen({}, { _, _, _ -> }) } }

@Preview(showBackground = true, showSystemUi = true, name = "Parent Gate · Tạm khóa")
@Composable
fun ParentGateLockedPreview() { MimiGoTheme { ParentGatePinScreen({}, {}, {}, {}, lockedSeconds = 45) } }

@Preview(showBackground = true, showSystemUi = true, name = "Parent Gate · Sai PIN")
@Composable
fun ParentGateErrorPreview() { MimiGoTheme { ParentGatePinScreen({}, {}, {}, {}, error = "PIN chưa đúng, ba mẹ thử lại nhé.") } }