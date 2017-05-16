//
//  JSON.swift
//  meh
//
//  Created by Jane Maunsell on 5/3/17.
//  Copyright © 2017 6.S062 Group. All rights reserved.
//

import Foundation

protocol JSONRepresentable {
    var JSONRepresentation: AnyObject { get }
}

protocol JSONSerializable: JSONRepresentable {
}

extension JSONSerializable {
    var JSONRepresentation: AnyObject {
        var representation = [String: AnyObject]()
        
        for case let (label?, value) in Mirror(reflecting: self).children {
            switch value {
            case let value as JSONRepresentable:
                representation[label] = value.JSONRepresentation
                
            case let value as NSObject:
                representation[label] = value
                
            default:
                // Ignore any unserializable properties
                break
            }
        }
        
        return representation as AnyObject
    }
}

extension JSONSerializable {
    func toJSON() -> String? {
        let representation = JSONRepresentation
        
        guard JSONSerialization.isValidJSONObject(representation) else {
            print("JSONRepresentation \(representation) is not valid JSON object")
            return nil
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: representation, options: [])
            return String(data: data, encoding: String.Encoding.utf8)
        } catch {
            print("failed to produce JSON serialized version of representation \(representation)")
            return nil
        }
    }
}

extension Date: JSONRepresentable {
    var JSONRepresentation: AnyObject {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        
        return formatter.string(from: self) as AnyObject
    }
}

extension UUID: JSONRepresentable {
    var JSONRepresentation: AnyObject {
        return self.uuidString as AnyObject
    }
}

extension Set : JSONRepresentable {
    var JSONRepresentation: AnyObject {
        return Array(self) as AnyObject
    }
}

