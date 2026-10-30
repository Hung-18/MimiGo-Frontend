package com.mimigo.frontend.ui.components

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import com.mimigo.frontend.R

/**
 * Nền chung cho màn Welcome và màn Đăng ký: ảnh Mimi bay trên đồng hoa cùng gia đình.
 */
@Composable
fun BackgroundDecor(
    modifier: Modifier = Modifier,
    @DrawableRes backgroundRes: Int = R.drawable.family_picnic_bg,
    content: @Composable () -> Unit
) {
    Box(
        modifier = modifier.fillMaxSize()
    ) {
        // 1. Ảnh nền
        Image(
            painter = painterResource(id = backgroundRes),
            contentDescription = null,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop,
            alignment = Alignment.Center
        )

        // 2. Lớp phủ trắng nhạt, đậm dần xuống dưới để chữ và form dễ đọc
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.White.copy(alpha = 0.05f),
                            Color.White.copy(alpha = 0.25f),
                            Color.White.copy(alpha = 0.45f)
                        )
                    )
                )
        )

        // 3. Nội dung phía trước
        content()
    }
}