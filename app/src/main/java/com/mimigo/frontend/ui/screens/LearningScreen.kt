package com.mimigo.frontend.ui.screens

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mimigo.frontend.R
import com.mimigo.frontend.data.MimiGoApi
import com.mimigo.frontend.ui.theme.MimiGoTheme
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

@Composable
fun LearningScreen(childId: String, lessonId: String, api: MimiGoApi, onExit: () -> Unit) {
    val scope = rememberCoroutineScope()

    // Rung + âm thanh khi bé bấm đáp án. Nếu máy không rung được thì dùng rung hệ thống của Compose.
    val context = LocalContext.current
    val haptic = LocalHapticFeedback.current
    val effects = remember(context) {
        LearningEffects(context) { haptic.performHapticFeedback(HapticFeedbackType.LongPress) }
    }
    DisposableEffect(effects) { onDispose { effects.release() } }

    var lesson by remember { mutableStateOf<JSONObject?>(null) }
    var sessionId by remember { mutableStateOf<String?>(null) }
    var currentCue by remember { mutableIntStateOf(0) }
    var feedback by remember { mutableStateOf<JSONObject?>(null) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var completed by remember { mutableStateOf(false) }
    var allAnswered by remember { mutableStateOf(false) }
    var selectedOptionId by remember { mutableStateOf<String?>(null) }
    val answers = remember { mutableStateMapOf<String, String>() }

    LaunchedEffect(childId, lessonId) {
        busy = true
        try {
            lesson = api.lesson(childId, lessonId)
            val started = api.startLearningSession(childId, lessonId)
            sessionId = started.getString("sessionId")
            if (started.optString("state") == "COMPLETED") completed = true
            val state = api.learningSession(childId, sessionId!!)
            val history = state.optJSONArray("answers") ?: JSONArray()
            for (index in 0 until history.length()) {
                val answer = history.optJSONObject(index) ?: continue
                // A previously incorrect attempt must not mark the cue complete; resume it for retry.
                if (answer.opt("isCorrect") as? Boolean != false) {
                    answers[answer.optString("cueId")] = answer.optString("optionId")
                }
            }
            val cues = lesson?.optJSONArray("cues") ?: JSONArray()
            val firstUnanswered = (0 until cues.length()).firstOrNull { index ->
                val cueId = cues.optJSONObject(index)?.optString("cueId")
                cueId.isNullOrBlank() || !answers.containsKey(cueId)
            }
            allAnswered = cues.length() > 0 && firstUnanswered == null
            currentCue = firstUnanswered ?: (cues.length() - 1).coerceAtLeast(0)
        } catch (e: Exception) {
            error = e.message ?: "Không thể tải bài học. Vui lòng thử lại."
        } finally { busy = false }
    }

    val cues = lesson?.optJSONArray("cues") ?: JSONArray()
    val cue = cues.optJSONObject(currentCue)
    val options = cue?.optJSONArray("options") ?: JSONArray()
    val optionItems = (0 until options.length()).mapNotNull { index ->
        options.optJSONObject(index)?.let { AnswerOption(it.optString("optionId"), it.optString("labelText")) }
    }

    // ----- Lời của Mimi: toàn bộ lấy từ API -----
    // Trước khi trả lời: promptText (+ companion.promptText nếu có tiếng Anh).
    // Sau khi trả lời: feedbackText (+ companion.feedbackText). Chỉ khi API không trả feedbackText
    // thì mới dùng câu khen/động viên dự phòng bên dưới.
    val promptText = cue?.stringOrNull("promptText").orEmpty()
    val isCorrect = feedback?.opt("isCorrect") as? Boolean
    val feedbackText = feedback?.stringOrNull("feedbackText")
    val mimiText = when {
        feedback == null -> promptText
        feedbackText != null -> feedbackText
        isCorrect == true -> "Giỏi quá! Con làm đúng rồi!"
        isCorrect == false -> "Không sao đâu con, mình cùng thử câu tiếp theo nhé!"
        else -> "Mimi đã ghi nhận câu trả lời của con nhé!"
    }
    val mimiCompanion = if (feedback == null) {
        cue?.optJSONObject("companion")?.stringOrNull("promptText")
    } else {
        feedback?.optJSONObject("companion")?.stringOrNull("feedbackText")
    }
    val mood = when (isCorrect) {
        true -> MimiMood.Happy
        false -> MimiMood.Cheer
        null -> MimiMood.Talking
    }

    LearningBackground {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            Row(
                Modifier.fillMaxWidth()
                    .background(Color.White.copy(alpha = 0.9f), RoundedCornerShape(bottomStart = 24.dp, bottomEnd = 24.dp))
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Filled.ArrowBack, "Quay lại", tint = Color(0xFF1749C8), modifier = Modifier
                    .clip(CircleShape).clickable(onClick = onExit).padding(7.dp).size(28.dp))
                Column(Modifier.weight(1f).padding(start = 7.dp)) {
                    Text(lesson?.optString("title", "Bài học") ?: "Đang tải bài học…", color = Color(0xFF173FBD), fontSize = 17.sp, fontWeight = FontWeight.ExtraBold, maxLines = 1)
                    Text(lesson?.optString("objective").orEmpty(), color = Color(0xFF77829A), fontSize = 11.sp, maxLines = 1)
                }
                Text("${(currentCue + 1).coerceAtMost(cues.length())}/${cues.length()}", color = Color(0xFFEF4E91), fontWeight = FontWeight.Bold)
            }

            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 14.dp, vertical = 10.dp)) {
                if (error != null) {
                    Text(
                        error.orEmpty(), color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.padding(bottom = 8.dp)
                            .clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.9f)).padding(8.dp)
                    )
                }
                if (completed) {
                    Card(
                        Modifier.fillMaxWidth(), shape = RoundedCornerShape(22.dp),
                        colors = CardDefaults.cardColors(containerColor = Color.White.copy(alpha = 0.95f))
                    ) {
                        Column(Modifier.fillMaxWidth().padding(28.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("🎉", fontSize = 48.sp)
                            Text("Giỏi quá, con yêu!", color = Color(0xFFEF4E91), fontSize = 23.sp, fontWeight = FontWeight.ExtraBold)
                            Text("Con đã hoàn thành bài học thật xuất sắc. Mimi rất tự hào về con!", color = Color(0xFF173FBD), textAlign = TextAlign.Center, fontWeight = FontWeight.SemiBold)
                            Spacer(Modifier.height(12.dp))
                            Button(
                                enabled = !busy,
                                onClick = {
                                    busy = true
                                    error = null
                                    scope.launch {
                                        try {
                                            val restarted = api.startLearningSession(childId, lessonId)
                                            sessionId = restarted.getString("sessionId")
                                            completed = restarted.optString("state") == "COMPLETED"
                                            if (!completed) {
                                                answers.clear()
                                                currentCue = 0
                                                feedback = null
                                                selectedOptionId = null
                                                allAnswered = false
                                            }
                                        } catch (e: Exception) {
                                            error = e.message ?: "Chưa thể bắt đầu học lại. Con thử lại nhé!"
                                        } finally {
                                            busy = false
                                        }
                                    }
                                },
                                modifier = Modifier.fillMaxWidth()
                            ) { Text(if (busy) "Đang chuẩn bị…" else "🔄  Học lại") }
                            TextButton(onClick = onExit, enabled = !busy) { Text("Về danh sách bài học") }
                        }
                    }
                } else if (!busy || lesson != null) {
                    val answeredIndices = (0 until cues.length()).filter { index ->
                        answers.containsKey(cues.optJSONObject(index)?.optString("cueId").orEmpty())
                    }.toSet()
                    CueProgressStrip(cueCount = cues.length(), currentCue = currentCue, answeredIndices = answeredIndices)
                    Spacer(Modifier.height(10.dp))

                    LessonMediaPanel()
                    if (promptText.isNotBlank()) {
                        Spacer(Modifier.height(10.dp))
                        SoftChip(promptText, Color(0xFF183B9E))
                    }
                    Spacer(Modifier.height(10.dp))

                    // Mimi là người dẫn thoại: đọc câu hỏi, khen khi đúng, động viên khi chưa đúng
                    MimiDialogueBubble(text = mimiText, companionText = mimiCompanion, mood = mood)

                    if (!allAnswered) {
                        Spacer(Modifier.height(14.dp))
                        if (feedback == null) SoftChip("Chọn đáp án nhé!")
                        AnswerOptionsRow(
                            items = optionItems,
                            enabled = !busy && (feedback == null || isCorrect == false),
                            selectedOptionId = selectedOptionId,
                            isCorrect = isCorrect,
                            onSelect = { optionId ->
                                val cueId = cue?.optString("cueId").orEmpty()
                                // Each retry is a new answer event, even when the child picks the same option.
                                val eventId = UUID.randomUUID().toString()
                                selectedOptionId = optionId
                                feedback = null
                                effects.onTap()
                                busy = true; error = null
                                scope.launch {
                                    try {
                                        val result = api.submitAnswer(childId, sessionId!!, cueId, optionId, eventId)
                                        feedback = result
                                        val correctness = result.opt("isCorrect") as? Boolean
                                        if (correctness == false) answers.remove(cueId) else answers[cueId] = optionId
                                        when (correctness) {
                                            true -> effects.onCorrect()
                                            false -> effects.onTryAgain()
                                            null -> Unit
                                        }
                                    } catch (e: Exception) {
                                        selectedOptionId = null
                                        error = e.message ?: "Không gửi được câu trả lời."
                                    } finally { busy = false }
                                }
                            }
                        )
                    }

                    if (isCorrect != false && (feedback != null || allAnswered)) {
                        if (feedback != null) {
                            Spacer(Modifier.height(10.dp))
                            SoftChip(
                                when (isCorrect) { true -> "Chính xác!"; false -> "Không sao, con chọn lại nhé!"; else -> "Đã ghi nhận câu trả lời." },
                                Color(0xFFEF4E91)
                            )
                        }
                        Spacer(Modifier.height(10.dp))
                        Button(enabled = !busy, onClick = {
                            if (currentCue < cues.length() - 1) {
                                currentCue++; feedback = null; selectedOptionId = null
                            } else {
                                busy = true
                                scope.launch {
                                    try { api.completeLearningSession(childId, sessionId!!); completed = true }
                                    catch (e: Exception) { error = e.message ?: "Chưa thể hoàn tất phiên học." }
                                    finally { busy = false }
                                }
                            }
                        }, modifier = Modifier.fillMaxWidth()) {
                            Text(if (allAnswered || currentCue == cues.length() - 1) "Hoàn tất bài học" else "Câu tiếp theo")
                        }
                    }
                } else SoftChip("Đang tải bài học…")
                Spacer(Modifier.height(10.dp))
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Dữ liệu và tiện ích
// ---------------------------------------------------------------------------

private data class AnswerOption(val id: String, val label: String)

private enum class MimiMood { Talking, Happy, Cheer }

private enum class OptionVisual { Idle, Picked, Correct, Wrong, Dimmed }

/** org.json trả về chữ "null" khi giá trị là null, nên phải kiểm tra isNull trước. */
private fun JSONObject.stringOrNull(key: String): String? =
    if (isNull(key)) null else optString(key).takeIf { it.isNotBlank() }

private fun visualFor(optionId: String, selectedId: String?, isCorrect: Boolean?): OptionVisual = when {
    selectedId == null -> OptionVisual.Idle
    optionId != selectedId -> OptionVisual.Dimmed
    isCorrect == true -> OptionVisual.Correct
    isCorrect == false -> OptionVisual.Wrong
    else -> OptionVisual.Picked
}

// ---------------------------------------------------------------------------
// Rung và âm thanh khi bấm đáp án
//  - Âm thanh: res/raw/sfx_tap.wav, sfx_correct.wav, sfx_try_again.wav (SoundPool, độ trễ thấp)
//  - Rung: Vibrator cần quyền VIBRATE trong AndroidManifest. Nếu thiếu quyền hoặc máy
//    không có động cơ rung thì tự chuyển sang rung hệ thống của Compose, không bị lỗi.
// ---------------------------------------------------------------------------
private class LearningEffects(context: Context, private val fallbackHaptic: () -> Unit) {
    private val appContext = context.applicationContext

    private val soundPool: SoundPool = SoundPool.Builder()
        .setMaxStreams(3)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        .build()
    private val tapSound = soundPool.load(appContext, R.raw.sfx_tap, 1)
    private val correctSound = soundPool.load(appContext, R.raw.sfx_correct, 1)
    private val tryAgainSound = soundPool.load(appContext, R.raw.sfx_try_again, 1)

    @Suppress("DEPRECATION")
    private val vibrator: Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (appContext.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            appContext.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    /** Vừa chạm vào đáp án: rung ngắn + tiếng "pop". */
    fun onTap() {
        soundPool.play(tapSound, 0.9f, 0.9f, 1, 0, 1f)
        vibrate(longArrayOf(0, 30))
    }

    /** Đúng: chuông đi lên + rung hai nhịp vui. */
    fun onCorrect() {
        soundPool.play(correctSound, 1f, 1f, 1, 0, 1f)
        vibrate(longArrayOf(0, 40, 70, 40, 70, 90))
    }

    /** Chưa đúng: tiếng nhẹ + một nhịp rung êm, không gây giật mình. */
    fun onTryAgain() {
        soundPool.play(tryAgainSound, 0.8f, 0.8f, 1, 0, 1f)
        vibrate(longArrayOf(0, 80))
    }

    fun release() {
        soundPool.release()
    }

    @Suppress("DEPRECATION")
    private fun vibrate(timings: LongArray) {
        val v = vibrator
        if (v == null || !v.hasVibrator()) {
            fallbackHaptic()
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                v.vibrate(VibrationEffect.createWaveform(timings, -1))
            } else {
                v.vibrate(timings, -1)
            }
        } catch (e: Exception) {
            fallbackHaptic()
        }
    }
}

// ---------------------------------------------------------------------------
// Giao diện
// ---------------------------------------------------------------------------

/** Nền dễ thương (đồng hoa, mây, nhà nhỏ) thay cho nền trắng, phủ nhẹ màu hồng sữa để dễ đọc chữ. */
@Composable
private fun LearningBackground(content: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize()) {
        Image(painterResource(R.drawable.learning_bg), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(listOf(Color(0x22FFF3F8), Color(0x55FFF3F8)))
            )
        )
        content()
    }
}

@Composable
private fun SoftChip(text: String, color: Color = Color(0xFF23396E)) {
    Box(
        Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.88f))
            .padding(horizontal = 14.dp, vertical = 6.dp)
    ) {
        Text(text, color = color, fontWeight = FontWeight.Bold, fontSize = 15.sp)
    }
}

@Composable
private fun CueProgressStrip(cueCount: Int, currentCue: Int, answeredIndices: Set<Int>) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.7f)).padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically
    ) {
        for (index in 0 until cueCount) {
            val isCurrent = index == currentCue
            Box(
                Modifier.padding(horizontal = 3.dp).size(if (isCurrent) 25.dp else 14.dp)
                    .clip(CircleShape).background(
                        if (index in answeredIndices) Color(0xFFEF4E91)
                        else if (isCurrent) Color(0xFFFF9BC3) else Color(0xFFDCE2F1)
                    ),
                contentAlignment = Alignment.Center
            ) {
                if (isCurrent || index in answeredIndices) Text("${index + 1}", color = Color.White, fontSize = 9.sp, fontWeight = FontWeight.Bold)
            }
            if (index < cueCount - 1) Box(Modifier.width(14.dp).height(2.dp).background(Color(0xFFE0E5F1)))
        }
    }
}

@Composable
private fun LessonMediaPanel() {
    // storageRef is opaque and the backend does not yet provide a child playback URL.
    Box(Modifier.fillMaxWidth().height(224.dp).clip(RoundedCornerShape(22.dp))) {
        Image(painterResource(R.drawable.family_picnic_bg), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color(0x33051743), Color(0xCC071A48)))))
        Column(Modifier.align(Alignment.Center).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.size(54.dp).clip(CircleShape).background(Color.White.copy(alpha = .92f)), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.PlayArrow, null, tint = Color(0xFFEB438A), modifier = Modifier.size(38.dp))
            }
            Spacer(Modifier.height(8.dp))
            Text("Video bài học", color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
            Text("Video chưa được cung cấp để phát trên ứng dụng", color = Color.White, fontSize = 11.sp, textAlign = TextAlign.Center)
        }
    }
}

/** Mimi: lắc lư nhẹ khi nói, nhảy lên + tim khi bé làm đúng, nghiêng đầu + cổ vũ khi chưa đúng. */
@Composable
private fun MimiAvatar(mood: MimiMood) {
    val bobTransition = rememberInfiniteTransition(label = "mimi_bob")
    val bob by bobTransition.animateFloat(
        initialValue = -3f,
        targetValue = 3f,
        animationSpec = infiniteRepeatable(
            animation = tween(1100, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "bob"
    )
    val jump = remember { Animatable(0f) }
    val tilt = remember { Animatable(0f) }
    val pop = remember { Animatable(1f) }
    // đếm số lần Mimi phản hồi để đổi luân phiên 2 biểu cảm cho đỡ nhàm
    var reactionCount by remember { mutableStateOf(0) }

    LaunchedEffect(mood) {
        if (mood != MimiMood.Talking) {
            reactionCount++
            pop.snapTo(0.7f)
            pop.animateTo(1f, spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessMedium))
        } else pop.snapTo(1f)
        when (mood) {
            MimiMood.Happy -> {
                repeat(2) {
                    jump.animateTo(-18f, tween(150, easing = FastOutSlowInEasing))
                    jump.animateTo(0f, tween(150, easing = FastOutSlowInEasing))
                }
                tilt.animateTo(-10f, tween(110))
                tilt.animateTo(10f, tween(110))
                tilt.animateTo(0f, tween(110))
            }
            MimiMood.Cheer -> {
                tilt.animateTo(-8f, tween(160))
                tilt.animateTo(8f, tween(160))
                tilt.animateTo(0f, tween(160))
            }
            MimiMood.Talking -> {
                jump.snapTo(0f)
                tilt.snapTo(0f)
            }
        }
    }

    Box(Modifier.size(96.dp)) {
        // Mimi đổi biểu cảm theo tình huống
        val face = when (mood) {
            MimiMood.Talking -> R.drawable.mimi_think                                   // đang hỏi bé
            MimiMood.Happy -> if (reactionCount % 2 == 0) R.drawable.mimi_love else R.drawable.mimi_cheer // bé đúng
            MimiMood.Cheer -> if (reactionCount % 2 == 0) R.drawable.mimi_think else R.drawable.mimi_shy  // bé chưa đúng
        }
        Crossfade(targetState = face, animationSpec = tween(220), label = "mimi_face", modifier = Modifier.fillMaxSize()) { res ->
            Image(
                painterResource(res), "Ong Mimi",
                Modifier.fillMaxSize().graphicsLayer {
                    translationY = (bob + jump.value).dp.toPx()
                    rotationZ = tilt.value
                    scaleX = pop.value
                    scaleY = pop.value
                },
                contentScale = ContentScale.Fit
            )
        }
        AnimatedVisibility(
            visible = mood == MimiMood.Cheer,
            enter = scaleIn(spring(dampingRatio = Spring.DampingRatioMediumBouncy)) + fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.TopEnd)
        ) {
            Text("💪", fontSize = 26.sp)
        }
    }
}

@Composable
private fun MimiDialogueBubble(text: String, companionText: String? = null, mood: MimiMood = MimiMood.Talking) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        MimiAvatar(mood)
        Spacer(Modifier.width(4.dp))
        Card(
            Modifier.weight(1f),
            shape = RoundedCornerShape(topStart = 6.dp, topEnd = 24.dp, bottomEnd = 24.dp, bottomStart = 24.dp),
            colors = CardDefaults.cardColors(containerColor = Color.White.copy(alpha = 0.96f)),
            elevation = CardDefaults.cardElevation(defaultElevation = 6.dp)
        ) {
            AnimatedContent(
                targetState = text to companionText,
                transitionSpec = { fadeIn(tween(250)) togetherWith fadeOut(tween(150)) },
                label = "mimi_text"
            ) { target ->
                Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp)) {
                    Text("Mimi", color = Color(0xFFEB438A), fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Text(target.first, color = Color(0xFF263653), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, lineHeight = 23.sp)
                    target.second?.let { Text(it, color = Color(0xFF78849B), fontSize = 13.sp) }
                }
            }
        }
    }
}

/**
 * Các nút đáp án to, xếp thành hàng ngang (tối đa 3 nút một hàng; từ 4 đáp án trở lên chia 2 nút một hàng).
 */
@Composable
private fun AnswerOptionsRow(
    items: List<AnswerOption>,
    enabled: Boolean,
    selectedOptionId: String?,
    isCorrect: Boolean?,
    onSelect: (String) -> Unit
) {
    if (items.isEmpty()) return
    val perRow = if (items.size <= 3) items.size else 2
    Column(Modifier.fillMaxWidth().padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        items.chunked(perRow).forEachIndexed { rowIndex, rowItems ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                rowItems.forEachIndexed { colIndex, item ->
                    BigAnswerButton(
                        label = item.label,
                        paletteIndex = rowIndex * perRow + colIndex,
                        perRow = perRow,
                        visual = visualFor(item.id, selectedOptionId, isCorrect),
                        enabled = enabled,
                        modifier = Modifier.weight(1f),
                        onClick = { onSelect(item.id) }
                    )
                }
                repeat(perRow - rowItems.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

private val OptionPalettes = listOf(
    listOf(Color(0xFFFFC2DA), Color(0xFFFF8CBC)), // hồng
    listOf(Color(0xFFB5E1FF), Color(0xFF6CC0FF)), // xanh trời
    listOf(Color(0xFFC3F2CF), Color(0xFF74D99A)), // xanh bạc hà
    listOf(Color(0xFFFFEAA5), Color(0xFFFFCB4D))  // vàng
)

private fun optionFontSize(label: String, perRow: Int): TextUnit {
    val length = label.length
    return when {
        length <= 2 -> 56.sp
        length <= 6 -> if (perRow >= 3) 26.sp else 34.sp
        length <= 12 -> if (perRow >= 3) 18.sp else 24.sp
        else -> 16.sp
    }
}

/**
 * Nút đáp án to cho bé: bo tròn, viền trắng dày, mỗi nút một màu kẹo.
 * Đúng: đổi xanh lá, nhún lên + dấu tick. Chưa đúng: đổi cam nhạt, lắc nhẹ. Các nút còn lại mờ đi.
 */
@Composable
private fun BigAnswerButton(
    label: String,
    paletteIndex: Int,
    perRow: Int,
    visual: OptionVisual,
    enabled: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val popScale by animateFloatAsState(
        targetValue = when {
            pressed -> 0.92f
            visual == OptionVisual.Correct -> 1.08f
            visual == OptionVisual.Picked -> 1.04f
            else -> 1f
        },
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessMedium),
        label = "answer_scale"
    )
    val fade by animateFloatAsState(
        targetValue = if (visual == OptionVisual.Dimmed) 0.45f else 1f,
        label = "answer_fade"
    )

    val density = LocalDensity.current.density
    val shake = remember { Animatable(0f) }
    LaunchedEffect(visual) {
        if (visual == OptionVisual.Wrong) {
            repeat(2) {
                shake.animateTo(-6f * density, tween(60))
                shake.animateTo(6f * density, tween(60))
            }
            shake.animateTo(0f, tween(60))
        }
    }

    val colors = when (visual) {
        OptionVisual.Correct -> listOf(Color(0xFFA8F0B8), Color(0xFF3FCB76))
        OptionVisual.Wrong -> listOf(Color(0xFFFFD7B0), Color(0xFFFFA05C))
        else -> OptionPalettes[paletteIndex % OptionPalettes.size]
    }
    val shape = RoundedCornerShape(28.dp)
    val buttonHeight = when (perRow) {
        1 -> 130.dp
        2 -> 150.dp
        else -> 140.dp
    }
    val fontSize = optionFontSize(label, perRow)

    Box(
        modifier = modifier
            .graphicsLayer {
                scaleX = popScale
                scaleY = popScale
                alpha = fade
                translationX = shake.value
            }
            .height(buttonHeight)
            .shadow(8.dp, shape, ambientColor = colors.last(), spotColor = colors.last())
            .clip(shape)
            .background(Brush.verticalGradient(colors))
            .border(4.dp, Color.White, shape)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                enabled = enabled,
                role = Role.Button,
                onClick = onClick
            )
            .padding(10.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            color = Color(0xFF1D2F6F),
            fontSize = fontSize,
            fontWeight = FontWeight.ExtraBold,
            textAlign = TextAlign.Center,
            maxLines = 3
        )
        if (visual == OptionVisual.Correct) {
            Box(
                Modifier.align(Alignment.TopEnd).size(30.dp).clip(CircleShape).background(Color.White),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Filled.Check, null, tint = Color(0xFF1FAE5B), modifier = Modifier.size(22.dp))
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Preview
// ---------------------------------------------------------------------------

@Composable
private fun PreviewHeader() {
    Row(
        Modifier.fillMaxWidth()
            .background(Color.White.copy(alpha = 0.9f), RoundedCornerShape(bottomStart = 24.dp, bottomEnd = 24.dp))
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Filled.ArrowBack, "Quay lại", tint = Color(0xFF1749C8), modifier = Modifier.size(30.dp))
        Column(Modifier.weight(1f).padding(start = 8.dp)) {
            Text("Bài 1. Đếm từ 1 đến 3", color = Color(0xFF173FBD), fontSize = 17.sp, fontWeight = FontWeight.ExtraBold)
            Text("Làm quen với số và đếm", color = Color(0xFF77829A), fontSize = 11.sp)
        }
        Text("2/6", color = Color(0xFFEF4E91), fontWeight = FontWeight.Bold)
    }
}

@Preview(showBackground = true, showSystemUi = true, widthDp = 393, heightDp = 852, name = "Video tương tác")
@Composable
fun LearningScreenPreview() {
    MimiGoTheme {
        LearningBackground {
            Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
                PreviewHeader()
                Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 14.dp, vertical = 10.dp)) {
                    CueProgressStrip(cueCount = 6, currentCue = 1, answeredIndices = setOf(0))
                    Spacer(Modifier.height(10.dp))
                    LessonMediaPanel()
                    Spacer(Modifier.height(10.dp))
                    MimiDialogueBubble("Bây giờ, con hãy chọn quả táo xanh là số mấy nhé?")
                    Spacer(Modifier.height(14.dp))
                    SoftChip("Chọn đáp án nhé!")
                    AnswerOptionsRow(
                        items = listOf(AnswerOption("1", "1"), AnswerOption("2", "2"), AnswerOption("3", "3")),
                        enabled = false, selectedOptionId = null, isCorrect = null, onSelect = {}
                    )
                }
            }
        }
    }
}

@Preview(showBackground = true, showSystemUi = true, widthDp = 393, heightDp = 852, name = "Bé trả lời đúng")
@Composable
fun LearningScreenCorrectPreview() {
    MimiGoTheme {
        LearningBackground {
            Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
                PreviewHeader()
                Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 14.dp, vertical = 10.dp)) {
                    CueProgressStrip(cueCount = 6, currentCue = 1, answeredIndices = setOf(0, 1))
                    Spacer(Modifier.height(10.dp))
                    LessonMediaPanel()
                    Spacer(Modifier.height(10.dp))
                    MimiDialogueBubble("Giỏi quá! Đúng rồi, có 2 quả táo xanh!", "Great job!", MimiMood.Happy)
                    Spacer(Modifier.height(14.dp))
                    AnswerOptionsRow(
                        items = listOf(AnswerOption("1", "1"), AnswerOption("2", "2"), AnswerOption("3", "3")),
                        enabled = false, selectedOptionId = "2", isCorrect = true, onSelect = {}
                    )
                    Spacer(Modifier.height(10.dp))
                    SoftChip("Chính xác!", Color(0xFFEF4E91))
                }
            }
        }
    }
}

@Preview(showBackground = true, showSystemUi = true, widthDp = 393, heightDp = 852, name = "Bé trả lời chưa đúng")
@Composable
fun LearningScreenWrongPreview() {
    MimiGoTheme {
        LearningBackground {
            Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
                PreviewHeader()
                Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 14.dp, vertical = 10.dp)) {
                    CueProgressStrip(cueCount = 6, currentCue = 1, answeredIndices = setOf(0, 1))
                    Spacer(Modifier.height(10.dp))
                    LessonMediaPanel()
                    Spacer(Modifier.height(10.dp))
                    MimiDialogueBubble("Không sao đâu con, mình cùng thử câu tiếp theo nhé!", null, MimiMood.Cheer)
                    Spacer(Modifier.height(14.dp))
                    AnswerOptionsRow(
                        items = listOf(AnswerOption("1", "1"), AnswerOption("2", "2"), AnswerOption("3", "3")),
                        enabled = false, selectedOptionId = "3", isCorrect = false, onSelect = {}
                    )
                    Spacer(Modifier.height(10.dp))
                    SoftChip("Mình thử câu tiếp theo nhé!", Color(0xFFFF9A1F))
                }
            }
        }
    }
}
