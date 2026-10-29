package com.mimigo.frontend.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mimigo.frontend.ui.components.AppleRegisterButton
import com.mimigo.frontend.ui.components.BackgroundDecor
import com.mimigo.frontend.ui.components.FeatureCardBox
import com.mimigo.frontend.ui.components.GoogleRegisterButton
import com.mimigo.frontend.ui.components.MimiGoHeader
import com.mimigo.frontend.ui.components.PrimaryRegisterButton
import com.mimigo.frontend.ui.components.SpeechBubble
import com.mimigo.frontend.ui.theme.MimiBlue
import com.mimigo.frontend.ui.theme.MimiGoTheme
import com.mimigo.frontend.ui.theme.TextSecondary

/**
 * MimiGo Welcome & Registration Screen with blurred mimi_bee background
 */
@Composable
fun WelcomeScreen(
    onRegisterClick: () -> Unit = {},
    onGoogleSignInClick: () -> Unit = {},
    onAppleSignInClick: () -> Unit = {},
    onLoginClick: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    BackgroundDecor(modifier = modifier) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .systemBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(modifier = Modifier.height(10.dp))

                // 1. Logo & Subtitle Banner
                MimiGoHeader()

                Spacer(modifier = Modifier.height(16.dp))

                // 2. Speech Bubble (Bee logo removed as requested)
                SpeechBubble(
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(modifier = Modifier.height(20.dp))

                // 3. Feature Cards Box
                FeatureCardBox()

                Spacer(modifier = Modifier.height(24.dp))

                // 4. Action Buttons Stack
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    PrimaryRegisterButton(
                        text = "Đăng ký ngay",
                        onClick = onRegisterClick
                    )

                    GoogleRegisterButton(
                        text = "Đăng ký bằng Google",
                        onClick = onGoogleSignInClick
                    )

                    AppleRegisterButton(
                        text = "Đăng ký bằng Apple",
                        onClick = onAppleSignInClick
                    )
                }
            }

            // 5. Footer: Already have an account? Login
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(top = 20.dp, bottom = 12.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Đã có tài khoản? ",
                        color = TextSecondary,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Medium
                    )
                    Text(
                        text = "Đăng nhập",
                        color = MimiBlue,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        textDecoration = TextDecoration.Underline,
                        modifier = Modifier.clickable { onLoginClick() }
                    )
                }
            }
        }
    }
}

@Preview(showBackground = true, showSystemUi = true, device = "id:pixel_7")
@Composable
fun WelcomeScreenPreview() {
    MimiGoTheme {
        WelcomeScreen()
    }
}
