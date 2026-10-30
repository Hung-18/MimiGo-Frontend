package com.mimigo.frontend.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mimigo.frontend.ui.theme.MimiNavyText
import com.mimigo.frontend.ui.theme.TextSubtle

/**
 * Container with 3 feature columns side by side inside a white rounded card
 */
@Composable
fun FeatureCardBox(
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .shadow(
                elevation = 8.dp,
                shape = RoundedCornerShape(24.dp),
                ambientColor = Color(0x15000000),
                spotColor = Color(0x20000000)
            )
            .clip(RoundedCornerShape(24.dp))
            .background(Color.White)
            .padding(vertical = 18.dp, horizontal = 12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.Top
        ) {
            // Feature 1: Video tương tác
            FeatureItem(
                modifier = Modifier.weight(1f),
                icon = { PlayIconCircle(modifier = Modifier.size(52.dp)) },
                title = "Video\ntương tác sinh động",
                subtitle = "Học mà như chơi"
            )

            // Feature 2: Phát triển toàn diện
            FeatureItem(
                modifier = Modifier.weight(1f),
                icon = { ChartIconCircle(modifier = Modifier.size(52.dp)) },
                title = "Phát triển\ntoàn diện 3 - 6 tuổi",
                subtitle = "Theo độ tuổi và năng lực"
            )

            // Feature 3: Nội dung an toàn
            FeatureItem(
                modifier = Modifier.weight(1f),
                icon = { ShieldIconCircle(modifier = Modifier.size(52.dp)) },
                title = "Nội dung an toàn,\nchuẩn khoa học",
                subtitle = "Được chuyên gia giáo dục\nthẩm định"
            )
        }
    }
}

/**
 * Single Feature Column item
 */
@Composable
fun FeatureItem(
    icon: @Composable () -> Unit,
    title: String,
    subtitle: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.padding(horizontal = 2.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        icon()

        Spacer(modifier = Modifier.height(10.dp))

        Text(
            text = title,
            color = MimiNavyText,
            fontSize = 12.5.sp,
            fontWeight = FontWeight.ExtraBold,
            textAlign = TextAlign.Center,
            lineHeight = 16.sp
        )

        Spacer(modifier = Modifier.height(4.dp))

        Text(
            text = subtitle,
            color = TextSubtle,
            fontSize = 10.5.sp,
            fontWeight = FontWeight.Normal,
            textAlign = TextAlign.Center,
            lineHeight = 14.sp
        )
    }
}

/**
 * Feature 1 Icon: Pink Play Button Circle
 */
@Composable
fun PlayIconCircle(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .shadow(4.dp, CircleShape, ambientColor = Color(0xFFFF4081), spotColor = Color(0xFFFF80AB))
            .clip(CircleShape)
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(Color(0xFFFF80AB), Color(0xFFFF4081), Color(0xFFE91E63))
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.size(22.dp)) {
            val w = size.width
            val h = size.height
            val playPath = Path().apply {
                moveTo(w * 0.25f, h * 0.15f)
                lineTo(w * 0.85f, h * 0.5f)
                lineTo(w * 0.25f, h * 0.85f)
                close()
            }
            drawPath(playPath, Color.White)
        }
    }
}

/**
 * Feature 2 Icon: Green Bar Chart Circle
 */
@Composable
fun ChartIconCircle(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .shadow(4.dp, CircleShape, ambientColor = Color(0xFF4CAF50), spotColor = Color(0xFF81C784))
            .clip(CircleShape)
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(Color(0xFF81C784), Color(0xFF4CAF50), Color(0xFF2E7D32))
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.size(24.dp)) {
            val w = size.width
            val h = size.height
            // 3 Vertical Bars
            val bar1 = Path().apply {
                addRoundRect(RoundRect(Rect(w * 0.15f, h * 0.45f, w * 0.33f, h * 0.82f), CornerRadius(4f, 4f)))
            }
            val bar2 = Path().apply {
                addRoundRect(RoundRect(Rect(w * 0.41f, h * 0.22f, w * 0.59f, h * 0.82f), CornerRadius(4f, 4f)))
            }
            val bar3 = Path().apply {
                addRoundRect(RoundRect(Rect(w * 0.67f, h * 0.35f, w * 0.85f, h * 0.82f), CornerRadius(4f, 4f)))
            }
            drawPath(bar1, Color.White)
            drawPath(bar2, Color.White)
            drawPath(bar3, Color.White)
        }
    }
}

/**
 * Feature 3 Icon: Shield with Heart Circle (Gold/Yellow/Orange)
 */
@Composable
fun ShieldIconCircle(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .shadow(4.dp, CircleShape, ambientColor = Color(0xFFFFB300), spotColor = Color(0xFFFFE082))
            .clip(CircleShape)
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFFF8F00))
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.size(24.dp)) {
            val w = size.width
            val h = size.height

            // Shield Outline Fill
            val shieldPath = Path().apply {
                moveTo(w * 0.5f, h * 0.12f)
                cubicTo(w * 0.75f, h * 0.12f, w * 0.88f, h * 0.25f, w * 0.88f, h * 0.48f)
                cubicTo(w * 0.88f, h * 0.75f, w * 0.5f, h * 0.92f, w * 0.5f, h * 0.92f)
                cubicTo(w * 0.5f, h * 0.92f, w * 0.12f, h * 0.75f, w * 0.12f, h * 0.48f)
                cubicTo(w * 0.12f, h * 0.25f, w * 0.25f, h * 0.12f, w * 0.5f, h * 0.12f)
                close()
            }
            drawPath(shieldPath, Color.White)

            // Inner Heart in Shield
            val heartPath = Path().apply {
                moveTo(w * 0.5f, h * 0.72f)
                cubicTo(w * 0.32f, h * 0.55f, w * 0.28f, h * 0.40f, w * 0.38f, h * 0.32f)
                cubicTo(w * 0.45f, h * 0.26f, w * 0.5f, h * 0.32f, w * 0.5f, h * 0.35f)
                cubicTo(w * 0.5f, h * 0.32f, w * 0.55f, h * 0.26f, w * 0.62f, h * 0.32f)
                cubicTo(w * 0.72f, h * 0.40f, w * 0.68f, h * 0.55f, w * 0.5f, h * 0.72f)
                close()
            }
            drawPath(
                path = heartPath,
                brush = Brush.verticalGradient(listOf(Color(0xFFFFB300), Color(0xFFFF8F00)))
            )
        }
    }
}
