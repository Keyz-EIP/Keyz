package fr.keyz

import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import fr.keyz.apiClient.mockApi.MockedApiService
import fr.keyz.authService.AuthService
import fr.keyz.MainActivity
import fr.keyz.isTesting
import fr.keyz.login.dataStore
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@ExperimentalTestApi
@RunWith(AndroidJUnit4::class)
class ProfileInstrumentedTest {
    constructor() {
        isTesting = true
    }
    @get:Rule
    val mainAct = createAndroidComposeRule<MainActivity>()

    @Before
    fun setup() {
        val dataStore = InstrumentationRegistry.getInstrumentation().targetContext.dataStore
        val authServ = AuthService(dataStore, apiService = MockedApiService())
        try {
            runBlocking {
                authServ.getToken()
                mainAct.onNodeWithTag("loggedBottomBarElement profile").assertIsDisplayed().performClick()
            }
        } catch (e: Exception) {
            runBlocking {
                mainAct.onNodeWithTag("loginEmailInput").performClick().performTextInput("robin.denni@epitech.eu")
                mainAct.onNodeWithTag("loginPasswordInput").performClick().performTextInput("Ttest99&")
                mainAct.onNodeWithTag("loginButton").performClick()
                mainAct.waitUntilAtLeastOneExists(hasTestTag("loggedBottomBarElement profile"), 2000)
                mainAct.onNodeWithTag("loggedBottomBarElement profile").assertIsDisplayed().performClick()
            }
        }
    }

    @Test
    fun useAppContext() {
        val appContext = InstrumentationRegistry.getInstrumentation().targetContext
        assertEquals("fr.keyz", appContext.packageName)
    }

    @Test
    fun canGoToProfile() {
        mainAct.onNodeWithTag("profile").assertIsDisplayed()
    }

    @Test
    fun profileContainsTheGoodDisplayAndButton() {
        mainAct.onNodeWithTag("profile").assertIsDisplayed()
        mainAct.onNodeWithTag("selectButtonLanguage").assertIsDisplayed()
        mainAct.onNodeWithTag("profileLogoutBtn").assertIsDisplayed()
    }

    @Test
    fun profileContainsGoodInfos() {
        mainAct.onNodeWithText("User's informations").assertIsDisplayed()
        mainAct.onNodeWithText("Test").assertIsDisplayed()
        mainAct.onNodeWithText("User").assertIsDisplayed()
        mainAct.onNodeWithText("robin.denni@epitech.eu").assertIsDisplayed()
        mainAct.onNodeWithText("Language").assertIsDisplayed()
        mainAct.onNodeWithText("Logout").assertIsDisplayed()
    }

    @Test
    fun canLogoutWithTheButton() {
        mainAct.onNodeWithTag("profileLogoutBtn").performClick()
        mainAct.waitUntilAtLeastOneExists(hasTestTag("loginEmailInput"), 2000)
    }
}
