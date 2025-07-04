//
//  TenantPropertyViewModel.swift
//  Keyz
//
//  Created by Liebenguth Alessio on 08/06/2025.
//

import SwiftUI
import Foundation

class TenantPropertyViewModel: ObservableObject {
    @Published var damages: [DamageResponse] = []
    @Published var isFetchingDamages = false
    @Published var damagesError: String?
    @Published var rooms: [PropertyRoomsTenant] = []
    private var tenantProperty: Property?
    public var activeLeaseId: String?
    private var isFetchingProperty = false
    private var isFetchingRooms = false
    private var isFetchingLease = false
    weak var propertyViewModel: PropertyViewModel?
    
    func fetchTenantProperty() async throws -> Property {
        if let property = tenantProperty {
            return property
        }
        guard !isFetchingProperty else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Already fetching property data."])
        }
        isFetchingProperty = true
        defer { isFetchingProperty = false }
                
        let url = URL(string: "\(APIConfig.baseURL)/tenant/leases/current/property/")!
        let token = try await TokenStorage.getValidAccessToken()
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            throw NSError(domain: "", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: "Failed with status code: \((response as? HTTPURLResponse)?.statusCode ?? 0) - \(errorBody)".localized()])
        }
        
        let propertyResponse = try await Task.detached(priority: .background) {
            let decoder = JSONDecoder()
            return try decoder.decode(PropertyResponse.self, from: data)
        }.value
        
        async let leaseIdTask = fetchActiveLeaseIdForProperty(propertyId: propertyResponse.id, token: token)
        async let photoTask = fetchPropertiesPicture(propertyId: propertyResponse.id)
        
        let (leaseId, photo) = try await (leaseIdTask, photoTask)
        
        var documents: [PropertyDocument] = []
        var damages: [DamageResponse] = []
        var rooms: [PropertyRoomsTenant] = []
        
        if let leaseId = leaseId {
            async let documentsTask = fetchTenantPropertyDocuments(leaseId: leaseId, propertyId: propertyResponse.id)
            async let damagesTask = fetchTenantDamages(leaseId: leaseId)
            async let roomsTask = fetchPropertyRooms(token: token)
            
            do {
                let (fetchedDocuments, fetchedDamages, fetchedRooms) = try await (documentsTask, damagesTask, roomsTask)
                documents = fetchedDocuments
                damages = fetchedDamages
                rooms = fetchedRooms
                await MainActor.run {
                    self.damages = fetchedDamages
                    self.rooms = fetchedRooms
                }
            } catch {
                print("Error fetching additional tenant data: \(error.localizedDescription)")
            }
        }
        
        let property = Property(
            id: propertyResponse.id,
            ownerID: propertyResponse.ownerId,
            name: propertyResponse.name,
            address: propertyResponse.address,
            city: propertyResponse.city,
            postalCode: propertyResponse.postalCode,
            country: propertyResponse.country,
            photo: photo,
            monthlyRent: propertyResponse.rentalPricePerMonth,
            deposit: propertyResponse.depositPrice,
            surface: propertyResponse.areaSqm,
            isAvailable: propertyResponse.isAvailable,
            tenantName: propertyResponse.lease?.tenantName,
            leaseId: leaseId,
            leaseStartDate: propertyResponse.lease?.startDate,
            leaseEndDate: propertyResponse.lease?.endDate,
            documents: documents,
            createdAt: propertyResponse.createdAt,
            rooms: rooms.map { PropertyRooms(id: $0.id, name: $0.name, checked: false, inventory: []) },
            damages: damages
        )
        
        await MainActor.run {
            self.tenantProperty = property
            self.activeLeaseId = leaseId
            self.objectWillChange.send()
        }
        return property
    }
    
    func fetchPropertyRooms(token: String) async throws -> [PropertyRoomsTenant] {
        if !rooms.isEmpty {
            return rooms
        }
        guard !isFetchingRooms else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Already fetching rooms."])
        }
        isFetchingRooms = true
        defer { isFetchingRooms = false }
                
        let url = URL(string: "\(APIConfig.baseURL)/tenant/leases/current/property/inventory/")!
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server.".localized()])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            switch httpResponse.statusCode {
            case 403:
                throw NSError(domain: "", code: 403, userInfo: [NSLocalizedDescriptionKey: "Property not yours.".localized()])
            case 404:
                print("fetchPropertyRooms: No property inventory found.")
                await MainActor.run {
                    self.rooms = []
                    self.objectWillChange.send()
                }
                return []
            default:
                throw NSError(domain: "", code: httpResponse.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "Failed with status code: \(httpResponse.statusCode) - \(errorBody)".localized()])
            }
        }
        
        let inventoryResponse = try await Task.detached(priority: .background) {
            let decoder = JSONDecoder()
            return try decoder.decode(PropertyInventoryResponse.self, from: data)
        }.value
        
        let fetchedRooms = inventoryResponse.rooms.map { room in
            PropertyRoomsTenant(id: room.id, name: room.name)
        }
        await MainActor.run {
            self.rooms = fetchedRooms
            self.objectWillChange.send()
        }
        return fetchedRooms
    }
    
    func fetchPropertiesPicture(propertyId: String) async throws -> UIImage? {
        if let cachedImage = ImageCache.shared.getImage(forKey: propertyId) {
            return cachedImage
        }

        let url = URL(string: "\(APIConfig.baseURL)/tenant/leases/current/property/picture/")!
        var attemptCount = 0
        let maxAttempts = 2

        while attemptCount < maxAttempts {
            attemptCount += 1
            do {
                let token = try await TokenStorage.getValidAccessToken()
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "GET"
                urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

                let (data, response) = try await URLSession.shared.data(for: urlRequest)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server.".localized()])
                }

                switch httpResponse.statusCode {
                case 200, 201:
                    return try await Task.detached(priority: .background) {
                        let propertyImage = try JSONDecoder().decode(PropertyImageBase64.self, from: data)
                        var base64String = propertyImage.data
                        if base64String.contains(",") {
                            base64String = propertyImage.data.components(separatedBy: ",").last ?? base64String
                        }
                        guard let imageData = Data(base64Encoded: base64String, options: [.ignoreUnknownCharacters]),
                              let image = UIImage(data: imageData) else {
                            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to decode image.".localized()])
                        }
                        ImageCache.shared.setImage(image, forKey: propertyId)
                        return image
                    }.value
                case 204, 403, 404:
                    ImageCache.shared.setImage(nil, forKey: propertyId)
                    return nil
                case 401:
                    if attemptCount == maxAttempts {
                        throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized after \(maxAttempts) attempts.".localized()])
                    }
                    continue
                default:
                    let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                    throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed with status code: \(httpResponse.statusCode) - \(errorBody)".localized()])
                }
            } catch {
                if attemptCount == maxAttempts {
                    throw error
                }
            }
        }
        return nil
    }
    
    func fetchTenantPropertyDocuments(leaseId: String, propertyId: String) async throws -> [PropertyDocument] {
        await MainActor.run {
            self.propertyViewModel?.isFetchingDocuments = true
        }
        defer {
            Task { @MainActor in
                self.propertyViewModel?.isFetchingDocuments = false
            }
        }

        let url = URL(string: "\(APIConfig.baseURL)/tenant/leases/current/docs/")!
        let token = try await TokenStorage.getValidAccessToken()
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 10
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server".localized()])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            throw NSError(domain: "", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Failed with status code: \(httpResponse.statusCode) - \(errorBody)".localized()])
        }
        
        let documents = try await Task.detached(priority: .background) {
            let decoder = JSONDecoder()
            let documentsData = try decoder.decode([PropertyDocumentResponse].self, from: data)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "dd-MM-yyyy"
            
            return documentsData.map { doc in
                let cleanBase64 = doc.data.contains(",") ? doc.data.components(separatedBy: ",").last ?? doc.data : doc.data
                let filename = doc.name
                
                let components = filename.split(separator: "_")
                var title = filename
                
                if let dateString = components.last?.prefix(10),
                   dateFormatter.date(from: String(dateString)) != nil {
                    title = outputFormatter.string(from: dateFormatter.date(from: String(dateString))!)
                }
                
                return PropertyDocument(id: doc.id, title: title, fileName: filename, data: cleanBase64)
            }
        }.value
        
        await MainActor.run {
            if var updatedProperty = self.tenantProperty, updatedProperty.id == propertyId {
                updatedProperty.documents = documents
                self.tenantProperty = updatedProperty
                self.objectWillChange.send()
            }
        }
        
        return documents
    }
    
    @MainActor
    func fetchTenantDamages(leaseId: String, fixed: Bool? = nil) async throws -> [DamageResponse] {
        var urlComponents = URLComponents(string: "\(APIConfig.baseURL)/tenant/leases/current/damages/")!
        
        if let fixed = fixed {
            urlComponents.queryItems = [URLQueryItem(name: "fixed", value: String(fixed))]
        }
        
        guard let url = urlComponents.url else {
            damagesError = "Invalid URL".localized()
            isFetchingDamages = false
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL".localized()])
        }
        
        let token = try await TokenStorage.getValidAccessToken()
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        isFetchingDamages = true
        damagesError = nil
        
//        let startTime = Date()

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server.".localized()])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            switch httpResponse.statusCode {
            case 403:
                throw NSError(domain: "", code: 403, userInfo: [NSLocalizedDescriptionKey: "Lease not yours.".localized()])
            case 404:
                self.damages = []
                objectWillChange.send()
                isFetchingDamages = false
                return []
            case 500:
                throw NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey: "Internal server error: \(errorBody)".localized()])
            default:
                throw NSError(domain: "", code: httpResponse.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "Failed with status code: \(httpResponse.statusCode) - \(errorBody)".localized()])
            }
        }
        
//        let decodeTime = Date()
//        print("Network request took: \(decodeTime.timeIntervalSince(startTime)) seconds")

        let damagesData = try await Task.detached(priority: .background) {
            let decoder = JSONDecoder()
            return try decoder.decode([DamageResponse].self, from: data)
        }.value
        
        self.damages = damagesData
        objectWillChange.send()
        isFetchingDamages = false
//        print("Decoding and UI update took: \(Date().timeIntervalSince(decodeTime)) seconds")
        return damagesData
    }
    
    func fetchActiveLeaseIdForProperty(propertyId: String, token: String) async throws -> String? {
        if let leaseId = activeLeaseId {
            return leaseId
        }
        guard !isFetchingLease else {
            while isFetchingLease {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            return activeLeaseId
        }
        
        isFetchingLease = true
        defer { isFetchingLease = false }
                
        let url = URL(string: "\(APIConfig.baseURL)/tenant/leases/current/")!
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server.".localized()])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            switch httpResponse.statusCode {
            case 403:
                throw NSError(domain: "", code: 403, userInfo: [NSLocalizedDescriptionKey: "Property not yours.".localized()])
            case 404:
                await MainActor.run {
                    self.activeLeaseId = nil
                }
                return nil
            default:
                throw NSError(domain: "", code: httpResponse.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "Failed with status code: \(httpResponse.statusCode) - \(errorBody)".localized()])
            }
        }
        
        let leaseResponse = try await Task.detached(priority: .background) {
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                if let date = dateFormatter.date(from: dateString) {
                    return date
                } else if let date = fallbackFormatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
            }
            return try decoder.decode(LeaseResponse.self, from: data)
        }.value
        
        await MainActor.run {
            if leaseResponse.active && leaseResponse.propertyId == propertyId {
                self.activeLeaseId = leaseResponse.id
            } else {
                self.activeLeaseId = nil
            }
        }
        return leaseResponse.active && leaseResponse.propertyId == propertyId ? leaseResponse.id : nil
    }
    
    func createDamage(propertyId: String, leaseId: String, damage: DamageRequest, token: String) async throws -> String {
        let url = URL(string: "\(APIConfig.baseURL)/tenant/leases/current/damages/")!
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let jsonData = try await Task.detached(priority: .background) {
            try JSONEncoder().encode(damage)
        }.value
        urlRequest.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch code {
            case 400:
                throw NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing fields or bad base64 string: \(errorBody)".localized()])
            case 403:
                throw NSError(domain: "", code: 403, userInfo: [NSLocalizedDescriptionKey: "Invalid data.".localized()])
            case 404:
                throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active lease.".localized()])
            case 500:
                throw NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey: "Internal server error: \(errorBody)".localized()])
            default:
                throw NSError(domain: "", code: code, userInfo: [NSLocalizedDescriptionKey: "Failed with status code: \(code) - \(errorBody)".localized()])
            }
        }
        
        let idResponse = try await Task.detached(priority: .background) {
            try JSONDecoder().decode(IdResponse.self, from: data)
        }.value
        return idResponse.id
    }
    
    private func performFetchActiveLeaseId(propertyId: String, token: String) async {
        guard !isFetchingLease else { return }
        isFetchingLease = true
        defer { isFetchingLease = false }
                
        let url = URL(string: "\(APIConfig.baseURL)/tenant/leases/current/")!
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server.".localized()])
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                switch httpResponse.statusCode {
                case 403:
                    throw NSError(domain: "", code: 403, userInfo: [NSLocalizedDescriptionKey: "Property not yours.".localized()])
                case 404:
                    await MainActor.run {
                        self.activeLeaseId = nil
                    }
                    return
                default:
                    throw NSError(domain: "", code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "Failed with status code: \(httpResponse.statusCode) - \(errorBody)".localized()])
                }
            }
            
            let leaseResponse = try await Task.detached(priority: .background) {
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                let fallbackFormatter = DateFormatter()
                fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    } else if let date = fallbackFormatter.date(from: dateString) {
                        return date
                    }
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
                }
                return try decoder.decode(LeaseResponse.self, from: data)
            }.value
            
            await MainActor.run {
                if leaseResponse.active && leaseResponse.propertyId == propertyId {
                    self.activeLeaseId = leaseResponse.id
                } else {
                    self.activeLeaseId = nil
                }
            }
        } catch {
            await MainActor.run {
                self.activeLeaseId = nil
            }
        }
    }
    
    func fetchDamageByID(damageId: String, token: String) async throws -> DamageResponse {
//        let startTime = Date()

        let url = URL(string: "\(APIConfig.baseURL)/tenant/leases/current/damages/\(damageId)/")!
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server.".localized()])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            switch httpResponse.statusCode {
            case 400:
                throw NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid request: \(errorBody)".localized()])
            case 401:
                throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized. Please check your token.".localized()])
            case 403:
                throw NSError(domain: "", code: 403, userInfo: [NSLocalizedDescriptionKey: "Damage not yours.".localized()])
            case 404:
                throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Damage not found.".localized()])
            default:
                throw NSError(domain: "", code: httpResponse.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "Failed with status code: \(httpResponse.statusCode) - \(errorBody)".localized()])
            }
        }
        
//        let decodeTime = Date()
//        print("Network request took: \(decodeTime.timeIntervalSince(startTime)) seconds")

        let damage = try await Task.detached(priority: .background) {
            let decoder = JSONDecoder()
            return try decoder.decode(DamageResponse.self, from: data)
        }.value

//        print("Decoding took: \(Date().timeIntervalSince(decodeTime)) seconds")
        return damage
    }

    func fixDamage(damageId: String, token: String) async throws {
        let url = URL(string: "\(APIConfig.baseURL)/tenant/leases/current/damages/\(damageId)/fix/")!
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server.".localized()])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            switch httpResponse.statusCode {
            case 400:
                throw NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid request: \(errorBody)".localized()])
            case 401:
                throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized. Please check your token.".localized()])
            case 403:
                throw NSError(domain: "", code: 403, userInfo: [NSLocalizedDescriptionKey: "Damage not yours.".localized()])
            case 404:
                throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Damage not found.".localized()])
            default:
                throw NSError(domain: "", code: httpResponse.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "Failed with status code: \(httpResponse.statusCode) - \(errorBody)".localized()])
            }
        }
    }
    
    func uploadTenantDocument(leaseId: String, propertyId: String, fileName: String, base64Data: String) async throws -> String {
        let url = URL(string: "\(APIConfig.baseURL)/tenant/leases/current/docs/")!
        let token = try await TokenStorage.getValidAccessToken()
        
        let body: [String: Any] = [
            "name": fileName,
            "data": base64Data
        ]
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        urlRequest.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server.".localized()])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            switch httpResponse.statusCode {
            case 400:
                throw NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid document data: \(errorBody)".localized()])
            case 401:
                throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized. Please check your token.".localized()])
            case 403:
                throw NSError(domain: "", code: 403, userInfo: [NSLocalizedDescriptionKey: "Lease not yours.".localized()])
            case 404:
                throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Property or lease not found.".localized()])
            default:
                throw NSError(domain: "", code: httpResponse.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "Failed with status code: \(httpResponse.statusCode) - \(errorBody)".localized()])
            }
        }
        
        let idResponse = try await Task.detached(priority: .background) {
            try JSONDecoder().decode(IdResponse.self, from: data)
        }.value
        return idResponse.id
    }
}

struct PropertyRoomsTenant: Identifiable, Equatable {
    let id: String
    let name: String
    
    static func == (lhs: PropertyRoomsTenant, rhs: PropertyRoomsTenant) -> Bool {
        return lhs.id == rhs.id
    }
}

struct FurnitureResponseTenant: Codable {
    let id: String
    let name: String
    let quantity: Int
    let archived: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case archived
    }
}

struct RoomResponseTenant: Codable {
    let id: String
    let name: String
    let archived: Bool
    let furnitures: [FurnitureResponseTenant]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case archived
        case furnitures
    }
}

struct PropertyInventoryResponse: Codable {
    let id: String
    let ownerId: String
    let name: String
    let address: String
    let city: String
    let postalCode: String
    let country: String
    let areaSqm: Double
    let rentalPricePerMonth: Int
    let depositPrice: Int
    let createdAt: String
    let archived: Bool
    let nbDamage: Int
    let status: String
    let lease: LeaseInfo?
    let rooms: [RoomResponseTenant]
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case address
        case city
        case postalCode = "postal_code"
        case country
        case areaSqm = "area_sqm"
        case rentalPricePerMonth = "rental_price_per_month"
        case depositPrice = "deposit_price"
        case createdAt = "created_at"
        case archived
        case nbDamage = "nb_damage"
        case status
        case lease
        case rooms
    }
}
