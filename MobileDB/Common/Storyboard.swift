//
//  Storyboard.swift
//  MobileDB
//
//  Created by Carlos Vinicius on 8/06/18.
//  Copyright © 2018 ArcTouch. All rights reserved.
//

import UIKit

enum Storyboard: String {
  case movies = "Movies"
  case movieDetail = "MovieDetails"
  
  var storyboard: UIStoryboard {
    return UIStoryboard(name: rawValue, bundle: nil)
  }
  
  func viewController(_ identifier: String) -> UIViewController? {
    return storyboard.instantiateViewController(withIdentifier: identifier)
  }
}