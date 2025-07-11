package fr.keyz.register

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import fr.keyz.LocalApiService
import fr.keyz.R
import fr.keyz.components.CheckBoxWithLabel
import fr.keyz.components.ErrorAlert
import fr.keyz.components.Header
import fr.keyz.components.TopText
import fr.keyz.ui.components.OutlinedTextField
import fr.keyz.ui.components.PasswordInput

@Composable
fun RegisterScreen(
    navController: NavController,
) {
    val apiService = LocalApiService.current
    val viewModel = viewModel{
        RegisterViewModel(navController, apiService)
    }
    val registerForm = viewModel.regForm.collectAsState()
    val registerConfirm = viewModel.regConfirm.collectAsState()
    val errors = viewModel.regFormError.collectAsState()

    BackHandler {
        navController.navigate("login")
    }
    Column(
        modifier = Modifier
            .background(MaterialTheme.colorScheme.background)
            .fillMaxSize()
            .padding(10.dp)
            .testTag("registerScreen")
            .verticalScroll(rememberScrollState())
    ) {
        Header()
        TopText(
            stringResource(R.string.create_account), stringResource(R.string.create_account_subtitle),
            limitMarginTop = true,
            noMarginTop = errors.value.apiError != null
        )
        Spacer(modifier = Modifier.height(10.dp))
        ErrorAlert(errors.value.apiError, true)
        Spacer(
            modifier = Modifier.height(if (errors.value.apiError != null) 15.dp else 30.dp)
        )
        Column(
            modifier = Modifier.fillMaxSize().padding(start = 20.dp, end = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            OutlinedTextField(
                label = stringResource(R.string.last_name),
                value = registerForm.value.lastName,
                onValueChange = { value -> viewModel.setLastName(value) },
                modifier = Modifier.fillMaxWidth().testTag("registerLastName"),
                errorMessage = if (errors.value.lastName) stringResource(R.string.last_name_error) else null,
            )
            OutlinedTextField(
                label = stringResource(R.string.first_name),
                value = registerForm.value.firstName,
                onValueChange = { value -> viewModel.setFirstName(value) },
                modifier = Modifier.fillMaxWidth().testTag("registerFirstName"),
                errorMessage = if (errors.value.firstName) stringResource(R.string.first_name_error) else null,
            )
            OutlinedTextField(
                label = stringResource(R.string.your_email),
                value = registerForm.value.email,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                onValueChange = { value -> viewModel.setEmail(value) },
                modifier = Modifier.fillMaxWidth().testTag("registerEmail"),
                errorMessage = if (errors.value.email) stringResource(R.string.email_error) else null,
            )
            PasswordInput(
                label = stringResource(R.string.your_password),
                value = registerForm.value.password,
                onValueChange = { value -> viewModel.setPassword(value) },
                modifier = Modifier.fillMaxWidth().testTag("registerPassword"),
                errorMessage = if (errors.value.password) stringResource(R.string.register_password_error) else null,
                iconButtonTestId = "registerTogglePasswordVisibility",
            )
            PasswordInput(
                label = stringResource(R.string.password_confirm),
                value = registerConfirm.value.password,
                onValueChange = { value -> viewModel.setConfirmPassword(value) },
                modifier = Modifier.fillMaxWidth().testTag("registerPasswordConfirm"),
                errorMessage = if (errors.value.confirmPassword) stringResource(R.string.password_confirm_error) else null,
                iconButtonTestId = "registerToggleConfirmPasswordVisibility",
            )
            CheckBoxWithLabel(
                label = stringResource(R.string.agree_terms),
                isChecked = registerConfirm.value.agreeToTerms,
                onCheckedChange = { value -> viewModel.setAgreeToTerms(value) },
                errorMessage = if (errors.value.agreeToTerms) stringResource(R.string.agree_terms_error) else null,
                modifier = Modifier.testTag("registerAgreeToTerm")
            )
            Button(
                onClick = { viewModel.onSubmit(navController) },
                modifier = Modifier.testTag("registerButton"),
            ) {
                Text(stringResource(R.string.sign_up))
            }
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.already_account), color = MaterialTheme.colorScheme.primary, fontSize = 12.sp)
                Text(
                    AnnotatedString(stringResource(R.string.sign_in)),
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.secondary,
                    modifier = Modifier
                        .padding(start = 3.dp)
                        .clickable { navController.navigate("login") }
                        .testTag("registerScreenToLoginButton"),
                )
            }
        }
    }
}
