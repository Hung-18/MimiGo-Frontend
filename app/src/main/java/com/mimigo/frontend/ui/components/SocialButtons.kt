package com.mimigo.frontend.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.material3.ripple
import androidx.compose.runtime.remember
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mimigo.frontend.ui.theme.MimiNavyText

/**
 * Main Pink Primary Action Button ("Đăng ký ngay ->")
 */
@Composable
fun PrimaryRegisterButton(
    text: String = "Đăng ký ngay",
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val interactionSource = remember { MutableInteractionSource() }
    Box(
        modifier = modifier
            .pressScale(interactionSource)
            .fillMaxWidth()
            .height(56.dp)
            .shadow(
                elevation = 8.dp,
                shape = CircleShape,
                ambientColor = Color(0xFFFF4081),
                spotColor = Color(0xFFFF4081)
            )
            .clip(CircleShape)
            .background(
                // Hồng giống nút "Tạo tài khoản" / "Đăng nhập" ở các màn sau
                brush = Brush.horizontalGradient(
                    colors = listOf(Color(0xFFFF6FA5), Color(0xFFFF3D8B))
                )
            )
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(),
                onClick = onClick
            )
            .padding(horizontal = 24.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Text(
                text = text,
                color = Color.White,
                fontSize = 19.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 0.2.sp
            )
            Spacer(modifier = Modifier.width(10.dp))
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}

/**
 * Google Sign-In Button ("Đăng ký bằng Google")
 */
@Composable
fun GoogleRegisterButton(
    text: String = "Đăng ký bằng Google",
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val interactionSource = remember { MutableInteractionSource() }
    Box(
        modifier = modifier
            .pressScale(interactionSource)
            .fillMaxWidth()
            .height(52.dp)
            .shadow(
                elevation = 3.dp,
                shape = CircleShape,
                ambientColor = Color.Black.copy(alpha = 0.05f),
                spotColor = Color.Black.copy(alpha = 0.08f)
            )
            .clip(CircleShape)
            .background(Color.White)
            .border(1.dp, Color(0xFFE2E8F0), CircleShape)
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(),
                onClick = onClick
            )
            .padding(horizontal = 20.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            GoogleIcon(modifier = Modifier.size(22.dp))
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = text,
                color = MimiNavyText,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

/**
 * Apple Sign-In Button ("Đăng ký bằng Apple")
 */
@Composable
fun AppleRegisterButton(
    text: String = "Đăng ký bằng Apple",
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val interactionSource = remember { MutableInteractionSource() }
    Box(
        modifier = modifier
            .pressScale(interactionSource)
            .fillMaxWidth()
            .height(52.dp)
            .shadow(
                elevation = 3.dp,
                shape = CircleShape,
                ambientColor = Color.Black.copy(alpha = 0.05f),
                spotColor = Color.Black.copy(alpha = 0.08f)
            )
            .clip(CircleShape)
            .background(Color.White)
            .border(1.dp, Color(0xFFE2E8F0), CircleShape)
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(),
                onClick = onClick
            )
            .padding(horizontal = 20.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            AppleIcon(modifier = Modifier.size(22.dp))
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = text,
                color = MimiNavyText,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

/**
 * Custom multi-color Google "G" Icon drawn via Canvas
 */
@Composable
fun GoogleIcon(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val width = size.width
        val height = size.height
        val cx = width / 2f
        val cy = height / 2f
        val radius = width / 2f

        // Google Colors
        val red = Color(0xFFEA4335)
        val yellow = Color(0xFFFBBC05)
        val green = Color(0xFF34A853)
        val blue = Color(0xFF4285F4)

        // Red Top Arc
        val pathRed = Path().apply {
            moveTo(cx, cy)
            arcTo(
                rect = Rect(cx - radius, cy - radius, cx + radius, cy + radius),
                startAngleDegrees = -45f,
                sweepAngleDegrees = -135f,
                forceMoveTo = false
            )
            lineTo(cx, cy)
            close()
        }
        drawPath(pathRed, red)

        // Yellow Left Arc
        val pathYellow = Path().apply {
            moveTo(cx, cy)
            arcTo(
                rect = Rect(cx - radius, cy - radius, cx + radius, cy + radius),
                startAngleDegrees = -180f,
                sweepAngleDegrees = -90f,
                forceMoveTo = false
            )
            lineTo(cx, cy)
            close()
        }
        drawPath(pathYellow, yellow)

        // Green Bottom Arc
        val pathGreen = Path().apply {
            moveTo(cx, cy)
            arcTo(
                rect = Rect(cx - radius, cy - radius, cx + radius, cy + radius),
                startAngleDegrees = 90f,
                sweepAngleDegrees = 90f,
                forceMoveTo = false
            )
            lineTo(cx, cy)
            close()
        }
        drawPath(pathGreen, green)

        // Blue Right Arc & Horizontal Bar
        val pathBlue = Path().apply {
            moveTo(cx, cy)
            arcTo(
                rect = Rect(cx - radius, cy - radius, cx + radius, cy + radius),
                startAngleDegrees = 0f,
                sweepAngleDegrees = 90f,
                forceMoveTo = false
            )
            lineTo(cx, cy)
            close()
        }
        drawPath(pathBlue, blue)

        // Inner Cutout
        val innerRadius = radius * 0.55f
        drawCircle(
            color = Color.White,
            radius = innerRadius,
            center = Offset(cx, cy)
        )

        // Blue Horizontal Bar
        val barPath = Path().apply {
            addRect(
                Rect(
                    left = cx,
                    top = cy - innerRadius * 0.45f,
                    right = cx + radius,
                    bottom = cy + innerRadius * 0.45f
                )
            )
        }
        drawPath(barPath, blue)
    }
}

/**
 * Apple Icon drawn via Canvas
 */
@Composable
fun AppleIcon(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height
        val black = Color(0xFF111111)

        // Apple body outline
        val applePath = Path().apply {
            moveTo(w * 0.5f, h * 0.22f)
            cubicTo(w * 0.42f, h * 0.22f, w * 0.32f, h * 0.27f, w * 0.25f, h * 0.27f)
            cubicTo(w * 0.17f, h * 0.27f, w * 0.08f, h * 0.22f, w * 0.02f, h * 0.35f)
            cubicTo(-0.06f, h * 0.53f, w * 0.05f, h * 0.81f, w * 0.2f, h * 0.98f)
            cubicTo(w * 0.27f, h * 1.06f, w * 0.36f, h * 1.01f, w * 0.46f, h * 1.01f)
            cubicTo(w * 0.56f, h * 1.01f, w * 0.63f, h * 1.06f, w * 0.72f, h * 0.98f)
            cubicTo(w * 0.83f, h * 0.85f, w * 0.92f, h * 0.63f, w * 0.92f, h * 0.59f)
            cubicTo(w * 0.91f, h * 0.58f, w * 0.73f, h * 0.51f, w * 0.73f, h * 0.33f)
            cubicTo(w * 0.73f, h * 0.18f, w * 0.86f, h * 0.1f, w * 0.87f, h * 0.09f)
            cubicTo(w * 0.79f, h * -0.01f, w * 0.66f, 0f, w * 0.6f, 0f)
            cubicTo(w * 0.5f, 0f, w * 0.44f, h * 0.05f, w * 0.38f, h * 0.05f)
            close()
        }

        // Apple leaf
        val leafPath = Path().apply {
            moveTo(w * 0.52f, h * 0.18f)
            cubicTo(w * 0.58f, h * 0.1f, w * 0.62f, h * 0.02f, w * 0.6f, 0f)
            cubicTo(w * 0.53f, 0f, w * 0.44f, h * 0.05f, w * 0.4f, h * 0.12f)
            cubicTo(w * 0.35f, h * 0.19f, w * 0.32f, h * 0.28f, w * 0.34f, h * 0.3f)
            cubicTo(w * 0.42f, h * 0.3f, w * 0.51f, h * 0.25f, w * 0.52f, h * 0.18f)
            close()
        }

        drawPath(applePath, black)
        drawPath(leafPath, black)
    }
}