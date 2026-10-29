package com.mimigo.frontend.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mimigo.frontend.ui.theme.MimiNavyText
import com.mimigo.frontend.ui.theme.MimiPink
import com.mimigo.frontend.ui.theme.TextSecondary

/**
 * Section containing Bee Mimi mascot on left and Speech Bubble on right
 */
@Composable
fun BeeAndSpeechBubbleSection(
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Bee Mascot Canvas Graphic
        BeeMascotIllustration(
            modifier = Modifier.size(width = 150.dp, height = 160.dp)
        )

        Spacer(modifier = Modifier.width(4.dp))

        // Speech Bubble Box
        SpeechBubble(
            modifier = Modifier.weight(1f)
        )
    }
}

/**
 * Cloud Speech Bubble
 */
@Composable
fun SpeechBubble(
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .shadow(
                elevation = 6.dp,
                shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp, bottomEnd = 24.dp, bottomStart = 8.dp),
                ambientColor = Color(0x1A000000),
                spotColor = Color(0x2A000000)
            )
            .clip(RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp, bottomEnd = 24.dp, bottomStart = 8.dp))
            .background(Color.White)
            .padding(horizontal = 16.dp, vertical = 14.dp)
    ) {
        Column {
            // Header: "Bắt đầu hành trình cùng MimiGo"
            Text(
                text = buildAnnotatedString {
                    withStyle(
                        style = SpanStyle(
                            color = MimiNavyText,
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 17.sp
                        )
                    ) {
                        append("Bắt đầu hành trình\n")
                    }
                    withStyle(
                        style = SpanStyle(
                            color = MimiPink,
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 18.sp
                        )
                    ) {
                        append("cùng MimiGo")
                    }
                },
                lineHeight = 22.sp
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Subtitle
            Text(
                text = "Học qua những câu chuyện nhỏ, cho những bước tiến lớn của con.",
                color = TextSecondary,
                fontSize = 12.5.sp,
                fontWeight = FontWeight.Normal,
                lineHeight = 17.sp
            )
        }
    }
}

/**
 * Full Bee Mimi Mascot drawn on Canvas
 */
@Composable
fun BeeMascotIllustration(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height

        // Colors
        val yellowGrad = Brush.verticalGradient(listOf(Color(0xFFFFF176), Color(0xFFFFCA28)))
        val darkBrown = Color(0xFF3E2723)
        val pinkWings = Color(0xCCFF80AB)
        val pinkCheeks = Color(0xFFFF4081)
        val satchelBrown = Color(0xFF8D6E63)
        val flowerPink = Color(0xFFFF4081)

        // 1. Wings (Left & Right Pink Fairy Wings)
        val leftWing = Path().apply {
            moveTo(w * 0.35f, h * 0.45f)
            cubicTo(w * 0.05f, h * 0.25f, -w * 0.05f, h * 0.55f, w * 0.25f, h * 0.65f)
            close()
        }
        val rightWing = Path().apply {
            moveTo(w * 0.65f, h * 0.45f)
            cubicTo(w * 0.95f, h * 0.25f, w * 1.05f, h * 0.55f, w * 0.75f, h * 0.65f)
            close()
        }
        drawPath(leftWing, pinkWings)
        drawPath(rightWing, pinkWings)
        drawPath(leftWing, Color.White.copy(alpha = 0.5f), style = Stroke(width = 3f))
        drawPath(rightWing, Color.White.copy(alpha = 0.5f), style = Stroke(width = 3f))

        // 2. Body (Striped Oval)
        val bodyBounds = Rect(w * 0.28f, h * 0.48f, w * 0.72f, h * 0.88f)
        drawOval(yellowGrad, topLeft = bodyBounds.topLeft, size = bodyBounds.size)

        // Dark stripes on body
        val stripe1 = Path().apply {
            addRoundRect(
                RoundRect(
                    rect = Rect(w * 0.31f, h * 0.58f, w * 0.69f, h * 0.65f),
                    cornerRadius = CornerRadius(10f, 10f)
                )
            )
        }
        val stripe2 = Path().apply {
            addRoundRect(
                RoundRect(
                    rect = Rect(w * 0.33f, h * 0.72f, w * 0.67f, h * 0.79f),
                    cornerRadius = CornerRadius(10f, 10f)
                )
            )
        }
        drawPath(stripe1, darkBrown)
        drawPath(stripe2, darkBrown)

        // 3. Satchel / Flower Bag Strap
        drawLine(
            color = satchelBrown,
            start = Offset(w * 0.35f, h * 0.5f),
            end = Offset(w * 0.65f, h * 0.78f),
            strokeWidth = 8f,
            cap = StrokeCap.Round
        )
        // Satchel Bag with Flower
        drawCircle(color = satchelBrown, radius = 12f, center = Offset(w * 0.62f, h * 0.76f))
        drawCircle(color = flowerPink, radius = 7f, center = Offset(w * 0.62f, h * 0.76f))
        drawCircle(color = Color.White, radius = 3f, center = Offset(w * 0.62f, h * 0.76f))

        // 4. Head
        val headCenter = Offset(w * 0.5f, h * 0.32f)
        val headRadius = w * 0.28f
        drawCircle(brush = yellowGrad, radius = headRadius, center = headCenter)

        // Antennae
        val leftAntenna = Path().apply {
            moveTo(w * 0.42f, h * 0.15f)
            cubicTo(w * 0.38f, h * 0.05f, w * 0.32f, h * 0.05f, w * 0.30f, h * 0.08f)
        }
        val rightAntenna = Path().apply {
            moveTo(w * 0.58f, h * 0.15f)
            cubicTo(w * 0.62f, h * 0.05f, w * 0.68f, h * 0.05f, w * 0.70f, h * 0.08f)
        }
        drawPath(leftAntenna, darkBrown, style = Stroke(width = 6f, cap = StrokeCap.Round))
        drawPath(rightAntenna, darkBrown, style = Stroke(width = 6f, cap = StrokeCap.Round))
        drawCircle(color = Color(0xFFFFD54F), radius = 8f, center = Offset(w * 0.30f, h * 0.08f))
        drawCircle(color = Color(0xFFFFD54F), radius = 8f, center = Offset(w * 0.70f, h * 0.08f))

        // Eyes (Right eye open shiny, Left eye winking cheerful arc)
        // Right Eye
        val rightEyeCenter = Offset(w * 0.61f, h * 0.30f)
        drawCircle(color = darkBrown, radius = 11f, center = rightEyeCenter)
        drawCircle(color = Color.White, radius = 4f, center = Offset(w * 0.59f, h * 0.28f)) // Sparkle

        // Left Eye (Winking Arc)
        val winkPath = Path().apply {
            moveTo(w * 0.34f, h * 0.31f)
            cubicTo(w * 0.39f, h * 0.25f, w * 0.44f, h * 0.25f, w * 0.48f, h * 0.31f)
        }
        drawPath(winkPath, darkBrown, style = Stroke(width = 5f, cap = StrokeCap.Round))

        // Blushing Cheeks
        drawCircle(color = pinkCheeks.copy(alpha = 0.5f), radius = 10f, center = Offset(w * 0.32f, h * 0.37f))
        drawCircle(color = pinkCheeks.copy(alpha = 0.5f), radius = 10f, center = Offset(w * 0.68f, h * 0.37f))

        // Cute Open Smile Mouth
        val smilePath = Path().apply {
            moveTo(w * 0.42f, h * 0.38f)
            cubicTo(w * 0.48f, h * 0.46f, w * 0.52f, h * 0.46f, w * 0.58f, h * 0.38f)
        }
        drawPath(smilePath, darkBrown, style = Stroke(width = 5f, cap = StrokeCap.Round))

        // 5. Waving Hand (Right Hand)
        val handPath = Path().apply {
            moveTo(w * 0.7f, h * 0.52f)
            cubicTo(w * 0.85f, h * 0.42f, w * 0.88f, h * 0.38f, w * 0.82f, h * 0.34f)
        }
        drawPath(handPath, darkBrown, style = Stroke(width = 10f, cap = StrokeCap.Round))
        drawCircle(color = Color(0xFFFFCA28), radius = 10f, center = Offset(w * 0.82f, h * 0.34f))
    }
}
