package com.mimigo.frontend.ui.screens

import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mimigo.frontend.R
import com.mimigo.frontend.data.MimiGoApi
import com.mimigo.frontend.ui.theme.MimiGoTheme
import java.io.IOException
import org.json.JSONArray
import org.json.JSONObject

private val ProgressPink = Color(0xFFEF4E91)
private val ProgressNavy = Color(0xFF3B3A7A)

private data class LessonProgress(
    val lessonId: String,
    val title: String,
    val state: String,
    val answeredCues: Int,
    val totalCues: Int,
    val lastActivity: String
) {
    val fraction: Float get() = if (totalCues == 0) 0f else (answeredCues.toFloat() / totalCues).coerceIn(0f, 1f)
}

@Composable
fun ProgressScreen(
    childId: String,
    api: MimiGoApi,
    onExit: () -> Unit,
    onLessonClick: (String) -> Unit
) {
    var rows by remember(childId) { mutableStateOf(emptyList<LessonProgress>()) }
    var loading by remember(childId) { mutableStateOf(true) }
    var error by remember(childId) { mutableStateOf<String?>(null) }

    LaunchedEffect(childId, api) {
        loading = true
        error = null
        rows = emptyList()
        try {
            // Workspace is an ordinary mapped route that reports when session items
            // are hidden behind Parent Gate. It is not a score or fabricated history.
            val workspace = api.learningWorkspace()
            if (workspace.toString().contains("PARENT_GATE_REQUIRED", ignoreCase = true)) {
                throw IOException("PARENT_GATE_REQUIRED: Lịch sử học yêu cầu xác minh phụ huynh (Parent Gate).")
            }
            val sessions = api.learningHistory(childId)
            val assembled = mutableListOf<LessonProgress>()
            for (index in 0 until sessions.length()) {
                val session = sessions.optJSONObject(index) ?: continue
                val lessonId = session.optString("lessonId")
                val sessionId = session.optString("sessionId")
                if (lessonId.isBlank() || sessionId.isBlank()) continue

                val detail = api.lesson(childId, lessonId)
                val cues = detail.optJSONArray("cues") ?: JSONArray()
                val sessionDetail = api.learningSession(childId, sessionId)
                val answers = sessionDetail.optJSONArray("answers") ?: JSONArray()
                val answered = (0 until answers.length()).mapNotNull { answerIndex ->
                    answers.optJSONObject(answerIndex)?.optString("cueId")?.takeIf { it.isNotBlank() }
                }.toSet().size

                assembled += LessonProgress(
                    lessonId = lessonId,
                    title = session.optString("lessonTitle").takeIf { it.isNotBlank() && it != "null" }
                        ?: detail.optString("title", "Bài học"),
                    state = session.optString("state"),
                    answeredCues = answered,
                    totalCues = cues.length(),
                    lastActivity = session.optString("lastActivityAt")
                )
            }
            rows = assembled
        } catch (exception: Exception) {
            error = exception.message ?: "Không thể tải tiến độ học lúc này."
        } finally {
            loading = false
        }
    }

    Column(Modifier.fillMaxSize().background(Color(0xFFFFF6FA))) {
        Row(
            Modifier.fillMaxWidth().shadow(5.dp, RoundedCornerShape(bottomStart = 24.dp, bottomEnd = 24.dp))
                .background(Color.White).padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Filled.ArrowBack, "Quay lại", tint = ProgressPink,
                modifier = Modifier.clip(CircleShape).clickable(onClick = onExit).padding(6.dp).size(28.dp))
            Column(Modifier.weight(1f).padding(start = 10.dp)) {
                Text("Tiến độ của bé", color = ProgressNavy, fontSize = 20.sp, fontWeight = FontWeight.ExtraBold)
                Text("Mỗi cue là một bước con khám phá! 🐝", color = Color(0xFF8991A8), fontSize = 12.sp)
            }
            Text("⭐", fontSize = 27.sp)
        }

        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 14.dp)) {
            Box(Modifier.fillMaxWidth().height(142.dp).clip(RoundedCornerShape(26.dp))) {
                Image(painterResource(R.drawable.family_picnic_bg), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                Box(Modifier.fillMaxSize().background(Brush.horizontalGradient(listOf(Color(0xCCFF6EA6), Color(0x665E83F5)))))
                Column(Modifier.align(Alignment.CenterStart).padding(start = 18.dp, end = 122.dp)) {
                    Text("Con đang tiến bộ mỗi ngày!", color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp)
                    Text("Cùng Mimi xem lại những bài học nhé", color = Color.White, fontSize = 12.sp)
                }
                Image(painterResource(R.drawable.mimi_happy), "Ong Mimi", Modifier.align(Alignment.BottomEnd).padding(end = 8.dp).size(112.dp), contentScale = ContentScale.Fit)
            }

            Text("Bài học của con", Modifier.padding(top = 20.dp, bottom = 10.dp), color = ProgressNavy, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold)
            when {
                loading -> Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = ProgressPink)
                }
                error != null -> {
                    val gateBlocked = error.orEmpty().contains("PARENT_GATE_REQUIRED", ignoreCase = true) ||
                        error.orEmpty().contains("Parent Gate", ignoreCase = true)
                    InfoCard(
                        icon = if (gateBlocked) "🔒" else "🐝",
                        title = if (gateBlocked) "Lịch sử học đang được bảo vệ" else "Chưa tải được tiến độ",
                        body = if (gateBlocked) "Backend yêu cầu xác minh phụ huynh (Parent Gate) để xem lịch sử. Sau khi luồng xác minh được bật, tên bài, video và tiến độ từng cue sẽ hiện ở đây." else error.orEmpty()
                    )
                }
                rows.isEmpty() -> InfoCard("🌱", "Chưa có bài học nào", "Khi con bắt đầu học, video, tên bài và thanh tiến độ cue sẽ xuất hiện tại đây.")
                else -> rows.forEach { item -> ProgressLessonCard(item) { onLessonClick(item.lessonId) } }
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun InfoCard(icon: String, title: String, body: String) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(Color.White)
            .border(1.dp, Color(0xFFFFD8E7), RoundedCornerShape(24.dp)).padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(icon, fontSize = 34.sp)
        Text(title, Modifier.padding(top = 8.dp), color = ProgressNavy, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, textAlign = TextAlign.Center)
        Text(body, Modifier.padding(top = 5.dp), color = Color(0xFF818BA2), fontSize = 13.sp, textAlign = TextAlign.Center, lineHeight = 19.sp)
    }
}

@Composable
private fun ProgressLessonCard(item: LessonProgress, onClick: () -> Unit) {
    val completed = item.state == "COMPLETED"
    Column(
        Modifier.fillMaxWidth().padding(bottom = 12.dp).shadow(5.dp, RoundedCornerShape(24.dp))
            .clip(RoundedCornerShape(24.dp)).background(Color.White).clickable(onClick = onClick).padding(12.dp)
    ) {
        Box(Modifier.fillMaxWidth().height(158.dp).clip(RoundedCornerShape(18.dp))) {
            Image(painterResource(R.drawable.family_picnic_bg), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            Box(Modifier.fillMaxSize().background(Color(0x33252B63)))
            Box(Modifier.align(Alignment.Center).size(52.dp).shadow(4.dp, CircleShape).background(ProgressPink, CircleShape), contentAlignment = Alignment.Center) {
                Text("▶", color = Color.White, fontSize = 22.sp)
            }
            Text(if (completed) "✅ Hoàn thành" else "📖 Đang học", Modifier.align(Alignment.BottomStart).padding(9.dp)
                .clip(CircleShape).background(Color.White.copy(alpha = .95f)).padding(horizontal = 10.dp, vertical = 5.dp),
                color = ProgressNavy, fontSize = 11.sp, fontWeight = FontWeight.Bold)
        }
        Text(item.title, Modifier.padding(top = 11.dp), color = ProgressNavy, fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
        Row(Modifier.fillMaxWidth().padding(top = 9.dp, bottom = 6.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("Tiến độ câu hỏi", color = Color(0xFF778198), fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            Text("${item.answeredCues}/${item.totalCues} cue", color = ProgressPink, fontSize = 12.sp, fontWeight = FontWeight.ExtraBold)
        }
        LinearProgressIndicator(
            progress = { item.fraction }, modifier = Modifier.fillMaxWidth().height(10.dp).clip(CircleShape),
            color = if (completed) Color(0xFF45C78B) else ProgressPink,
            trackColor = Color(0xFFFFE3EF)
        )
        Text(if (completed) "Con đã hoàn thành bài này! 🎉" else "Chạm để tiếp tục học cùng Mimi →",
            Modifier.padding(top = 7.dp), color = if (completed) Color(0xFF28A774) else Color(0xFF818BA2), fontSize = 11.sp)
    }
}

@Preview(showBackground = true, showSystemUi = true, name = "Tiến độ học - bài và cue")
@Composable
fun ProgressScreenPreview() {
    MimiGoTheme {
        Column(Modifier.fillMaxSize().background(Color(0xFFFFF6FA))) {
            Row(
                Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Filled.ArrowBack, "Quay lại", tint = ProgressPink, modifier = Modifier.size(28.dp))
                Column(Modifier.weight(1f).padding(start = 10.dp)) {
                    Text("Tiến độ của bé", color = ProgressNavy, fontSize = 20.sp, fontWeight = FontWeight.ExtraBold)
                    Text("Mỗi cue là một bước con khám phá! 🐝", color = Color(0xFF8991A8), fontSize = 12.sp)
                }
                Text("⭐", fontSize = 27.sp)
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 14.dp)) {
                Box(Modifier.fillMaxWidth().height(142.dp).clip(RoundedCornerShape(26.dp))) {
                    Image(painterResource(R.drawable.family_picnic_bg), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                    Box(Modifier.fillMaxSize().background(Brush.horizontalGradient(listOf(Color(0xCCFF6EA6), Color(0x665E83F5)))))
                    Column(Modifier.align(Alignment.CenterStart).padding(start = 18.dp, end = 122.dp)) {
                        Text("Con đang tiến bộ mỗi ngày!", color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp)
                        Text("Cùng Mimi xem lại những bài học nhé", color = Color.White, fontSize = 12.sp)
                    }
                    Image(painterResource(R.drawable.mimi_happy), "Ong Mimi", Modifier.align(Alignment.BottomEnd).padding(end = 8.dp).size(112.dp), contentScale = ContentScale.Fit)
                }
                Text("Bài học của con", Modifier.padding(top = 20.dp, bottom = 10.dp), color = ProgressNavy, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold)
                ProgressLessonCard(
                    LessonProgress("preview-lesson", "Bài 1. Đếm từ 1 đến 3", "IN_PROGRESS", 2, 6, ""),
                    onClick = {}
                )
                ProgressLessonCard(
                    LessonProgress("preview-complete", "Bài 2. Màu sắc quanh em", "COMPLETED", 5, 5, ""),
                    onClick = {}
                )
            }
        }
    }
}
