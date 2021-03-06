//
//  ConfigServiceProvider.swift
//  MobileDB
//
//  Created by Carlos Vinicius on 8/05/18.
//

import RxSwift

final class ConfigServiceProvider: ServiceProviderProtocol, ConfigServiceProtocol {
  let session: SessionHandler
  
  required init(session: SessionHandler = URLSession.shared) {
    self.session = session
  }
  
  func fetchConfig() -> Single<String> {
    Single.create { [weak self] single in
      self?.session.executeRequest(with: MoviesAPI.configuration) { result in
        switch result {
        case .success(let data):
          guard let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers),
            let value = json as? [String: Any],
            let images = value["images"] as? [String: Any],
            let secureImageBaseUrl = images["secure_base_url"] as? String else {
              return single(.error(ServiceError.invalidFormatData))
          }
          
          single(.success(secureImageBaseUrl))
        case .error(let error):
          single(.error(error))
        }
      }
      
      return Disposables.create()
    }
  }
  
  func loadBackdropImage(for path: String) -> Single<UIImage?> {
    return loadImage(for: MoviesAPI.backdropImage(path: path))
  }
  
  func loadPoster(for path: String) -> Single<UIImage?> {
    return loadImage(for: MoviesAPI.posterImage(path: path))
  }
  
  private func loadImage(for requestType: RequestableAPI) -> Single<UIImage?> {
    Single.create { [weak self] single in
      self?.session.executeRequest(with: requestType) { result in
        switch result {
        case .success(let data):
          guard let image = UIImage(data: data) else {
            return single(.error(ServiceError.invalidFormatData))
          }
          
          single(.success(image))
        case .error(let error):
          single(.error(error))
        }
      }
      
      return Disposables.create()
    }
  }
}
