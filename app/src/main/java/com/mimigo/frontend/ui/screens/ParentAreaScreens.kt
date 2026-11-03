package com.mimigo.frontend.ui.screens

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mimigo.frontend.R
import com.mimigo.frontend.data.MimiGoApi
import com.mimigo.frontend.ui.components.pressScale
import com.mimigo.frontend.ui.theme.MimiGoTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

private val ParentPink = Color(0xFFEF4E91)
private val ParentPinkLight = Color(0xFFFF8DBB)
private val ParentNavy = Color(0xFF3B3A7A)
private val ParentBg = Color(0xFFFFF6FA)
private val ParentGray = Color(0xFF7E879E)
private val ParentButton = Brush.verticalGradient(listOf(Color(0xFFFF9CC4), Color(0xFFFF4B8D)))

/* ───────────── Âm thanh nút bấm (dùng chung sfx_* của màn học) ───────────── */

private class ParentSfx(context: Context) {
    private val pool: SoundPool? = runCatching {
        SoundPool.Builder().setMaxStreams(3).setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
        ).build()
    }.getOrNull()
    private val tapId = load(context, R.raw.sfx_tap)
    private val okId = load(context, R.raw.sfx_correct)
    private val sorryId = load(context, R.raw.sfx_try_again)

    private fun load(c: Context, res: Int): Int = runCatching { pool?.load(c, res, 1) ?: 0 }.getOrDefault(0)
    private fun play(id: Int) { if (id != 0) runCatching { pool?.play(id, 1f, 1f, 1, 0, 1f) } }
    fun tap() = play(tapId)
    fun success() = play(okId)
    fun sorry() = play(sorryId)
    fun release() { runCatching { pool?.release() } }
}

private val LocalParentSfx = compositionLocalOf<ParentSfx?> { null }

/* ───────────── Khung trang & thành phần dùng chung ───────────── */

@Composable
private fun ParentHeader(title: String, subtitle: String?, onBack: () -> Unit) {
    val sfx = LocalParentSfx.current
    val bob = rememberInfiniteTransition(label = "header-bob")
    val dy by bob.animateFloat(
        0f, -6f, infiniteRepeatable(tween(1100, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "dy"
    )
    val back = remember { MutableInteractionSource() }
    Box(
        Modifier.fillMaxWidth().height(142.dp)
            .clip(RoundedCornerShape(bottomStart = 32.dp, bottomEnd = 32.dp))
    ) {
        Image(painterResource(R.drawable.family_picnic_bg), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color(0x66FFFFFF), Color(0xE6FFF0F6)))))
        Row(
            Modifier.fillMaxSize().statusBarsPadding().padding(start = 14.dp, end = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                Modifier.pressScale(back, pressedScale = .88f)
                    .size(46.dp).shadow(6.dp, CircleShape).clip(CircleShape).background(Color.White)
                    .border(2.dp, ParentPinkLight, CircleShape)
                    .clickable(interactionSource = back, indication = null) { sfx?.tap(); onBack() },
                contentAlignment = Alignment.Center
            ) { Icon(Icons.Filled.ArrowBack, "Quay lại", tint = ParentPink, modifier = Modifier.size(24.dp)) }
            Column(Modifier.weight(1f).padding(start = 12.dp)) {
                Text(
                    title,
                    style = TextStyle(
                        color = ParentPink, fontSize = 22.sp, fontWeight = FontWeight.ExtraBold,
                        shadow = Shadow(Color.White, Offset.Zero, blurRadius = 16f)
                    ),
                    maxLines = 2, overflow = TextOverflow.Ellipsis
                )
                subtitle?.let {
                    Text(
                        it,
                        style = TextStyle(
                            color = ParentNavy, fontSize = 11.sp, fontWeight = FontWeight.Bold,
                            shadow = Shadow(Color.White, Offset.Zero, blurRadius = 12f)
                        )
                    )
                }
            }
            Image(
                painterResource(R.drawable.mimi_happy), null,
                Modifier.size(78.dp).graphicsLayer { translationY = dy }
            )
        }
    }
}

@Composable
private fun ParentPage(title: String, subtitle: String? = null, onBack: () -> Unit, content: @Composable () -> Unit) {
    val context = LocalContext.current
    val inspection = LocalInspectionMode.current
    val sfx = remember { if (inspection) null else ParentSfx(context) }
    DisposableEffect(sfx) { onDispose { sfx?.release() } }
    CompositionLocalProvider(LocalParentSfx provides sfx) {
        Column(Modifier.fillMaxSize().background(ParentBg)) {
            ParentHeader(title, subtitle, onBack)
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 14.dp).navigationBarsPadding(),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) { content() }
        }
    }
}

@Composable
private fun ParentCard(content: @Composable () -> Unit) {
    val shape = RoundedCornerShape(26.dp)
    Column(
        Modifier.fillMaxWidth().shadow(6.dp, shape).clip(shape).background(Color.White)
            .border(2.dp, Color(0xFFFFE3EF), shape).padding(16.dp)
    ) { content() }
}

@Composable
private fun CardTitle(emoji: String, text: String, tint: Color = Color(0xFFFFE3EF)) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier.size(38.dp).clip(CircleShape).background(tint).border(2.dp, Color.White, CircleShape),
            contentAlignment = Alignment.Center
        ) { Text(emoji, fontSize = 19.sp) }
        Text(text, Modifier.padding(start = 10.dp), color = ParentNavy, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
    }
}

@Composable
private fun ParentAvatar(key: String?, size: Int) {
    val res = when (key?.uppercase()) {
        "GIRL", "GIRL_1", "AVATAR_GIRL" -> R.drawable.avatar_girl
        "GIRL_2", "AVATAR_GIRL_2" -> R.drawable.avatar_girl_2
        "BOY", "BOY_1", "AVATAR_BOY" -> R.drawable.avatar_boy
        "BOY_2", "AVATAR_BOY_2" -> R.drawable.avatar_boy_2
        else -> R.drawable.mimi_happy
    }
    Image(
        painterResource(res), null,
        Modifier.size(size.dp)
            .border(3.dp, Brush.linearGradient(listOf(ParentPinkLight, Color(0xFFFFC857), Color(0xFF8EC5FF))), CircleShape)
            .padding(3.dp).clip(CircleShape).background(Color(0xFFFFE7F0)),
        contentScale = ContentScale.Crop
    )
}

@Composable
private fun Chip(text: String, color: Color = ParentPink) {
    Text(
        text, color = color, fontSize = 11.sp, fontWeight = FontWeight.Bold,
        modifier = Modifier.clip(CircleShape).background(color.copy(alpha = .12f)).padding(horizontal = 10.dp, vertical = 4.dp)
    )
}

/** Nút hồng mập (giống "Học ngay"), có tiếng bấm. danger = đỏ nhạt, muted = xám (đang bị khóa). */
@Composable
private fun ParentAction(
    title: String, subtitle: String, onClick: () -> Unit,
    danger: Boolean = false, muted: Boolean = false
) {
    val sfx = LocalParentSfx.current
    val source = remember { MutableInteractionSource() }
    val shape = RoundedCornerShape(22.dp)
    val bg = when {
        danger -> Brush.verticalGradient(listOf(Color.White, Color(0xFFFFEEF2)))
        muted -> Brush.verticalGradient(listOf(Color(0xFFC9CDDD), Color(0xFFA9AEC4)))
        else -> ParentButton
    }
    val fg = if (danger) Color(0xFFC84B69) else Color.White
    Row(
        Modifier.fillMaxWidth().pressScale(source, pressedScale = .96f)
            .shadow(if (muted) 2.dp else 6.dp, shape).clip(shape).background(bg)
            .border(2.5.dp, if (danger) Color(0xFFFFC2D1) else Color.White, shape)
            .clickable(interactionSource = source, indication = null) { sfx?.tap(); onClick() }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, color = fg, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
            Text(subtitle, color = fg.copy(alpha = .88f), fontSize = 11.sp, lineHeight = 14.sp)
        }
        Box(
            Modifier.size(30.dp).clip(CircleShape).background(if (danger) Color(0xFFFFE0E8) else Color.White.copy(alpha = .28f)),
            contentAlignment = Alignment.Center
        ) { Icon(Icons.Filled.ArrowForward, null, tint = fg, modifier = Modifier.size(17.dp)) }
    }
}

@Composable
private fun EmptyMimi(image: Int, title: String, body: String) {
    val bob = rememberInfiniteTransition(label = "empty-bob")
    val dy by bob.animateFloat(
        0f, -8f, infiniteRepeatable(tween(1000, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "dy"
    )
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Image(painterResource(image), null, Modifier.size(width = 120.dp, height = 130.dp).graphicsLayer { translationY = dy })
        Text(title, Modifier.padding(top = 6.dp), color = ParentNavy, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, textAlign = TextAlign.Center)
        Text(body, Modifier.padding(top = 5.dp), color = ParentGray, fontSize = 13.sp, lineHeight = 18.sp, textAlign = TextAlign.Center)
    }
}

/* ───────────── Hồ sơ phụ huynh ───────────── */

@Composable
fun ParentProfileScreen(
    api: MimiGoApi,
    children: List<ChildHomeProfile>,
    onBack: () -> Unit,
    onPremium: () -> Unit,
    onAddChild: () -> Unit,
    onLogout: () -> Unit
) {
    var parent by remember { mutableStateOf<JSONObject?>(null) }
    var childDetails by remember { mutableStateOf<Map<String, ChildHomeProfile>>(emptyMap()) }
    var childPlanStatuses by remember { mutableStateOf<Map<String, String>>(emptyMap()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(api, children) {
        try { parent = api.parentProfile() }
        catch (e: Exception) { error = e.message ?: "Không tải được hồ sơ phụ huynh." }
        children.forEach { child ->
            runCatching { api.childDetails(child.id) }.onSuccess { detail ->
                childDetails = childDetails + (child.id to ChildHomeProfile(
                    id = detail.optString("childId").takeIf { it.isNotBlank() && it != "null" } ?: child.id,
                    name = detail.optString("childAlias").takeIf { it.isNotBlank() && it != "null" } ?: child.name,
                    ageYears = if (detail.has("ageYears") && !detail.isNull("ageYears")) detail.optInt("ageYears") else child.ageYears,
                    avatarKey = detail.optString("stockAvatarKey").takeIf { it.isNotBlank() && it != "null" } ?: child.avatarKey
                ))
            }
            childPlanStatuses = childPlanStatuses + (child.id to runCatching {
                when (api.premiumEntitlement(child.id).optString("status")) {
                    "ACTIVE" -> "💎 Premium đang hoạt động"
                    "EXPIRED" -> "⌛ Premium đã hết hạn"
                    else -> "🌱 Chưa có gói Premium"
                }
            }.getOrElse { "Trạng thái gói chưa khả dụng" })
        }
        loading = false
    }
    ParentProfileContent(
        parentName = parent?.optString("displayName")?.takeIf { it.isNotBlank() && it != "null" } ?: "Phụ huynh MimiGo",
        parentEmail = parent?.optString("email")?.takeIf { it.isNotBlank() && it != "null" } ?: "Tài khoản đã đăng nhập",
        loading = loading, error = error, children = children.map { childDetails[it.id] ?: it }, statuses = childPlanStatuses,
        onBack = onBack, onPremium = onPremium, onAddChild = onAddChild, onLogout = onLogout
    )
}

@Composable
private fun ParentProfileContent(
    parentName: String, parentEmail: String, loading: Boolean, error: String?,
    children: List<ChildHomeProfile>, statuses: Map<String, String>,
    onBack: () -> Unit, onPremium: () -> Unit, onAddChild: () -> Unit, onLogout: () -> Unit
) {
    ParentPage("Hồ sơ phụ huynh", "Quản lý tài khoản và hồ sơ của bé", onBack) {
        ParentCard {
            CardTitle("👨‍👩‍👧", "Tài khoản phụ huynh")
            Spacer(Modifier.height(12.dp))
            when {
                loading -> CircularProgressIndicator(color = ParentPink, modifier = Modifier.size(26.dp))
                error != null -> Text(error, color = Color(0xFFB43C5D), fontSize = 13.sp)
                else -> Row(verticalAlignment = Alignment.CenterVertically) {
                    ParentAvatar(null, 58)
                    Column(Modifier.padding(start = 12.dp)) {
                        Text(parentName, color = ParentNavy, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                        Text(parentEmail, color = ParentGray, fontSize = 13.sp)
                    }
                }
            }
        }
        ParentCard {
            CardTitle("🐣", "Hồ sơ của các bé (${children.size})", Color(0xFFFFF1D6))
            children.forEach { child ->
                Row(
                    Modifier.fillMaxWidth().padding(top = 12.dp).clip(RoundedCornerShape(20.dp))
                        .background(Brush.horizontalGradient(listOf(Color(0xFFFFF6FA), Color(0xFFFFE9F2)))).padding(10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    ParentAvatar(child.avatarKey, 54)
                    Column(Modifier.weight(1f).padding(start = 12.dp)) {
                        Text(child.name, color = ParentNavy, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(child.ageYears?.let { "🎂 $it tuổi" } ?: "Hồ sơ học tập", color = Color(0xFF8991A8), fontSize = 12.sp)
                        Spacer(Modifier.height(4.dp))
                        Chip(statuses[child.id] ?: "Đang kiểm tra gói học…")
                    }
                }
            }
            Spacer(Modifier.height(14.dp))
            ParentAction("＋  Thêm hồ sơ cho bé", "Tạo hồ sơ mới bằng biểu mẫu hiện có", onAddChild)
            Text("Backend hiện chưa có API chỉnh sửa hoặc xóa hồ sơ bé.", Modifier.padding(top = 8.dp), color = Color(0xFF8991A8), fontSize = 11.sp)
        }
        ParentCard {
            CardTitle("💎", "Gói học", Color(0xFFE2F3FF))
            Text("Xem trạng thái gói của từng hồ sơ và các gói đang được backend cung cấp.", Modifier.padding(top = 8.dp, bottom = 12.dp), color = ParentGray, fontSize = 12.sp)
            ParentAction("Xem gói Premium", "Gói và trạng thái đăng ký theo hồ sơ bé", onPremium)
        }
        ParentAction("Đăng xuất", "Đăng xuất khỏi tài khoản trên thiết bị này", onLogout, danger = true)
    }
}

/* ───────────── Gói Premium ───────────── */

private val PlanTints = listOf(Color(0xFFFFE3EF), Color(0xFFFFF1D6), Color(0xFFE2F3FF), Color(0xFFE6F8EC))
private val PlanAccents = listOf(Color(0xFFEF4E91), Color(0xFFFF9A1F), Color(0xFF3585F5), Color(0xFF32BD83))

@Composable
fun PremiumPlansScreen(childId: String, childName: String, api: MimiGoApi, onBack: () -> Unit, onBuy: (JSONObject) -> Unit) {
    var plans by remember(childId) { mutableStateOf(JSONArray()) }
    var eligibility by remember(childId) { mutableStateOf<JSONObject?>(null) }
    var entitlement by remember(childId) { mutableStateOf<JSONObject?>(null) }
    var notice by remember(childId) { mutableStateOf<String?>(null) }
    var loading by remember(childId) { mutableStateOf(true) }
    LaunchedEffect(childId, api) {
        loading = true
        try {
            plans = api.premiumPlans().optJSONArray("plans") ?: JSONArray()
            eligibility = api.premiumEligibility(childId)
            entitlement = api.premiumEntitlement(childId)
        } catch (e: Exception) { notice = e.message ?: "Gói Premium chưa khả dụng." }
        finally { loading = false }
    }
    ParentPage("Gói học Premium", "Hồ sơ của $childName", onBack) {
        entitlement?.let { current ->
            ParentCard {
                CardTitle("🏅", "Trạng thái hiện tại", Color(0xFFFFF1D6))
                Text(
                    when (current.optString("status")) { "ACTIVE" -> "💎 Đang hoạt động"; "EXPIRED" -> "⌛ Đã hết hạn"; else -> "🌱 Chưa có gói Premium" },
                    Modifier.padding(top = 10.dp), color = ParentPink, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold
                )
                current.optString("expiresAt").takeIf { it.isNotBlank() && it != "null" }
                    ?.let { Text("Hết hạn: $it", color = ParentGray, fontSize = 12.sp) }
            }
        }
        ParentCard {
            CardTitle("🎁", "Các lựa chọn cho $childName", Color(0xFFE2F3FF))
            if (loading) CircularProgressIndicator(color = ParentPink, modifier = Modifier.padding(top = 12.dp).size(28.dp))
            else if (notice != null) {
                Text(notice.orEmpty(), Modifier.padding(top = 10.dp), color = Color(0xFFB43C5D), fontSize = 13.sp)
                Text("API Premium là module mặc định tắt; chỉ có dữ liệu khi Billing:Enabled được bật.", Modifier.padding(top = 5.dp), color = Color(0xFF8991A8), fontSize = 11.sp)
            } else if (plans.length() == 0) Text("Backend chưa cung cấp gói nào.", Modifier.padding(top = 10.dp), color = ParentGray)
            else for (index in 0 until plans.length()) {
                val plan = plans.optJSONObject(index) ?: continue
                val term = plan.optInt("termMonths")
                val price = plan.optJSONObject("price")?.optInt("amountMinor") ?: plan.optInt("amountMinor")
                val currency = plan.optJSONObject("price")?.optString("currency", "VND") ?: plan.optString("currency", "VND")
                val allowed = eligibility?.optJSONArray("terms")?.let { terms ->
                    (0 until terms.length()).mapNotNull { terms.optJSONObject(it) }
                        .firstOrNull { it.optString("planId") == plan.optString("planId") }?.optBoolean("allowed", false)
                } ?: false
                val tint = PlanTints[index % PlanTints.size]
                val accent = PlanAccents[index % PlanAccents.size]
                val shape = RoundedCornerShape(22.dp)
                Column(
                    Modifier.fillMaxWidth().padding(top = 12.dp).clip(shape)
                        .background(Brush.horizontalGradient(listOf(Color.White, tint)))
                        .border(2.dp, tint, shape).padding(13.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(
                            Modifier.size(58.dp).clip(CircleShape).background(accent).border(3.dp, Color.White, CircleShape),
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center
                        ) {
                            Text("$term", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.ExtraBold, lineHeight = 22.sp)
                            Text("tháng", color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                        }
                        Column(Modifier.weight(1f).padding(start = 12.dp)) {
                            Text("$price $currency", color = ParentNavy, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp)
                            Chip("Gói mô phỏng", accent)
                        }
                    }
                    Text("Giá này chỉ là dữ liệu simulator, chưa phải giá bán thật.", Modifier.padding(top = 8.dp, bottom = 10.dp), color = Color(0xFF858CA1), fontSize = 10.sp)
                    ParentAction(
                        if (allowed) "Chọn gói này" else "Chưa đủ điều kiện mua",
                        if (allowed) "Xem bước thanh toán" else "Backend chưa cho phép kỳ hạn này",
                        onClick = { if (allowed) onBuy(JSONObject(plan.toString())) },
                        muted = !allowed
                    )
                }
            }
        }
        Text(
            "Gói mô phỏng không phải thanh toán thật và chưa đảm bảo mở khóa bài học Premium. Backend Billing và Learning có các cờ bật riêng.",
            color = Color(0xFF8991A8), fontSize = 11.sp
        )
    }
}

@Composable
fun PremiumCheckoutScreen(childName: String, plan: JSONObject?, onBack: () -> Unit, onPay: () -> Unit) {
    ParentPage("Xác nhận gói học", "Thanh toán mô phỏng", onBack) {
        ParentCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Image(painterResource(R.drawable.mimi_heart), null, Modifier.size(width = 90.dp, height = 96.dp))
                Column(Modifier.weight(1f).padding(start = 12.dp)) {
                    Text("Gói Premium cho $childName", color = ParentNavy, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp)
                    Text("${plan?.optInt("termMonths") ?: 0} tháng", Modifier.padding(top = 6.dp), color = ParentPink, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold)
                    val price = plan?.optJSONObject("price")?.optInt("amountMinor") ?: plan?.optInt("amountMinor") ?: 0
                    val currency = plan?.optJSONObject("price")?.optString("currency", "VND") ?: "VND"
                    Text("Tổng tiền mô phỏng: $price $currency", color = ParentNavy, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                }
            }
        }
        ParentCard {
            CardTitle("🔒", "Chưa thể tiếp tục thanh toán", Color(0xFFFFF1D6))
            Text(
                "Backend handoff chỉ có simulator; tạo checkout và ghi nhận thành công/thất bại đều yêu cầu Parent Gate proof. App hiện chưa có luồng Parent Gate để lấy proof, vì vậy chưa gửi yêu cầu mua hoặc giả lập kết quả.",
                Modifier.padding(top = 10.dp), color = Color(0xFF737E96), fontSize = 13.sp, lineHeight = 19.sp
            )
            Spacer(Modifier.height(12.dp))
            ParentAction("Cần Parent Gate proof", "Checkout đang tắt trong app cho tới khi xác minh phụ huynh khả dụng", onPay, muted = true)
        }
    }
}

/* ───────────── Thông báo / Yêu thích ───────────── */

@Composable
fun NotificationsScreen(onBack: () -> Unit) {
    ParentPage("Thông báo", "Tin mới dành cho phụ huynh", onBack) {
        ParentCard {
            EmptyMimi(
                R.drawable.mimi_sleepy, "Backend chưa có API thông báo",
                "Danh sách thông báo và trạng thái đã đọc sẽ xuất hiện khi backend cung cấp endpoint tương ứng."
            )
        }
    }
}

@Composable
fun FavoritesScreen(onBack: () -> Unit) {
    ParentPage("Bài học yêu thích", "Những bài bé muốn học lại", onBack) {
        ParentCard {
            EmptyMimi(
                R.drawable.mimi_heart, "Chưa có API yêu thích",
                "Handoff hiện chưa ánh xạ API xem/thêm/xóa bài yêu thích, nên danh sách này chưa thể đồng bộ với backend."
            )
        }
    }
}

/* ───────────── Cài đặt / Điều khoản ───────────── */

@Composable
fun SettingsScreen(english: Boolean, onEnglishChange: (Boolean) -> Unit, onBack: () -> Unit, onTerms: () -> Unit, onPremium: () -> Unit, onParentGate: () -> Unit, onLogout: () -> Unit) {
    val sfx = LocalParentSfx.current
    ParentPage("Cài đặt", "Tùy chỉnh tài khoản MimiGo", onBack) {
        ParentCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.size(44.dp).clip(CircleShape).background(Color(0xFFE2F3FF)).border(2.dp, Color.White, CircleShape),
                    contentAlignment = Alignment.Center
                ) { Text("🌏", fontSize = 22.sp) }
                Column(Modifier.weight(1f).padding(start = 12.dp)) {
                    Text("Ngôn ngữ", color = ParentNavy, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                    Text(if (english) "English selected" else "Tiếng Việt", color = Color(0xFF8991A8), fontSize = 12.sp)
                }
                Switch(
                    checked = english,
                    onCheckedChange = { sfx?.tap(); onEnglishChange(it) },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.White, checkedTrackColor = ParentPink,
                        uncheckedThumbColor = Color.White, uncheckedTrackColor = Color(0xFFD7DAE8)
                    )
                )
            }
            Text("Tùy chọn này lưu trên thiết bị. Bản dịch đầy đủ toàn ứng dụng cần bộ chuỗi tiếng Anh riêng.", Modifier.padding(top = 8.dp), color = Color(0xFF8991A8), fontSize = 11.sp)
        }
        ParentAction("🔐  Bảo vệ khu vực phụ huynh", "Thiết lập hoặc xác minh PIN phụ huynh", onParentGate)
        ParentAction("💎  Gói học và thanh toán", "Xem các gói Premium cho hồ sơ bé đang chọn", onPremium)
        ParentAction("📜  Điều khoản sử dụng", "Xem điều khoản hiện hành từ API", onTerms)
        ParentAction("Đăng xuất", "Xóa phiên đăng nhập trên thiết bị", onLogout, danger = true)
    }
}

@Composable
fun TermsScreen(api: MimiGoApi, onBack: () -> Unit) {
    var termsText by remember { mutableStateOf<String?>(null) }
    var termsVersionId by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var accepted by remember { mutableStateOf(false) }
    var submitting by remember { mutableStateOf(false) }
    var acceptedOnServer by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(api) {
        try {
            val terms = api.onboardingReference().optJSONObject("terms")
            termsVersionId = terms?.optString("termsVersionId")?.takeIf { it.isNotBlank() && it != "null" }
            termsText = listOf("text", "termsText", "content", "noticeText", "summary")
                .firstNotNullOfOrNull { key -> terms?.optString(key)?.takeIf { it.isNotBlank() && it != "null" } }
                ?: "API cung cấp phiên bản điều khoản ${terms?.optString("versionLabel", "hiện hành")}, nhưng không trả nội dung văn bản để hiển thị."
        } catch (e: Exception) { error = e.message ?: "Không tải được điều khoản." }
    }
    ParentPage("Điều khoản sử dụng", "Mimi muốn gia đình hiểu rõ nhé", onBack) {
        ParentCard {
            CardTitle("📜", "Điều khoản & quyền riêng tư")
            Text(error ?: termsText ?: "Mimi đang tải điều khoản… 🐝", Modifier.padding(top = 12.dp), color = ParentNavy, fontSize = 14.sp, lineHeight = 21.sp)
            Row(Modifier.fillMaxWidth().padding(top = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Checkbox(
                    checked = accepted,
                    onCheckedChange = { accepted = it },
                    enabled = !submitting && !acceptedOnServer,
                    colors = CheckboxDefaults.colors(checkedColor = ParentPink)
                )
                Text("Tôi đã đọc và đồng ý với phiên bản điều khoản hiện hành.", color = ParentGray, fontSize = 12.sp, lineHeight = 17.sp)
            }
            Button(
                enabled = accepted && termsVersionId != null && !submitting && !acceptedOnServer,
                onClick = {
                    val versionId = termsVersionId ?: return@Button
                    scope.launch {
                        submitting = true
                        error = null
                        try {
                            api.acceptTerms(versionId)
                            acceptedOnServer = true
                        } catch (e: Exception) {
                            error = e.message ?: "Chưa gửi được xác nhận điều khoản."
                        } finally {
                            submitting = false
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth().padding(top = 6.dp),
                colors = ButtonDefaults.buttonColors(containerColor = ParentPink)
            ) {
                if (submitting) CircularProgressIndicator(color = Color.White, modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                else Text(if (acceptedOnServer) "Đã ghi nhận đồng ý ✓" else "Xác nhận điều khoản", fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
fun RegistrationLegalDialog(api: MimiGoApi, showPrivacy: Boolean, onDismiss: () -> Unit) {
    var body by remember(api, showPrivacy) { mutableStateOf<String?>(null) }
    var error by remember(api, showPrivacy) { mutableStateOf<String?>(null) }
    LaunchedEffect(api, showPrivacy) {
        try {
            val reference = api.onboardingReference()
            if (showPrivacy) {
                val notices = reference.optJSONArray("notices")
                    ?: reference.optJSONArray("currentNotices")
                    ?: JSONArray()
                val entries = (0 until notices.length()).mapNotNull { index ->
                    val notice = notices.optJSONObject(index) ?: return@mapNotNull null
                    val version = notice.optJSONObject("currentVersion") ?: notice
                    val purpose = when (notice.optString("purposeCode")) {
                        "CHILD_PROFILE_AGE" -> "Hồ sơ và độ tuổi của trẻ"
                        "LEARNING_PROGRESS", "CHILD_LEARNING" -> "Hoạt động và tiến độ học tập"
                        "ACCOUNT_AUTH" -> "Tài khoản và xác thực phụ huynh"
                        "SECURITY_AUDIT" -> "Bảo mật và nhật ký hệ thống"
                        "SUPPORT_RIGHTS" -> "Hỗ trợ và quyền của người dùng"
                        else -> notice.optString("purposeCode").replace('_', ' ').lowercase()
                    }
                    val content = listOf("noticeText", "text", "contentText", "content", "summary")
                        .firstNotNullOfOrNull { key -> version?.optString(key)?.takeIf { it.isNotBlank() && it != "null" } }
                    val label = version?.optString("versionLabel")?.takeIf { it.isNotBlank() && it != "null" }
                        ?: "phiên bản hiện hành"
                    "$purpose · $label" + (content?.let { "\n$it" } ?: "")
                }
                body = entries.takeIf { it.isNotEmpty() }?.joinToString("\n\n")
                    ?.plus("\n\nAPI hiện chỉ cung cấp tên mục và phiên bản; chưa có nội dung văn bản thông báo.")
                    ?: "API chưa trả các mục thông báo quyền riêng tư."
            } else {
                val terms = reference.optJSONObject("terms")
                val version = terms?.optString("versionLabel")?.takeIf { it.isNotBlank() && it != "null" }
                    ?: terms?.optString("code")?.takeIf { it.isNotBlank() && it != "null" }
                    ?: terms?.optString("termsVersionId")?.takeIf { it.isNotBlank() && it != "null" }
                val content = listOf("text", "termsText", "content", "noticeText", "summary")
                    .firstNotNullOfOrNull { key -> terms?.optString(key)?.takeIf { it.isNotBlank() && it != "null" } }
                body = content ?: "API cung cấp phiên bản điều khoản ${version ?: "hiện hành"}, nhưng chưa trả văn bản điều khoản."
            }
        } catch (exception: Exception) {
            error = exception.message ?: "Không tải được nội dung từ API."
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (showPrivacy) "Chính sách bảo mật" else "Điều khoản sử dụng", color = ParentNavy, fontWeight = FontWeight.ExtraBold) },
        text = {
            Column(Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState())) {
                when {
                    error != null -> Text(error.orEmpty(), color = Color(0xFFB43C5D), fontSize = 13.sp)
                    body == null -> CircularProgressIndicator(color = ParentPink, modifier = Modifier.size(26.dp))
                    else -> Text(body.orEmpty(), color = ParentNavy, fontSize = 13.sp, lineHeight = 20.sp)
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("Đóng", color = ParentPink, fontWeight = FontWeight.Bold) } },
        containerColor = Color.White
    )
}

/* ───────────── Kết quả thanh toán (có tiếng) ───────────── */

@Composable
fun PaymentResultScreen(success: Boolean, onBack: () -> Unit) {
    ParentPage(if (success) "Thanh toán thành công" else "Thanh toán thất bại", onBack = onBack) {
        val sfx = LocalParentSfx.current
        LaunchedEffect(success) {
            delay(350) // chờ SoundPool nạp xong
            if (success) sfx?.success() else sfx?.sorry()
        }
        val bob = rememberInfiniteTransition(label = "result-bob")
        val dy by bob.animateFloat(
            0f, -12f, infiniteRepeatable(tween(900, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "dy"
        )
        ParentCard {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                Box(contentAlignment = Alignment.TopEnd) {
                    Image(
                        painterResource(if (success) R.drawable.mimi_cheer else R.drawable.mimi_shy), null,
                        Modifier.size(width = 150.dp, height = 185.dp).graphicsLayer { translationY = dy }
                    )
                    Text(if (success) "🎉" else "🍯", fontSize = 30.sp)
                }
                Text(
                    if (success) "Cảm ơn gia đình đã đồng hành cùng MimiGo!" else "Giao dịch chưa hoàn tất",
                    Modifier.fillMaxWidth().padding(top = 8.dp),
                    color = if (success) Color(0xFF2E9E6A) else ParentNavy, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold, textAlign = TextAlign.Center
                )
                Text(
                    if (success) "Backend đã xác nhận kết quả thanh toán mô phỏng." else "Backend báo thanh toán mô phỏng thất bại. Gói chưa được cấp.",
                    Modifier.fillMaxWidth().padding(top = 6.dp), color = ParentGray, textAlign = TextAlign.Center, fontSize = 13.sp
                )
            }
        }
        ParentAction("Quay lại", "Về màn hình trước", onBack)
    }
}

/* ───────────── Preview ───────────── */

private val previewChildren = listOf(
    ChildHomeProfile("1", "Bảo Anh", 3, "GIRL_1"),
    ChildHomeProfile("2", "Minh Khang", 5, "BOY_1")
)

@Preview(showBackground = true, showSystemUi = true, name = "Hồ sơ phụ huynh")
@Composable
fun ParentProfilePreview() {
    MimiGoTheme {
        ParentProfileContent(
            "Phụ huynh MimiGo", "phuhuynh@example.test", false, null, previewChildren,
            mapOf("1" to "💎 Premium đang hoạt động", "2" to "🌱 Chưa có gói Premium"), {}, {}, {}, {}
        )
    }
}

@Preview(showBackground = true, showSystemUi = true, name = "Xác nhận thanh toán")
@Composable
fun PremiumCheckoutPreview() {
    MimiGoTheme { PremiumCheckoutScreen("Bảo Anh", JSONObject().put("termMonths", 1).put("price", JSONObject().put("amountMinor", 1000).put("currency", "VND")), {}, {}) }
}

@Preview(showBackground = true, showSystemUi = true, name = "Thông báo")
@Composable
fun NotificationsPreview() { MimiGoTheme { NotificationsScreen(onBack = {}) } }

@Preview(showBackground = true, showSystemUi = true, name = "Yêu thích")
@Composable
fun FavoritesPreview() { MimiGoTheme { FavoritesScreen(onBack = {}) } }

@Preview(showBackground = true, showSystemUi = true, name = "Cài đặt")
@Composable
fun SettingsPreview() { MimiGoTheme { SettingsScreen(false, {}, {}, {}, {}, {}, {}) } }

@Preview(showBackground = true, showSystemUi = true, name = "Thanh toán thành công")
@Composable
fun PaymentSuccessPreview() { MimiGoTheme { PaymentResultScreen(success = true, onBack = {}) } }

@Preview(showBackground = true, showSystemUi = true, name = "Thanh toán thất bại")
@Composable
fun PaymentFailurePreview() { MimiGoTheme { PaymentResultScreen(success = false, onBack = {}) } }
