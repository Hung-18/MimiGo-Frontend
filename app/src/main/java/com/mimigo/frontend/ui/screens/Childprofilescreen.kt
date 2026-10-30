package com.mimigo.frontend.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.imePadding
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
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Female
import androidx.compose.material.icons.filled.Male
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material3.Icon
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import android.app.DatePickerDialog
import java.time.LocalDate
import com.mimigo.frontend.R
import com.mimigo.frontend.ui.components.BackgroundDecor
import com.mimigo.frontend.ui.components.pressScale
import com.mimigo.frontend.ui.theme.MimiBlue
import com.mimigo.frontend.ui.theme.MimiGoTheme
import com.mimigo.frontend.ui.theme.MimiNavyText
import com.mimigo.frontend.ui.theme.MimiPink
import com.mimigo.frontend.ui.theme.TextSecondary
import com.mimigo.frontend.ui.theme.TextSubtle
import kotlinx.coroutines.delay

// ---------------------------------------------------------------------------
// Dữ liệu hồ sơ của bé (sau này gửi lên API)
// ---------------------------------------------------------------------------
enum class ChildGender(val label: String) { Girl("Bé gái"), Boy("Bé trai") }

/** 4 avatar để chọn: 2 bé gái, 2 bé trai. */
enum class ChildAvatar(val gender: ChildGender) {
    Girl1(ChildGender.Girl),
    Girl2(ChildGender.Girl),
    Boy1(ChildGender.Boy),
    Boy2(ChildGender.Boy)
}

data class ChildProfile(
    val name: String,
    val nickname: String,
    val age: Int,
    val dateOfBirth: String,
    val gender: ChildGender,
    val avatar: ChildAvatar
)

private val ErrorRed = Color(0xFFE53935)
private val FieldBorder = Color(0xFFE3E8F0)
private val GirlColor = Color(0xFFFF4F9A)
private val BoyColor = Color(0xFF2F80ED)

private fun ChildAvatar.drawable() = when (this) {
    ChildAvatar.Girl1 -> R.drawable.avatar_girl
    ChildAvatar.Girl2 -> R.drawable.avatar_girl_2
    ChildAvatar.Boy1 -> R.drawable.avatar_boy
    ChildAvatar.Boy2 -> R.drawable.avatar_boy_2
}

private fun ChildGender.defaultAvatar() =
    if (this == ChildGender.Girl) ChildAvatar.Girl1 else ChildAvatar.Boy1

/** Gợi ý nội dung học theo độ tuổi, hiện ngay dưới ô chọn tuổi. */
private fun ageHint(age: Int?): String = when (age) {
    null -> "Chọn tuổi để Mimi chuẩn bị bài học phù hợp cho bé nhé!"
    2 -> "Bé 2 tuổi · Khám phá màu sắc, âm thanh và các con vật quen thuộc"
    3 -> "Bé 3 tuổi · Làm quen chữ cái, số đếm 1–10 và bài hát vui nhộn"
    4 -> "Bé 4 tuổi · Ghép vần đầu tiên, đếm số và nghe kể chuyện"
    5 -> "Bé 5 tuổi · Tập đọc chữ, phép cộng đơn giản, chuẩn bị vào lớp 1"
    else -> "Bé 6 tuổi · Đánh vần, tính toán và khám phá thế giới xung quanh"
}

/**
 * Màn hình "Thông tin của bé": tạo hồ sơ học tập cho bé sau khi xác nhận tài khoản phụ huynh.
 *
 * @param isLoading đang gọi server (khóa nút trong pop-up xác nhận)
 * @param serverError lỗi từ server, hiện trong pop-up xác nhận
 * @param onSubmit được gọi khi phụ huynh bấm "Xác nhận" trong pop-up
 * @param onSkip bấm "Bỏ qua, hoàn tất sau" -> vào trang chủ luôn
 */
@Composable
fun ChildProfileScreen(
    isLoading: Boolean = false,
    serverError: String? = null,
    onSubmit: (ChildProfile) -> Unit = {},
    onSkip: () -> Unit = {},
    requiredNotices: List<String> = emptyList(),
    modifier: Modifier = Modifier
) {
    var name by remember { mutableStateOf("") }
    var nickname by remember { mutableStateOf("") }
    var age by remember { mutableStateOf<Int?>(null) }
    var dateOfBirth by remember { mutableStateOf<LocalDate?>(null) }
    val context = LocalContext.current
    var gender by remember { mutableStateOf<ChildGender?>(null) }
    var avatar by remember { mutableStateOf<ChildAvatar?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showConfirm by remember { mutableStateOf(false) }
    var noticesConfirmed by remember(requiredNotices) { mutableStateOf(false) }

    var contentVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(350)
        contentVisible = true
    }

    // Chọn avatar hoặc giới tính -> tự điền ô còn lại nếu chưa chọn (vẫn đổi riêng được)
    fun pickAvatar(value: ChildAvatar) {
        avatar = value
        if (gender == null) gender = value.gender
        errorMessage = null
    }

    fun pickGender(value: ChildGender) {
        gender = value
        if (avatar == null) avatar = value.defaultAvatar()
        errorMessage = null
    }

    fun validateAndAsk() {
        errorMessage = when {
            name.isBlank() -> "Vui lòng nhập họ và tên của bé"
            dateOfBirth == null -> "Vui lòng chọn ngày sinh chính xác của bé"
            gender == null -> "Vui lòng chọn giới tính của bé"
            requiredNotices.isNotEmpty() && !noticesConfirmed -> "Vui lòng xác nhận các mục thông báo bắt buộc"
            else -> null
        }
        if (errorMessage == null) showConfirm = true
    }

    BackgroundDecor(
        modifier = modifier,
        backgroundRes = R.drawable.child_profile_bg
    ) {
        // Bố cục vừa khít một màn hình: thanh tiến trình ở trên, form ở dưới, con ong ở giữa
        var screenMinHeight by remember { mutableStateOf(0.dp) }
        val density = LocalDensity.current
        Box(
            modifier = Modifier
                .fillMaxSize()
                .systemBarsPadding()
                .imePadding()
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
                    StepProgress(total = 4, current = 3)

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
                                .background(Color.White.copy(alpha = 0.95f))
                                .padding(horizontal = 14.dp, vertical = 14.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Thông tin của bé",
                                color = MimiBlue,
                                fontSize = 22.sp,
                                fontWeight = FontWeight.ExtraBold
                            )
                            Text(
                                text = "Nhập thông tin để tạo hồ sơ học tập cho bé nhé!",
                                color = TextSecondary,
                                fontSize = 12.sp,
                                textAlign = TextAlign.Center
                            )

                            Spacer(modifier = Modifier.height(10.dp))

                            // Ảnh đại diện: 4 lựa chọn (2 bé gái, 2 bé trai)
                            FormRow(label = "Ảnh đại diện", subLabel = "của bé") {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    ChildAvatar.entries.forEach { option ->
                                        AvatarOption(
                                            avatar = option,
                                            selected = avatar == option,
                                            onClick = { pickAvatar(option) }
                                        )
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            FormRow(label = "Họ và tên bé") {
                                ChildField(
                                    value = name,
                                    onValueChange = {
                                        name = it.take(40)
                                        errorMessage = null
                                    },
                                    placeholder = "Nhập họ và tên của bé",
                                    icon = Icons.Filled.Person,
                                    iconTint = MimiBlue
                                )
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            FormRow(label = "Biệt danh", subLabel = "ở nhà (tùy chọn)") {
                                ChildField(
                                    value = nickname,
                                    onValueChange = { nickname = it.take(20) },
                                    placeholder = "Ví dụ: Suri, Bống...",
                                    icon = Icons.Filled.StarBorder,
                                    iconTint = MimiBlue
                                )
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            FormRow(label = "Ngày sinh của bé", subLabel = "(dùng để chọn nội dung phù hợp)") {
                                val today = LocalDate.now()
                                val selected = dateOfBirth
                                val birthYear = selected?.year ?: today.minusYears(3).year
                                val birthMonth = (selected?.monthValue ?: today.monthValue) - 1
                                val birthDay = selected?.dayOfMonth ?: today.dayOfMonth
                                OutlineActionButton(
                                    text = selected?.toString() ?: "Chọn ngày sinh",
                                    onClick = {
                                        DatePickerDialog(context, { _, year, month, day ->
                                            val selectedDate = LocalDate.of(year, month + 1, day)
                                            dateOfBirth = selectedDate
                                            age = java.time.Period.between(selectedDate, LocalDate.now()).years
                                            errorMessage = null
                                        }, birthYear, birthMonth, birthDay).apply {
                                            datePicker.maxDate = System.currentTimeMillis()
                                            show()
                                        }
                                    }
                                )
                            }
                            dateOfBirth?.let { AgeHint(age = java.time.Period.between(it, LocalDate.now()).years) }

                            if (requiredNotices.isNotEmpty()) {
                                Spacer(modifier = Modifier.height(8.dp))
                                Column(
                                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                                        .background(Color(0xFFF3F8FF)).padding(10.dp)
                                ) {
                                    Text("Thông báo về dữ liệu của bé", color = MimiNavyText, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                    requiredNotices.forEach { notice ->
                                        Text(notice, color = TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp))
                                    }
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Checkbox(
                                            checked = noticesConfirmed,
                                            onCheckedChange = { noticesConfirmed = it },
                                            colors = CheckboxDefaults.colors(checkedColor = MimiPink)
                                        )
                                        Text("Tôi xác nhận các mục đích xử lý dữ liệu trên.", color = MimiNavyText, fontSize = 12.sp)
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            FormRow(label = "Giới tính") {
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    GenderButton(
                                        modifier = Modifier.weight(1f),
                                        text = ChildGender.Girl.label,
                                        icon = Icons.Filled.Female,
                                        accent = GirlColor,
                                        selected = gender == ChildGender.Girl,
                                        onClick = { pickGender(ChildGender.Girl) }
                                    )
                                    GenderButton(
                                        modifier = Modifier.weight(1f),
                                        text = ChildGender.Boy.label,
                                        icon = Icons.Filled.Male,
                                        accent = BoyColor,
                                        selected = gender == ChildGender.Boy,
                                        onClick = { pickGender(ChildGender.Boy) }
                                    )
                                }
                            }

                            errorMessage?.let {
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
                                text = "Tạo hồ sơ cho bé này",
                                onClick = { validateAndAsk() }
                            )

                            Spacer(modifier = Modifier.height(8.dp))

                            OutlineActionButton(
                                text = "Bỏ qua, hoàn tất sau",
                                onClick = onSkip
                            )
                        }
                    }
                }
            }
        }

        // Pop-up hỏi lại trước khi tạo hồ sơ
        if (showConfirm) {
            val chosenGender = gender ?: ChildGender.Girl
            ConfirmProfileDialog(
                profile = ChildProfile(
                    name = name.trim(),
                    nickname = nickname.trim(),
                    age = age ?: 3,
                    dateOfBirth = dateOfBirth?.toString().orEmpty(),
                    gender = chosenGender,
                    avatar = avatar ?: chosenGender.defaultAvatar()
                ),
                isLoading = isLoading,
                serverError = serverError,
                onConfirm = { profile -> onSubmit(profile) },
                onDismiss = { showConfirm = false }
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Các thành phần giao diện
// ---------------------------------------------------------------------------

/** Thanh tiến trình các bước đăng ký: bước đã xong có dấu tick, bước hiện tại to hơn. */
@Composable
private fun StepProgress(total: Int, current: Int) {
    Row(
        modifier = Modifier.padding(top = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        for (step in 1..total) {
            val done = step < current
            val active = step == current
            Box(
                modifier = Modifier
                    .size(if (active) 24.dp else 20.dp)
                    .clip(CircleShape)
                    .background(
                        when {
                            done || active -> MimiPink
                            else -> Color.White.copy(alpha = 0.9f)
                        }
                    )
                    .border(2.dp, Color.White, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                if (done) {
                    Icon(
                        imageVector = Icons.Filled.Check,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(12.dp)
                    )
                }
            }
            if (step < total) {
                Box(
                    modifier = Modifier
                        .width(34.dp)
                        .height(3.dp)
                        .clip(CircleShape)
                        .background(if (done) MimiPink else Color.White.copy(alpha = 0.85f))
                )
            }
        }
    }
}

/** Một hàng của form: nhãn bên trái, ô nhập/lựa chọn bên phải. */
@Composable
private fun FormRow(
    label: String,
    subLabel: String? = null,
    content: @Composable () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.width(80.dp)) {
            Text(
                text = label,
                color = MimiNavyText,
                fontSize = 12.5.sp,
                fontWeight = FontWeight.ExtraBold,
                lineHeight = 15.sp
            )
            subLabel?.let {
                Text(
                    text = it,
                    color = TextSubtle,
                    fontSize = 10.5.sp,
                    lineHeight = 13.sp
                )
            }
        }
        Spacer(modifier = Modifier.width(6.dp))
        Box(modifier = Modifier.weight(1f)) { content() }
    }
}

/** Ô nhập chữ gọn (cao 46dp) để cả form vừa một màn hình. */
@Composable
private fun ChildField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    icon: ImageVector,
    iconTint: Color
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(46.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White)
            .border(1.dp, FieldBorder, RoundedCornerShape(14.dp))
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(20.dp))
        Spacer(modifier = Modifier.width(8.dp))
        Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
            if (value.isEmpty()) {
                Text(
                    text = placeholder,
                    color = TextSubtle,
                    fontSize = 13.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                singleLine = true,
                textStyle = TextStyle(color = MimiNavyText, fontSize = 14.sp),
                cursorBrush = SolidColor(MimiPink),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

/** Avatar tròn có thể chọn: viền hồng + dấu tick khi được chọn. */
@Composable
private fun AvatarOption(
    avatar: ChildAvatar,
    selected: Boolean,
    onClick: () -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    val borderColor by animateColorAsState(
        targetValue = if (selected) MimiPink else FieldBorder,
        label = "avatar_border"
    )
    Box(modifier = Modifier.pressScale(interactionSource, pressedScale = 0.9f)) {
        Image(
            painter = painterResource(avatar.drawable()),
            contentDescription = if (avatar.gender == ChildGender.Girl) "Avatar bé gái" else "Avatar bé trai",
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .size(46.dp)
                .clip(CircleShape)
                .border(if (selected) 3.dp else 1.dp, borderColor, CircleShape)
                .clickable(
                    interactionSource = interactionSource,
                    indication = ripple(),
                    onClick = onClick
                )
        )
        if (selected) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .size(18.dp)
                    .clip(CircleShape)
                    .background(MimiPink)
                    .border(1.5.dp, Color.White, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(11.dp)
                )
            }
        }
    }
}

/** Khung gợi ý đổi nội dung (hiệu ứng mờ dần) mỗi khi chọn tuổi khác. */
@Composable
private fun AgeHint(age: Int?) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 36.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFFFFF3F8))
            .padding(horizontal = 10.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        AnimatedContent(
            targetState = age,
            transitionSpec = { fadeIn(tween(250)) togetherWith fadeOut(tween(150)) },
            label = "age_hint"
        ) { value ->
            Text(
                text = ageHint(value),
                color = if (value == null) TextSubtle else MimiNavyText,
                fontSize = 11.5.sp,
                lineHeight = 15.sp,
                fontWeight = if (value == null) FontWeight.Normal else FontWeight.Medium,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun GenderButton(
    text: String,
    icon: ImageVector,
    accent: Color,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val interactionSource = remember { MutableInteractionSource() }
    val borderColor by animateColorAsState(
        targetValue = if (selected) accent else Color.Transparent,
        label = "gender_border"
    )
    Row(
        modifier = modifier
            .pressScale(interactionSource)
            .height(44.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(accent.copy(alpha = if (selected) 0.14f else 0.07f))
            .border(1.5.dp, borderColor, RoundedCornerShape(14.dp))
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(),
                onClick = onClick
            ),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        Icon(icon, contentDescription = null, tint = accent, modifier = Modifier.size(20.dp))
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = text,
            color = accent,
            fontSize = 14.sp,
            fontWeight = FontWeight.ExtraBold
        )
    }
}

/** Nút phụ: nền trắng, viền hồng. */
@Composable
internal fun OutlineActionButton(
    text: String,
    onClick: () -> Unit,
    enabled: Boolean = true,
    modifier: Modifier = Modifier
) {
    val interactionSource = remember { MutableInteractionSource() }
    Box(
        modifier = modifier
            .pressScale(interactionSource)
            .fillMaxWidth()
            .height(46.dp)
            .clip(CircleShape)
            .background(Color.White)
            .border(1.5.dp, if (enabled) MimiPink else FieldBorder, CircleShape)
            .clickable(
                enabled = enabled,
                interactionSource = interactionSource,
                indication = ripple(),
                onClick = onClick
            ),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            color = if (enabled) MimiPink else TextSubtle,
            fontSize = 15.sp,
            fontWeight = FontWeight.ExtraBold
        )
    }
}

/** Pop-up hỏi lại thông tin trước khi tạo hồ sơ. */
@Composable
private fun ConfirmProfileDialog(
    profile: ChildProfile,
    isLoading: Boolean,
    serverError: String?,
    onConfirm: (ChildProfile) -> Unit,
    onDismiss: () -> Unit
) {
    Dialog(
        onDismissRequest = { if (!isLoading) onDismiss() },
        properties = DialogProperties(
            dismissOnBackPress = !isLoading,
            dismissOnClickOutside = false
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .shadow(12.dp, RoundedCornerShape(28.dp))
                .clip(RoundedCornerShape(28.dp))
                .background(Color.White)
                .padding(horizontal = 20.dp, vertical = 22.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Image(
                painter = painterResource(profile.avatar.drawable()),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(84.dp)
                    .clip(CircleShape)
                    .border(3.dp, MimiPink, CircleShape)
            )
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = "Tạo hồ sơ cho bé này?",
                color = MimiBlue,
                fontSize = 20.sp,
                fontWeight = FontWeight.ExtraBold,
                textAlign = TextAlign.Center
            )
            Spacer(modifier = Modifier.height(10.dp))

            // Tóm tắt thông tin vừa nhập
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color(0xFFF4F8FF))
                    .padding(12.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = profile.name,
                    color = MimiNavyText,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.ExtraBold,
                    textAlign = TextAlign.Center
                )
                if (profile.nickname.isNotBlank()) {
                    Text(
                        text = "Biệt danh: ${profile.nickname}",
                        color = TextSecondary,
                        fontSize = 13.sp
                    )
                }
                Text(
                    text = "${profile.age} tuổi · ${profile.gender.label}",
                    color = MimiPink,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Bạn có thể chỉnh sửa thông tin này sau trong phần Hồ sơ của bé.",
                color = TextSubtle,
                fontSize = 11.5.sp,
                textAlign = TextAlign.Center,
                lineHeight = 15.sp
            )

            serverError?.let {
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = it,
                    color = ErrorRed,
                    fontSize = 12.5.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            CreateAccountButton(
                text = "Xác nhận",
                isLoading = isLoading,
                onClick = { onConfirm(profile) }
            )
            Spacer(modifier = Modifier.height(8.dp))
            OutlineActionButton(
                text = "Kiểm tra lại",
                enabled = !isLoading,
                onClick = onDismiss
            )
        }
    }
}

@Preview(showBackground = true, showSystemUi = true, device = "id:pixel_7")
@Composable
fun ChildProfileScreenPreview() {
    MimiGoTheme {
        ChildProfileScreen()
    }
}
