package com.mimigo.frontend.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColorScheme = lightColorScheme(
    primary = MimiYellow,
    secondary = MimiBlue,
    tertiary = MimiPink,
    background = Color(0xFFF0FBFF),
    surface = Color.White,
    onPrimary = MimiNavyText,
    onSecondary = Color.White,
    onBackground = MimiNavyText,
    onSurface = MimiNavyText
)

@Composable
fun MimiGoTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = LightColorScheme,
        typography = Typography,
        content = content
    )
}
