//
//  MoviesViewModel.swift
//  MobileDB
//
//  Created by Carlos Vinicius on 8/05/18.
//  Copyright © 2018 ArcTouch. All rights reserved.
//

import RxSwift
import RxCocoa

private struct MoviesViewModelConstants {
  static let messageEmptySearch = "No movies found"
  static let invalidMovieId = "Invalid Movie id"
}

final class MoviesViewModel {
  var moviesDataSource: Driver<[MovieDetailModel]> {
    return dataSource.asDriver()
  }

  let dataSource = Variable<[MovieDetailModel]>([])
  let refresh = PublishSubject<Void>()
  let nextPage = PublishSubject<Void>()
  let willSearchMovieDetail = PublishSubject<String>()
  let errorMessage = PublishSubject<String>()
  let isLoadingData = PublishSubject<Bool>()
  let didReceiveMovieDetail = PublishSubject<MovieDetailModel>()
  let searchMovie = PublishSubject<String>()
  let willCleanSearchResult = PublishSubject<Void>()
  let willCancelSearch = PublishSubject<Void>()
  let emptyStateMessage = PublishSubject<String>()
  
  private var page = 0
  private let service: MoviesServiceProtocol
  private let disposeBag: DisposeBag
  private let pagination = BehaviorSubject(value: 0)
  
  init(service: MoviesServiceProtocol = MoviesServiceProvider()) {
    self.service = service
    self.disposeBag = DisposeBag()
    
    setupServiceCalls()
    setupSearch()
    
    // load the fist page
    nextPage.onNext(())
  }
}

// MARK: Setup Search bind
private extension MoviesViewModel {
  func setupSearch() {
    
  }
  
  func searchMovies(query: String, from page: Int) -> Observable<[MovieDetailModel]> {
    isLoadingData.onNext(true)
    
    let searchMovies = service.search(for: query, page: page).asObservable()
    let genres = service.genres().asObservable()
    
    return loadMovies(searchMovies, genres: genres)
  }
}

// MARK: Setup observables
private extension MoviesViewModel {
  func setupServiceCalls() {
    // Refresh
    refresh
      .flatMap { [weak self] page -> Observable<[MovieDetailModel]> in
        guard let strongSelf = self else { return .just([]) }
        strongSelf.dataSource.value.removeAll()
        strongSelf.page = 1
        return strongSelf.loadMovies(from: strongSelf.page)
      }.bind(to: dataSource)
      .disposed(by: disposeBag)
    
    // Cancel search
    willCancelSearch.subscribe(onNext: { [weak self] _ in
      self?.refresh.onNext(())
    }).disposed(by: disposeBag)
    
    willCleanSearchResult.subscribe(onNext: { [weak self] in
      guard let strongSelf = self else { return }
      strongSelf.dataSource.value.removeAll()
      strongSelf.page = 1
    }).disposed(by: disposeBag)
    
    // Load movie detail
    willSearchMovieDetail
      .flatMap { [weak self] id -> Observable<MovieDetailModel> in
        guard let strongSelf = self else { return .error(ServiceError.invalidParameters(message: MoviesViewModelConstants.invalidMovieId)) }
        return strongSelf.loadMovieDetail(with: id)
      }.bind(to: didReceiveMovieDetail)
      .disposed(by: disposeBag)
    
    // Pagination
    let paginator = self.nextPage
      .flatMapLatest { [weak self] _ -> Observable<Int> in
        guard let strongSelf = self else { return .just(1) }
        strongSelf.page += 1
        return .just(strongSelf.page)
      }

    // fetch movies
    let moviesObservable = paginator
      .distinctUntilChanged()
      .flatMap { [weak self] page -> Observable<[MovieDetailModel]> in
        guard let strongSelf = self else { return .just([]) }
        return strongSelf.loadMovies(from: page)
    }
    
    //serach movies
    let serachObservable = Observable.zip(searchMovie, paginator) { ($0, $1) }
      .skipWhile { $0.0.isEmpty }
      .flatMap { [weak self] (query, page) -> Observable<[MovieDetailModel]> in
        guard let strongSelf = self else { return .just([]) }
        return strongSelf.searchMovies(query: query, from: page)
      }
    
    moviesObservable.bind(to: dataSource).disposed(by: disposeBag)
    serachObservable.bind(to: dataSource).disposed(by: disposeBag)
  }
  
  func loadMovieDetail(with identifier: String) -> Observable<MovieDetailModel> {
    isLoadingData.onNext(true)
    return service.fetchMovieDetail(with: identifier).asObservable()
      .map { [weak self] movie -> MovieDetailModel? in
        return self?.mapMovieToMovieDetail(movie: movie,
                                           genres: movie.genres,
                                           language: movie.spokenLanguage?.first?.name)
      }.flatMap { Observable.from(optional: $0) }
      .do(onNext: { [weak self] _ in
        self?.isLoadingData.onNext(false)
      }, onError: { [weak self] error in
        self?.isLoadingData.onNext(false)
        self?.errorMessage.onNext(error.localizedDescription)
      })
  }
  
  func loadMovies(from page: Int) -> Observable<[MovieDetailModel]> {
    isLoadingData.onNext(true)
    
    let fetchMovies = service.fetchMovies(from: page).asObservable()
    let genres = service.genres().asObservable()
    
    return loadMovies(fetchMovies, genres: genres)
  }
}

// MARK: Load movies
private extension MoviesViewModel {
  func loadMovies(_ movies: Observable<Movies>, genres: Observable<[Genre]>) -> Observable<[MovieDetailModel]> {

    isLoadingData.onNext(true)
    return Observable.zip(movies, genres) { ($0, $1) }
      .filter { self.page <= $0.0.totalPages }
      .map { [weak self] (movies, genres) -> [MovieDetailModel] in
        guard let strongSelf = self else { return [] }
        return strongSelf.mapMoviesGenresToMovieDetail(movies: movies, genres: genres)
      }.scan(dataSource.value) { (currentMovies, newMovies) -> [MovieDetailModel] in
        return currentMovies + newMovies
      }.do(onNext: { [weak self] _ in
        self?.isLoadingData.onNext(false)
        }, onError: { [weak self] error in
          self?.isLoadingData.onNext(false)
          self?.errorMessage.onNext(error.localizedDescription)
      })
  }
}

// MARK: Utility map methods
private extension MoviesViewModel {
  func mapMoviesGenresToMovieDetail(movies: Movies, genres: [Genre]) -> [MovieDetailModel] {
    return movies.results.map { [weak self] movie -> MovieDetailModel? in
      let movieGenres = movie.genreIds?.map { id -> Genre? in
        return genres.first(where: { $0.id == id })
        }.compactMap { $0 }
      
      return self?.mapMovieToMovieDetail(movie: movie,
                                         genres: movieGenres,
                                         language: movie.language)
      }.compactMap { $0 }
  }
  
  func mapMovieToMovieDetail(movie: Movie, genres: [Genre]?, language: String?) -> MovieDetailModel? {
    return MovieDetailModel(id: movie.id,
                            title: movie.title,
                            posterImagePath: movie.poster,
                            backdropImagePath: movie.backdrop,
                            ratingScore: movie.rating,
                            releaseYear: movie.releaseDate,
                            genres: genres,
                            revenue: movie.revenue,
                            description: movie.description,
                            runtime: movie.runtime,
                            language: language,
                            homepageLink: movie.homepage)
  }
}
