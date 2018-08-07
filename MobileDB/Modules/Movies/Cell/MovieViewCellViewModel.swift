//
//  MovieViewCellViewModel.swift
//  MobileDB
//
//  Created by Carlos Vinicius on 8/05/18.
//  Copyright © 2018 ArcTouch. All rights reserved.
//

import RxSwift

final class MovieViewCellViewModel {
  let title = PublishSubject<String>()
  let releaseYear = PublishSubject<String>()
  let genres = PublishSubject<String>()
  let posterImage = PublishSubject<UIImage>()
  let popularity = PublishSubject<String>()
  
  private var model: MovieViewData?
  private let service: ConfigServiceProtocol
  
  init(service: ConfigServiceProtocol) {
    self.service = service
  }
  
  func setupData(with model: MovieViewData) {
    self.model = model
    
    if let title = model.title {
      self.title.onNext(title)
    }
    
    if let releaseYear = model.releaseYear,
      let year = releaseYear.split(separator: "-").first {
      self.releaseYear.onNext(String(year))
    }
    
    if let ratingScore = model.ratingScore {
      let rating = String(format: "%.1f", ratingScore)
      popularity.onNext(rating)
    }
    
    if let genres = model.genres {
      self.genres.onNext(genres.formatGenresAsString())
    }
  }
  
  func loadPosterImage() {
    guard let model = model, let imagePath = model.posterImagePath else { return }
    // Once the Single call receives a success or error the subscriber will disposed
    _ = service
      .loadPoster(for: imagePath)
      .observeOn(MainScheduler.asyncInstance)
      .subscribe(onSuccess: { [weak self] image in
        self?.posterImage.onNext(image)
      })
  }
}
