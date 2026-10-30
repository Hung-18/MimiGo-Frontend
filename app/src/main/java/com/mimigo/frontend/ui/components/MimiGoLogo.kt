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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mimigo.frontend.ui.theme.MimiNavyText
import kotlin.math.cos
import kotlin.math.sin

/**
 * Top Header section with the 3D colorful "MimiGo" logo and subtitle pill
 */
@Composable
fun MimiGoHeader(
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Logo Text Row
        Box(
            contentAlignment = Alignment.Center
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                // "Mimi" in 3D Yellow/Orange
                Text(
                    text = "Mimi",
                    style = TextStyle(
                        fontFamily = FontFamily.Default,
                        fontWeight = FontWeight.Black,
                        fontSize = 58.sp,
                        brush = Brush.verticalGradient(
                            colors = listOf(
                                Color(0xFFFFF176), // Shiny yellow top
                                Color(0xFFFFC107), // Golden yellow
                                Color(0xFFFF9800)  // Deep orange bottom
                            )
                        ),
                        shadow = Shadow(
                            color = Color(0xFFB74100),
                            offset = Offset(3f, 6f),
                            blurRadius = 0f
                        )
                    )
                )

                // "Go" in 3D Sky Blue/Navy
                Box {
                    Text(
                        text = "Go",
                        style = TextStyle(
                            fontFamily = FontFamily.Default,
                            fontWeight = FontWeight.Black,
                            fontSize = 58.sp,
                            brush = Brush.verticalGradient(
                                colors = listOf(
                                    Color(0xFF4FC3F7), // Light cyan top
                                    Color(0xFF0288D1), // Bright sky blue
                                    Color(0xFF01579B)  // Dark blue bottom
                                )
                            ),
                            shadow = Shadow(
                                color = Color(0xFF002171),
                                offset = Offset(3f, 6f),
                                blurRadius = 0f
                            )
                        )
                    )

                    // Star attached to 'o'
                    CuteStarIcon(
                        modifier = Modifier
                            .size(24.dp)
                            .align(Alignment.TopEnd)
                            .offset(x = 10.dp, y = (-4).dp)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(4.dp))

        // Subtitle Banner Pill ("Cùng Mimi học tập và khám phá! ❤️")
        Box(
            modifier = Modifier
                .shadow(
                    elevation = 4.dp,
                    shape = CircleShape,
                    ambientColor = Color(0x20000000),
                    spotColor = Color(0x30000000)
                )
                .clip(CircleShape)
                .background(Color.White)
                .padding(horizontal = 20.dp, vertical = 8.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Text(
                    text = "Cùng Mimi học tập và khám phá!",
                    color = MimiNavyText,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = " ❤️",
                    fontSize = 14.sp
                )
            }
        }
    }
}

/**
 * Star icon drawn on Canvas
 */
@Composable
fun CuteStarIcon(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val cx = size.width / 2f
        val cy = size.height / 2f
        val outerRadius = size.width / 2f
        val innerRadius = outerRadius * 0.45f

        val path = Path()
        val numPoints = 5
        var angle = -Math.PI / 2.0

        for (i in 0 until numPoints * 2) {
            val r = if (i % 2 == 0) outerRadius else innerRadius
            val x = (cx + r * cos(angle)).toFloat()
            val y = (cy + r * sin(angle)).toFloat()
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
            angle += Math.PI / numPoints
        }
        path.close()

        // Draw star with yellow gradient
        drawPath(
            path = path,
            brush = Brush.verticalGradient(
                colors = listOf(Color(0xFFFFF59D), Color(0xFFFFC107))
            )
        )
    }
}