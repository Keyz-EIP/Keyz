package fr.keyz.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.navigation.NavController
import fr.keyz.apiCallerServices.ApiCallerServiceException
import fr.keyz.apiCallerServices.DashBoard
import fr.keyz.apiCallerServices.DashBoardCallerService
import fr.keyz.apiCallerServices.ProfileCallerService
import fr.keyz.apiClient.ApiService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class DashBoardViewModel(
    private val navController: NavController,
    apiService: ApiService
) : ViewModel() {
    private val _dashBoardApiCaller = DashBoardCallerService(apiService, navController)
    private val _profileApiCaller = ProfileCallerService(apiService, navController)
    private val _isLoading = MutableStateFlow(false)
    private val _dashBoard = MutableStateFlow(DashBoard())
    private val _userName = MutableStateFlow("")
    private val _loadingMutex = Mutex()
    val isLoading = _isLoading.asStateFlow()
    val dashBoard = _dashBoard.asStateFlow()
    val userName = _userName.asStateFlow()

    fun getDashBoard() {
        viewModelScope.launch {
            _loadingMutex.withLock {
                try {
                    _isLoading.value = true
                    val newDashBoard = _dashBoardApiCaller.getDashBoard()
                    _dashBoard.value = newDashBoard
                } catch (e: ApiCallerServiceException) {
                    e.printStackTrace()
                } finally {
                    _isLoading.value = false
                }
            }
        }
    }

    fun getName() {
        viewModelScope.launch {
            try {
                val profile = _profileApiCaller.getProfile()
                _userName.value = "${profile.firstname} ${profile.lastname}"
            } catch(e : ApiCallerServiceException) {
                e.printStackTrace()
            }
        }
    }
}
