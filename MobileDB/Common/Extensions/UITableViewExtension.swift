//
//  UITableViewExtension.swift
//  MobileDB
//
//  Created by Carlos Vinicius on 8/05/18.
//

import UIKit

extension UITableView {
  func register<T: UITableViewCell>(_: T.Type) where T: ReusableIdentifier {
    let nib = UINib(nibName: T.identifier, bundle: nil)
    register(nib, forCellReuseIdentifier: T.identifier)
  }
}
