//
//  String+data.swift
//  PairMe
//
//  Created by Oleksii Kolomiiets on 1/12/26.
//


import Foundation

extension String {
    var data: Data? {
        self.data(using: .utf8)
    }
}
