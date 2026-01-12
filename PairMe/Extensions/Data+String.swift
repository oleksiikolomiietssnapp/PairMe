//
//  Data+String.swift
//  PairMe
//
//  Created by Oleksii Kolomiiets on 1/12/26.
//


import Foundation

extension Data {
    var string: String {
        String(data: self, encoding: .utf8) ?? ""
    }
}
