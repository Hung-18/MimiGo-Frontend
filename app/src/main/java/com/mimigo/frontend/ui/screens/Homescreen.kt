package com.mimigo.frontend.ui.screens

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Calculate
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mimigo.frontend.R
import com.mimigo.frontend.data.MimiGoApi
import com.mimigo.frontend.ui.components.pressScale
import com.mimigo.frontend.ui.theme.MimiGoTheme
import org.json.JSONArray
import org.json.JSONObject

private val Pink = Color(0xFFEF4E91)
private val PinkLight = Color(0xFFFF8DBB)
private val Navy = Color(0xFF3B3A7A)
private val SoftBg = Color(0xFFFFF6FA)

data class ChildHomeProfile(
    val id: String,
    val name: String,
    val ageYears: Int? = null,
    val avatarKey: String? = null
)

@Composable
fun HomeScreen(
    childId: String = "",
    childName: String? = null,
    children: List<ChildHomeProfile> = emptyList(),
    onChildSelect: (ChildHomeProfile) -> Unit = {},
    onAddChildClick: () -> Unit = {},
    onLessonClick: (String) -> Unit = {},
    onNotificationsClick: () -> Unit = {},
    onSettingsClick: () -> Unit = {},
    api: MimiGoApi? = null,
    lessonsOnly: Boolean = false,
    modifier: Modifier = Modifier
) {
    var lessons by remember(childId) { mutableStateOf(JSONArray()) }
    var loading by remember(childId) { mutableStateOf(false) }
    var error by remember(childId) { mutableStateOf<String?>(null) }
    var selectedDomain by remember(childId) { mutableStateOf("ALL") }
    var selectedTopic by remember(childId) { mutableStateOf("ALL") }
    var curriculum by remember(childId) { mutableStateOf(JSONObject()) }
    var profileMenuExpanded by remember(childId) { mutableStateOf(false) }
    var premiumLessonTitle by remember { mutableStateOf<String?>(null) }
    fun openLesson(lesson: JSONObject) {
        if (lesson.optString("access").equals("CORE", ignoreCase = true)) premiumLessonTitle = lesson.optString("title", "Bài học Premium")
        else onLessonClick(lesson.optString("lessonId"))
    }
    LaunchedEffect(childId, api) {
        if (api != null && childId.isNotBlank()) {
            try { curriculum = api.curriculum(childId) }
            catch (e: Exception) { error = e.message ?: "Không tải được chương trình học." }
        }
    }

    LaunchedEffect(childId, api, selectedDomain, selectedTopic) {
        if (api != null && childId.isNotBlank()) {
            loading = true
            error = null
            try {
                lessons = api.lessons(
                    childId,
                    selectedDomain.takeIf { it != "ALL" },
                    selectedTopic.takeIf { it != "ALL" }
                ).optJSONArray("items") ?: JSONArray()
            } catch (e: Exception) { error = e.message ?: "Không tải được bài học theo bộ lọc." }
            finally { loading = false }
        }
    }

    val curriculumDomains = remember(curriculum) { curriculum.optJSONArray("domains") ?: JSONArray() }
    val domains = remember(curriculumDomains) {
        buildList {
            add("ALL" to "Tất cả")
            for (i in 0 until curriculumDomains.length()) {
                val code = curriculumDomains.optJSONObject(i)?.optString("domainCode").orEmpty()
                if (code.isNotBlank() && code != "null") add(code to domainTitle(code))
            }
        }
    }
    val selectedDomainItem = remember(curriculumDomains, selectedDomain) {
        (0 until curriculumDomains.length()).mapNotNull { curriculumDomains.optJSONObject(it) }
            .firstOrNull { it.optString("domainCode") == selectedDomain }
    }
    val curriculumTopics = remember(selectedDomainItem) { selectedDomainItem?.optJSONArray("topics") ?: JSONArray() }
    val topics = remember(curriculumTopics) {
        buildList {
            add("ALL" to "Tất cả chủ đề")
            for (i in 0 until curriculumTopics.length()) {
                val code = curriculumTopics.optJSONObject(i)?.optString("topicCode").orEmpty()
                if (code.isNotBlank() && code != "null") add(code to code.replace('_', ' ').lowercase().replaceFirstChar { it.uppercase() })
            }
        }
    }
    val visibleLessons = remember(lessons) { (0 until lessons.length()).mapNotNull { lessons.optJSONObject(it) } }
    val featured = visibleLessons.firstOrNull()
    val activeProfile = children.firstOrNull { it.id == childId }
    val shownName = childName?.takeIf { it.isNotBlank() } ?: "bé"

    Column(modifier = modifier.fillMaxSize().background(SoftBg)) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
            if (!lessonsOnly) WelcomeBanner(
                childName = shownName,
                ageYears = activeProfile?.ageYears,
                onNotificationsClick = onNotificationsClick,
                onSettingsClick = onSettingsClick,
                profileSlot = {
                    Box {
                        ProfilePill(
                            name = shownName,
                            ageYears = activeProfile?.ageYears,
                            avatarKey = activeProfile?.avatarKey,
                            onClick = { profileMenuExpanded = true }
                        )
                        DropdownMenu(
                            expanded = profileMenuExpanded,
                            onDismissRequest = { profileMenuExpanded = false },
                            shape = RoundedCornerShape(22.dp),
                            containerColor = Color.White
                        ) {
                            Text("Chọn hồ sơ của bé", color = Pink, fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp))
                            children.forEach { profile ->
                                DropdownMenuItem(
                                    text = {
                                        Column {
                                            Text(profile.name, color = Navy, fontWeight = if (profile.id == childId) FontWeight.Bold else FontWeight.Medium)
                                            profile.ageYears?.let { Text("$it tuổi", color = Color(0xFF8993AB), fontSize = 11.sp) }
                                        }
                                    },
                                    leadingIcon = { AvatarRing(profile.avatarKey, 36) },
                                    trailingIcon = if (profile.id == childId) ({ Icon(Icons.Filled.Check, null, tint = Pink) }) else null,
                                    onClick = { profileMenuExpanded = false; onChildSelect(profile) }
                                )
                            }
                            DropdownMenuItem(
                                text = { Text("Thêm hồ sơ cho bé", color = Pink, fontWeight = FontWeight.Bold) },
                                leadingIcon = { Icon(Icons.Filled.Add, null, tint = Pink) },
                                onClick = { profileMenuExpanded = false; onAddChildClick() }
                            )
                        }
                    }
                }
            )
            else {
                Text(
                    "📚  Bài học của $shownName",
                    Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 18.dp, vertical = 18.dp),
                    color = Navy, fontSize = 21.sp, fontWeight = FontWeight.ExtraBold
                )
            }

            SectionTitle("Chọn chủ đề", null)
            Row(
                Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 12.dp, vertical = 2.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                domains.forEach { (code, title) ->
                    CategoryChip(title = title, selected = selectedDomain == code) {
                        selectedDomain = code
                        selectedTopic = "ALL"
                    }
                }
            }

            if (selectedDomain != "ALL" && topics.size > 1) {
                Row(
                    Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 12.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    topics.forEach { (code, title) ->
                        CategoryChip(title = title, selected = selectedTopic == code) { selectedTopic = code }
                    }
                }
            }

            if (featured != null) {
                FeaturedLesson(lesson = featured, onClick = { openLesson(featured) })
            }

            SectionTitle("Danh sách bài học", "${visibleLessons.size} bài")

            when {
                loading -> InfoBubble("Mimi đang tìm bài học cho con… 🐝")
                error != null -> Text(error.orEmpty(), Modifier.padding(20.dp), color = MaterialTheme.colorScheme.error)
                visibleLessons.isEmpty() -> InfoBubble("Chưa có bài học phù hợp cho hồ sơ này, Mimi sẽ sớm chuẩn bị thêm nhé!", R.drawable.mimi_sleepy)
                else -> visibleLessons.forEachIndexed { index, lesson ->
                    LessonRow(index + 1, lesson) { openLesson(lesson) }
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
    premiumLessonTitle?.let { title ->
        AlertDialog(
            onDismissRequest = { premiumLessonTitle = null },
            icon = { Image(painterResource(R.drawable.mimi_think), "Ong Mimi", Modifier.size(86.dp)) },
            title = { Text("Bài học Premium 💎", color = Navy, fontWeight = FontWeight.ExtraBold) },
            text = { Text("Bài học ‘$title’ thuộc gói Premium. Ba mẹ cần mua gói phù hợp thì con mới sử dụng được nhé!", color = Color(0xFF66728C), textAlign = TextAlign.Center) },
            confirmButton = { TextButton(onClick = { premiumLessonTitle = null }) { Text("Mimi hiểu rồi 🐝", color = Pink, fontWeight = FontWeight.Bold) } },
            containerColor = Color.White
        )
    }
}

/* ───────────── Banner chào mừng có ong Mimi cầm tim ───────────── */

@Composable
private fun WelcomeBanner(
    childName: String,
    ageYears: Int?,
    onNotificationsClick: () -> Unit,
    onSettingsClick: () -> Unit,
    profileSlot: @Composable () -> Unit
) {
    val bob = rememberInfiniteTransition(label = "mimi-bob")
    val dy by bob.animateFloat(
        initialValue = 0f, targetValue = -10f,
        animationSpec = infiniteRepeatable(tween(1100, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "dy"
    )
    val tilt by bob.animateFloat(
        initialValue = -4f, targetValue = 4f,
        animationSpec = infiniteRepeatable(tween(1500, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "tilt"
    )
    val pulse by bob.animateFloat(
        initialValue = 0.9f, targetValue = 1.15f,
        animationSpec = infiniteRepeatable(tween(700), RepeatMode.Reverse), label = "pulse"
    )

    Box(
        Modifier.fillMaxWidth().height(318.dp)
            .clip(RoundedCornerShape(bottomStart = 36.dp, bottomEnd = 36.dp))
    ) {
        Image(painterResource(R.drawable.family_picnic_bg), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(listOf(Color(0x55FFFFFF), Color(0x22FFE3EF), Color(0xE6FFF0F6)))
            )
        )

        // hồ sơ bé
        Box(Modifier.align(Alignment.TopStart).statusBarsPadding().padding(start = 14.dp, top = 10.dp)) { profileSlot() }

        // quick parent actions
        Row(Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(end = 12.dp, top = 8.dp), horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            HeaderAction("🔔", "Thông báo", listOf(Color(0xFFFFE6A0), Color(0xFFFFB84D)), false, onNotificationsClick)
            HeaderAction("⚙️", "Cài đặt", listOf(Color(0xFFCDE8FF), Color(0xFF7CC4FF)), true, onSettingsClick)
        }

        // logo + slogan
        Column(
            Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(end = 18.dp, top = 62.dp),
            horizontalAlignment = Alignment.End
        ) {
            Text(
                "MimiGo",
                style = TextStyle(
                    fontSize = 30.sp, fontWeight = FontWeight.ExtraBold, color = Pink,
                    shadow = Shadow(Color.White, Offset(0f, 0f), blurRadius = 18f)
                )
            )
            Text(
                "Cùng học tập và khám phá",
                style = TextStyle(
                    fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Navy,
                    shadow = Shadow(Color.White, Offset(0f, 0f), blurRadius = 12f)
                )
            )
        }

        // ong Mimi cầm tim
        Box(Modifier.align(Alignment.BottomEnd).padding(end = 10.dp, bottom = 12.dp)) {
            Image(
                painterResource(R.drawable.mimi_happy), "Ong Mimi cầm trái tim",
                Modifier.size(width = 138.dp, height = 170.dp).graphicsLayer { translationY = dy; rotationZ = tilt },
                contentScale = ContentScale.Fit
            )
            Text(
                "💖", fontSize = 22.sp,
                modifier = Modifier.align(Alignment.TopStart).padding(start = 2.dp, top = 6.dp)
                    .graphicsLayer { scaleX = pulse; scaleY = pulse }
            )
            Text(
                "✨", fontSize = 18.sp,
                modifier = Modifier.align(Alignment.TopEnd).padding(end = 4.dp, top = 22.dp)
                    .graphicsLayer { scaleX = pulse; scaleY = pulse }
            )
        }

        // bong bóng lời chào
        Column(Modifier.align(Alignment.BottomStart).padding(start = 16.dp, bottom = 22.dp).widthIn(max = 210.dp)) {
            val bubble = RoundedCornerShape(24.dp, 24.dp, 24.dp, 6.dp)
            Column(
                Modifier.shadow(8.dp, bubble).clip(bubble).background(Color.White)
                    .border(2.dp, Brush.horizontalGradient(listOf(PinkLight, Color(0xFFFFC857))), bubble)
                    .padding(horizontal = 14.dp, vertical = 12.dp)
            ) {
                Text("Chào $childName! 👋", color = Pink, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(3.dp))
                Text(
                    "Mimi rất vui được học cùng con. Hôm nay mình chơi gì nhé?",
                    color = Navy, fontSize = 12.sp, lineHeight = 16.sp, fontWeight = FontWeight.Medium
                )
            }
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                ageYears?.let { SoftTag("🎂 $it tuổi") }
                SoftTag("⭐ Bé ngoan")
            }
        }
    }
}

/** Nút tròn bóng bẩy: chuông lắc nhẹ, bánh răng xoay chậm. */
@Composable
private fun HeaderAction(emoji: String, label: String, colors: List<Color>, spin: Boolean, onClick: () -> Unit) {
    val source = remember { MutableInteractionSource() }
    val t = rememberInfiniteTransition(label = "hdr-$label")
    val angle by t.animateFloat(
        initialValue = 0f, targetValue = if (spin) 360f else 0f,
        animationSpec = infiniteRepeatable(
            if (spin) tween<Float>(14000, easing = LinearEasing)
            else keyframes<Float> {
                durationMillis = 3200
                0f at 0; 16f at 120; -14f at 240; 10f at 360; -6f at 480; 0f at 600
            },
            RepeatMode.Restart
        ),
        label = "angle"
    )
    Box(
        Modifier.pressScale(source, pressedScale = .86f)
            .size(46.dp).shadow(8.dp, CircleShape).clip(CircleShape)
            .background(Brush.verticalGradient(colors))
            .border(2.5.dp, Color.White, CircleShape)
            .semantics { contentDescription = label }
            .clickable(interactionSource = source, indication = null, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Box(
            Modifier.align(Alignment.TopCenter).padding(top = 4.dp).size(width = 24.dp, height = 9.dp)
                .clip(CircleShape).background(Color.White.copy(alpha = .38f))
        )
        Text(emoji, fontSize = 22.sp, modifier = Modifier.graphicsLayer { rotationZ = angle })
    }
}

@Composable
private fun SoftTag(text: String) {
    Text(
        text, color = Navy, fontSize = 10.sp, fontWeight = FontWeight.Bold,
        modifier = Modifier.clip(CircleShape).background(Color.White.copy(alpha = .9f))
            .padding(horizontal = 9.dp, vertical = 4.dp)
    )
}

@Composable
private fun ProfilePill(name: String, ageYears: Int?, avatarKey: String?, onClick: () -> Unit) {
    val source = remember { MutableInteractionSource() }
    Row(
        Modifier.pressScale(source, pressedScale = .95f)
            .shadow(8.dp, CircleShape).clip(CircleShape)
            .background(Brush.horizontalGradient(listOf(Color.White, Color(0xFFFFEAF3))))
            .border(2.dp, Brush.horizontalGradient(listOf(PinkLight, Color(0xFFFFC857))), CircleShape)
            .clickable(interactionSource = source, indication = null, onClick = onClick)
            .padding(start = 4.dp, end = 8.dp, top = 4.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AvatarRing(avatarKey, 50)
        Column(Modifier.padding(start = 8.dp).widthIn(max = 100.dp)) {
            Text(name, color = Pink, fontSize = 15.sp, fontWeight = FontWeight.ExtraBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(
                ageYears?.let { "🎂 $it tuổi" } ?: "Đổi hồ sơ", color = Navy, fontSize = 10.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 2.dp).clip(CircleShape).background(Color(0xFFFFE3EF)).padding(horizontal = 7.dp, vertical = 1.dp)
            )
        }
        Box(
            Modifier.padding(start = 6.dp).size(26.dp).clip(CircleShape)
                .background(Brush.verticalGradient(listOf(Color(0xFFFF9CC4), Color(0xFFFF4B8D))))
                .border(1.5.dp, Color.White, CircleShape),
            contentAlignment = Alignment.Center
        ) { Icon(Icons.Filled.ExpandMore, "Đổi hồ sơ bé", tint = Color.White, modifier = Modifier.size(19.dp)) }
    }
}

@Composable
private fun AvatarRing(key: String?, size: Int) {
    Image(
        painterResource(profileAvatar(key)), "Ảnh đại diện",
        Modifier.size(size.dp)
            .border(3.dp, Brush.linearGradient(listOf(PinkLight, Color(0xFFFFC857), Color(0xFF8EC5FF))), CircleShape)
            .padding(3.dp).clip(CircleShape).background(Color(0xFFFFE7F0)),
        contentScale = ContentScale.Crop
    )
}

/* ───────────── Thành phần dùng chung ───────────── */

@Composable
private fun SectionTitle(title: String, trailing: String?) {
    Row(
        Modifier.fillMaxWidth().padding(start = 18.dp, end = 18.dp, top = 16.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(width = 6.dp, height = 20.dp).clip(CircleShape).background(Brush.verticalGradient(listOf(PinkLight, Pink))))
            Text(title, Modifier.padding(start = 8.dp), color = Navy, fontSize = 17.sp, fontWeight = FontWeight.ExtraBold)
        }
        trailing?.let {
            Text(
                it, color = Pink, fontSize = 11.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.clip(CircleShape).background(Color(0xFFFFE3EF)).padding(horizontal = 10.dp, vertical = 4.dp)
            )
        }
    }
}

@Composable
private fun InfoBubble(text: String, mimi: Int = R.drawable.mimi_think) {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(24.dp)).background(Color.White)
            .border(2.dp, Color(0xFFFFE3EF), RoundedCornerShape(24.dp)).padding(18.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Image(painterResource(mimi), null, Modifier.size(110.dp), contentScale = ContentScale.Fit)
        Text(text, color = Color(0xFF78839B), fontSize = 13.sp, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 6.dp))
    }
}

/** Nút hồng tròn mập, bóng nổi, nhấn lún xuống – dùng cho "Học ngay". */
@Composable
private fun CuteButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val source = remember { MutableInteractionSource() }
    Row(
        modifier.pressScale(source, pressedScale = .92f)
            .shadow(8.dp, CircleShape)
            .clip(CircleShape)
            .background(Brush.verticalGradient(listOf(Color(0xFFFF9CC4), Color(0xFFFF4B8D))))
            .border(2.5.dp, Color.White, CircleShape)
            .clickable(interactionSource = source, indication = null, onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text, color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
        Icon(Icons.Filled.ArrowForward, null, tint = Color.White, modifier = Modifier.padding(start = 6.dp).size(16.dp))
    }
}

@Composable
private fun FeaturedLesson(lesson: JSONObject, onClick: () -> Unit) {
    val shape = RoundedCornerShape(28.dp)
    Box(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp)
            .shadow(10.dp, shape).clip(shape).border(3.dp, Color.White, shape)
            .clickable(onClick = onClick)
    ) {
        Box(Modifier.fillMaxWidth().height(170.dp)) {
            Image(painterResource(R.drawable.family_picnic_bg), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            Box(Modifier.fillMaxSize().background(Brush.horizontalGradient(listOf(Color(0xF2FF5C9A), Color(0xCCB86BFF), Color(0x33B86BFF)))))
            Column(Modifier.align(Alignment.CenterStart).fillMaxWidth(0.68f).padding(start = 16.dp, top = 12.dp, bottom = 12.dp)) {
                Text(
                    "⭐ Gợi ý hôm nay · ${domainTitle(lesson.optString("domainCode"))}", color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold,
                    modifier = Modifier.clip(CircleShape).background(Color.White.copy(alpha = .25f)).padding(horizontal = 9.dp, vertical = 3.dp)
                )
                Spacer(Modifier.height(7.dp))
                Text(lesson.optString("title", "Bài học cho bé"), color = Color.White, fontSize = 20.sp, lineHeight = 24.sp, fontWeight = FontWeight.ExtraBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Text(lesson.stringOrNull("objective").orEmpty(), color = Color.White.copy(alpha = .92f), fontSize = 11.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(10.dp))
                CuteButton("Học ngay", onClick)
            }
            Image(
                painterResource(R.drawable.mimi_cheer), null,
                Modifier.align(Alignment.BottomEnd).padding(end = 6.dp, bottom = 4.dp).size(96.dp)
            )
        }
    }
}

private fun JSONObject.stringOrNull(key: String): String? =
    if (isNull(key)) null else optString(key).takeIf { it.isNotBlank() }

private fun profileAvatar(key: String?): Int = when (key?.uppercase()) {
    "GIRL", "GIRL_1", "AVATAR_GIRL" -> R.drawable.avatar_girl
    "GIRL_2", "AVATAR_GIRL_2" -> R.drawable.avatar_girl_2
    "BOY", "BOY_1", "AVATAR_BOY" -> R.drawable.avatar_boy
    "BOY_2", "AVATAR_BOY_2" -> R.drawable.avatar_boy_2
    else -> R.drawable.mimi_happy
}

@Composable
private fun CategoryChip(title: String, selected: Boolean, onClick: () -> Unit) {
    val source = remember { MutableInteractionSource() }
    val icon = when (title) {
        "Tất cả" -> Icons.Filled.GridView
        "Toán học" -> Icons.Filled.Calculate
        "Ngôn ngữ", "Tiếng Anh" -> Icons.Filled.Translate
        "Kỹ năng sống", "Sáng tạo" -> Icons.Filled.Spa
        else -> Icons.Filled.Psychology
    }
    val tint = when (title) {
        "Toán học" -> Color(0xFFFF9A1F)
        "Ngôn ngữ" -> Color(0xFF3585F5)
        "Tiếng Anh" -> Color(0xFF50A7FF)
        "Kỹ năng sống" -> Color(0xFF32BD83)
        "Sáng tạo" -> Color(0xFFAC68E8)
        else -> Pink
    }
    val grow by animateFloatAsState(if (selected) 1.08f else 1f, label = "chip")
    Column(
        Modifier.width(72.dp).graphicsLayer { scaleX = grow; scaleY = grow }
            .pressScale(source, pressedScale = .92f)
            .clip(RoundedCornerShape(20.dp))
            .clickable(interactionSource = source, indication = null, onClick = onClick)
            .padding(vertical = 5.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            Modifier.size(54.dp)
                .shadow(if (selected) 8.dp else 3.dp, CircleShape)
                .clip(CircleShape)
                .background(
                    if (selected) Brush.verticalGradient(listOf(Color(0xFFFF9CC4), Color(0xFFFF4B8D)))
                    else Brush.verticalGradient(listOf(Color.White, tint.copy(alpha = .16f)))
                )
                .border(2.5.dp, if (selected) Color.White else tint.copy(alpha = .35f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            if (title == "Toán học") {
                Text("1 2\n3", color = if (selected) Color.White else tint, fontSize = 14.sp, lineHeight = 13.sp, fontWeight = FontWeight.ExtraBold, textAlign = TextAlign.Center)
            } else {
                Icon(icon, null, tint = if (selected) Color.White else tint, modifier = Modifier.size(27.dp))
            }
        }
        Text(
            title, color = if (selected) Pink else Color(0xFF65728B), fontSize = 11.sp,
            fontWeight = if (selected) FontWeight.ExtraBold else FontWeight.Medium,
            maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 4.dp)
        )
    }
}

private val rowTints = listOf(Color(0xFFFFE3EF), Color(0xFFFFF1D6), Color(0xFFE2F3FF), Color(0xFFE6F8EC), Color(0xFFF1E6FF))
private val rowAccents = listOf(Color(0xFFEF4E91), Color(0xFFFF9A1F), Color(0xFF3585F5), Color(0xFF32BD83), Color(0xFFAC68E8))

@Composable
private fun LessonRow(number: Int, lesson: JSONObject, onClick: () -> Unit) {
    val tint = rowTints[(number - 1) % rowTints.size]
    val accent = rowAccents[(number - 1) % rowAccents.size]
    val source = remember { MutableInteractionSource() }
    val shape = RoundedCornerShape(24.dp)
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 5.dp)
            .pressScale(source, pressedScale = .97f)
            .shadow(5.dp, shape).clip(shape)
            .background(Brush.horizontalGradient(listOf(Color.White, tint)))
            .border(2.dp, Color.White, shape)
            .clickable(interactionSource = source, indication = null, onClick = onClick)
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box {
            Image(
                painterResource(R.drawable.family_picnic_bg), null,
                Modifier.size(width = 86.dp, height = 74.dp).clip(RoundedCornerShape(18.dp))
                    .border(2.5.dp, Color.White, RoundedCornerShape(18.dp)),
                contentScale = ContentScale.Crop
            )
            Box(
                Modifier.align(Alignment.TopStart).padding(3.dp).size(24.dp)
                    .clip(CircleShape).background(accent).border(1.5.dp, Color.White, CircleShape),
                contentAlignment = Alignment.Center
            ) { Text("$number", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.ExtraBold) }
        }
        Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
            Text(
                domainTitle(lesson.optString("domainCode")), color = accent, fontSize = 10.sp, fontWeight = FontWeight.ExtraBold,
                modifier = Modifier.clip(CircleShape).background(accent.copy(alpha = .14f)).padding(horizontal = 8.dp, vertical = 2.dp)
            )
            Text(lesson.optString("title", "Bài học"), Modifier.padding(top = 3.dp), color = Navy, fontSize = 14.sp, fontWeight = FontWeight.ExtraBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(lesson.stringOrNull("objective").orEmpty(), color = Color(0xFF7D879B), fontSize = 11.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
        Box(
            Modifier.size(38.dp).shadow(4.dp, CircleShape).clip(CircleShape)
                .background(Brush.verticalGradient(listOf(Color(0xFFFF9CC4), Color(0xFFFF4B8D))))
                .border(2.dp, Color.White, CircleShape),
            contentAlignment = Alignment.Center
        ) { Icon(Icons.Filled.ArrowForward, "Mở bài học", tint = Color.White, modifier = Modifier.size(18.dp)) }
    }
}

@Composable
fun MainBottomBar(selectedTab: String, onTabClick: (String) -> Unit) {
    val shape = RoundedCornerShape(topStart = 30.dp, topEnd = 30.dp)
    Row(
        Modifier.fillMaxWidth().shadow(16.dp, shape).clip(shape)
            .background(Brush.verticalGradient(listOf(Color.White, Color(0xFFFFF0F6))))
            .navigationBarsPadding().padding(horizontal = 8.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceAround, verticalAlignment = Alignment.CenterVertically
    ) {
        BottomItem("Trang chủ", "🏠", Color(0xFFFF8DBB), selectedTab == "HOME") { onTabClick("HOME") }
        BottomItem("Bài học", "📚", Color(0xFFFFB84D), selectedTab == "LESSONS") { onTabClick("LESSONS") }
        BottomItem("Yêu thích", "💖", Color(0xFFFF6FA5), selectedTab == "FAVORITES") { onTabClick("FAVORITES") }
        BottomItem("Tiến độ", "🌟", Color(0xFF7CC4FF), selectedTab == "PROGRESS") { onTabClick("PROGRESS") }
        BottomItem("Phụ huynh", "👨‍👩‍👧", Color(0xFFB98CFF), selectedTab == "PROFILE") { onTabClick("PROFILE") }
    }
}

@Composable
private fun BottomItem(label: String, emoji: String, color: Color, selected: Boolean, onClick: () -> Unit) {
    val source = remember { MutableInteractionSource() }
    val jump by animateFloatAsState(if (selected) -6f else 0f, label = "jump")
    val grow by animateFloatAsState(if (selected) 1.15f else 1f, label = "grow")
    Column(
        Modifier.pressScale(source, pressedScale = .88f)
            .clickable(interactionSource = source, indication = null, onClick = onClick)
            .padding(horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            Modifier.size(48.dp)
                .graphicsLayer { translationY = jump; scaleX = grow; scaleY = grow }
                .shadow(if (selected) 6.dp else 0.dp, CircleShape)
                .clip(CircleShape)
                .background(Brush.verticalGradient(listOf(color.copy(alpha = if (selected) .55f else .22f), color.copy(alpha = if (selected) .95f else .35f))))
                .border(if (selected) 2.5.dp else 1.5.dp, Color.White, CircleShape),
            contentAlignment = Alignment.Center
        ) { Text(emoji, fontSize = 24.sp) }
        Text(
            label, color = if (selected) Color.White else Color(0xFF9AA0BC), fontSize = 10.sp,
            fontWeight = if (selected) FontWeight.ExtraBold else FontWeight.Medium,
            modifier = Modifier.padding(top = 3.dp).clip(CircleShape)
                .background(if (selected) Pink else Color.Transparent)
                .padding(horizontal = 8.dp, vertical = 1.dp)
        )
    }
}

private fun domainTitle(code: String): String = when (code.uppercase()) {
    "MATH", "MATHEMATICS", "NUMBER" -> "Toán học"
    "LANGUAGE", "LITERACY", "VIETNAMESE" -> "Ngôn ngữ"
    "ENGLISH" -> "Tiếng Anh"
    "LIFE_SKILLS", "LIFE" -> "Kỹ năng sống"
    "SCIENCE", "NATURE" -> "Khám phá"
    "ART", "MUSIC" -> "Sáng tạo"
    else -> code.replace('_', ' ').lowercase().replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }.ifBlank { "Khám phá" }
}

@Preview(showBackground = true, showSystemUi = true, device = "id:pixel_7")
@Composable
fun HomeScreenPreview() { MimiGoTheme { HomeScreen(childName = "Bé") } }
