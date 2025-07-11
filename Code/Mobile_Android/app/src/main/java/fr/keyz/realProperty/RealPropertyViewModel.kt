package fr.keyz.realProperty

import androidx.compose.runtime.mutableStateListOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.navigation.NavController
import fr.keyz.apiCallerServices.AddPropertyInput
import fr.keyz.apiCallerServices.DetailedProperty
import fr.keyz.apiCallerServices.RealPropertyCallerService
import fr.keyz.apiClient.ApiService
import fr.keyz.utils.Base64Utils
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock


class RealPropertyViewModel(
    navController: NavController,
    apiService: ApiService
) : ViewModel() {
    enum class WhichApiError {
         NONE,
        GET_PROPERTIES,
        ADD_PROPERTY,
        DELETE_PROPERTY
    }
    private val apiCaller = RealPropertyCallerService(apiService, navController)
    private val _isLoading = MutableStateFlow(true)
    private val _propertySelectedDetails = MutableStateFlow<DetailedProperty?>(null)
    private val _apiError = MutableStateFlow(WhichApiError.NONE)
    private val _propertiesMutex = Mutex()

    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    val apiError: StateFlow<WhichApiError> = _apiError.asStateFlow()
    val propertySelectedDetails = _propertySelectedDetails.asStateFlow()
    val properties = mutableStateListOf<DetailedProperty>()

    fun closeError() {
        _apiError.value = WhichApiError.NONE
    }

    private fun getPropertyImage(propertyId : String) {
        viewModelScope.launch {
            try {
                val picture = apiCaller.getPropertyPicture(propertyId)?: return@launch
                val pictureDecoded = Base64Utils.decodeBase64ToImage(picture)
                    ?: throw Exception("Picture is not a valid base64 string")
                _propertiesMutex.withLock {
                    val index = properties.indexOfFirst { it.id == propertyId }
                    if (index != -1) {
                        properties[index] = properties[index].copy(picture = pictureDecoded)
                    }
                }
            } catch (e : Exception) {
                println("error getting property image ${e.message}")
                e.printStackTrace()
            }
        }
    }

    fun getProperties() {
        viewModelScope.launch {
            closeError()
            _isLoading.value = true
            try {
                _propertiesMutex.withLock {
                    properties.clear()
                    properties.addAll(apiCaller.getPropertiesAsDetailedProperties())
                }
                properties.forEach {
                    getPropertyImage(it.id)
                }
            } catch (e : Exception) {
                _apiError.value = WhichApiError.GET_PROPERTIES
                println("error getting properties ${e.message}")
                e.printStackTrace()
            } finally {
                _isLoading.value = false
            }
        }
    }

    suspend fun addProperty(propertyForm: AddPropertyInput) : String {
        _propertiesMutex.withLock {
            try {
                val (id) = apiCaller.addProperty(propertyForm)
                properties.add(propertyForm.toDetailedProperty(id))
                closeError()
                return id
            } catch (e: Exception) {
                _apiError.value = WhichApiError.ADD_PROPERTY
                println("error adding property ${e.message}")
            }
        }
        return ""
    }

    fun deleteProperty(propertyId: String) {

        val index = properties.indexOfFirst { it.id == propertyId }
        if (index == -1) {
            return
        }
        viewModelScope.launch {
            _propertiesMutex.withLock {
                try {
                    _propertySelectedDetails.value = null
                    apiCaller.archiveProperty(propertyId)
                    properties.removeAt(index)
                    closeError()
                } catch (e: Exception) {
                    _apiError.value = WhichApiError.DELETE_PROPERTY
                    println("error deleting property ${e.message}")
                    e.printStackTrace()
                }
            }
        }
    }

    fun setPropertySelectedDetails(propertyId: String) {
        val index = properties.indexOfFirst { it.id == propertyId }
        if (index == -1) {
            return
        }
        _propertySelectedDetails.value = properties[index]
    }

    fun getBackFromDetails(modifiedProperty : DetailedProperty) {
        val index = properties.indexOfFirst { it.id == modifiedProperty.id }
        if (index == -1) {
            return
        }
        properties[index] = modifiedProperty
        _propertySelectedDetails.value = null
    }

    fun setPropertyImage(propertyId: String, image: String) {
        viewModelScope.launch {
            try {
                val pictureDecoded = Base64Utils.decodeBase64ToImage(image)
                _propertiesMutex.withLock {
                    val index = properties.indexOfFirst { it.id == propertyId }
                    if (index != -1) {
                        properties[index] = properties[index].copy(picture = pictureDecoded)
                    }
                }
            } catch (e :Exception) {
                e.printStackTrace()
            }
        }
    }
}
