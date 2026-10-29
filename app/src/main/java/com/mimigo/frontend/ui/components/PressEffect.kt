package com.mimigo.frontend.ui.components

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.interaction.InteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer

/**
 * Hiệu ứng bấm nút: nút thu nhỏ lại khi nhấn xuống và nảy về kích thước cũ khi thả tay.
 * Dùng chung một [InteractionSource] với `clickable` để biết khi nào đang được nhấn.
 */
@Composable
fun Modifier.pressScale(
    interactionSource: InteractionSource,
    pressedScale: Float = 0.93f
): Modifier {
    val isPressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isPressed) pressedScale else 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMedium
        ),
        label = "press_scale"
    )
    return this.graphicsLayer {
        scaleX = scale
        scaleY = scale
    }
}