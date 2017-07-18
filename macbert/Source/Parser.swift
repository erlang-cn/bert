//
//  Model.swift
//  Nynja
//
//  Created by Anton Makarov on 11.07.2017.
//  Copyright © 2017 TecSynt Solutions. All rights reserved.
//

import Foundation
protocol Parsable { func parse(bert: BertObject) -> Any? }

enum SelectType {
    case chain
    case tuple
    case binary
    case atom
    case number
    case list
    case boolean
}

class Model: Parsable {
    var chain: Chain?
    var tuple: Tuple?
    var binary: Binary?
    var number: Number?
    var atom: Atom?
    var list: List?
    var boolean: Boolean?
    var select: SelectType!
    
    init(value: Chain)  { self.select = .chain;  self.chain  = value; }
    init(value: Tuple)  { self.select = .tuple;  self.tuple  = value; }
    init(value: Atom)   { self.select = .atom;   self.atom   = value; }
    init(value: Binary) { self.select = .binary; self.binary = value; }
    init(value: Number) { self.select = .number; self.number = value; }
    init(value: List)   { self.select = .list;   self.list   = value; }
    init(value: Boolean){ self.select = .boolean;self.boolean = value;}
    
    var description : String {
        get {
            switch select! {
            case .atom:
                return atom!.description
            case .binary:
                return binary!.description
            case .chain:
                return chain!.description
            case .number:
                return number!.description
            case .tuple:
                return tuple!.description
            case .list:
                return list!.description
            case .boolean:
                return boolean!.description
            }
        }
    }
    func parse(bert: BertObject) -> Any? {
        switch select! {
        case .atom:
            return atom!.parse(bert:bert)
        case .binary:
            return binary!.parse(bert:bert)
        case .chain:
            return chain!.parse(bert:bert)
        case .number:
            return number!.parse(bert:bert)
        case .tuple:
            return tuple!.parse(bert:bert)
        case .list:
            return list!.parse(bert: bert)
        case .boolean:
            return boolean!.parse(bert:bert)
        }
    }
}

class Boolean: Parsable {
    
    func parse(bert: BertObject) -> Any? {
        if let bool = bert as? BertBool {
            return bool.value
        }
        return nil
    }
    
    var description : String {
        get {
            return "Bool()"
        }
    }
}

class Tuple: Parsable {
    var name: String?
    var arity: Int
    var body: [Model]
    init(name: String?, body: [Model]) { self.name = name; self.body = body; self.arity = body.count }
    
    func parse(bert: BertObject) -> Any? {
        if let tuple = bert as? BertTuple {
            if name != nil {
                //It's class
                if let atom = tuple.elements[0] as? BertAtom {
                    if atom.value == name! {
                        switch atom.value {
                        
                        case "Err":
                            if body.count != 1 {
                                return nil
                            }
                            let err = Err()
                            err.code = body[0].parse(bert: tuple.elements[1]) as? String
                            return err
                        case "Ok":
                            if body.count != 1 {
                                return nil
                            }
                            let ok = Ok()
                            ok.code = body[0].parse(bert: tuple.elements[1]) as? String
                            return ok
                        case "Io":
                            if body.count != 2 {
                                return nil
                            }
                            let io = Io()
                            io.code = body[0].parse(bert: tuple.elements[1]) as AnyObject
                            io.data = body[1].parse(bert: tuple.elements[2]) as AnyObject
                            return io
                        default:
                            return nil
                        }
                    }
                    return true
                }
            } else {
                //It's Array
                var result = [Any]()
                for i in 0..<body.count {
                    if let item = body[i].parse(bert: tuple.elements[i]) {
                        result.append(item)
                    } else {
                        return nil
                    }
                }
                return result
            }
        }
        return nil
    }
    
    
    var description : String {
        get {
            if name != nil {
                var text = "#\(name!){"
                for i in 0..<body.count {
                    if i != body.count - 1{
                        text += "\(body[i].description),"
                    } else {
                        text += "\(body[i].description)}"
                    }
                }
                return text
            } else {
                var text = "["
                for i in 0..<body.count {
                    if i != body.count - 1{
                        text += "\(body[i].description),"
                    } else {
                        text += "\(body[i].description)]"
                    }
                }
                return text
            }
        }
    }
}

class List: Parsable {
    var constant: String?
    var model: Model
    init(model: Model) { constant = nil ; self.model = model }
    init(constant: String, model: Model) { self.constant = constant; self.model = model }
    
    func parse(bert: BertObject) -> Any? {
        if let list = bert as? BertList {
            if let result = self.addToList(list: list, constant: constant) {
                return result
            } else {
                return nil
            }
        }
        return nil
    }
    
    func addToList(list: BertList, constant: String? = nil) -> [Any]? {
        var result = [Any]()
        for i in list.elements {
            if let value = model.parse(bert: i) {
                if let const = constant {
                    if let val = self.getStringFrom(any: value) {
                        if val == const {
                            result.append(value)
                        }
                    }
                } else {
                    result.append(value)
                }
            } else {
                return nil
            }
        }
        return result
    }
    
    func getStringFrom(any: Any) -> String? {
        if let atom = any as? BertAtom {
            return atom.value
        }
        return nil
    }
    
    var description : String {
        get {
            return constant ?? "[]"
        }
    }
}


class Atom: Parsable {
    var constant: String?
    
    init() { constant = nil }
    init(constant: String) { self.constant = constant }
    
    func parse(bert: BertObject) -> Any? {
        if let atom = bert as? BertAtom {
            if let const = constant {
                if atom.value == const {
                    return atom.value
                }
            } else {
                return atom.value
            }
        }
        return nil
    }
    
    var description : String {
        get {
            return constant ?? "Atom()"
        }
    }
}


class Binary: Parsable {
    var constant: String?
    init() { constant = nil }
    init(constant: String) { self.constant = constant }
    func parse(bert: BertObject) -> Any? {
        if let bin = bert as? BertBinary {
            if let const = constant {
                let dataString = String(data: bin.value as Data, encoding: String.Encoding.utf8)
                if dataString == const {
                    return String(data: bin.value as Data, encoding: String.Encoding.utf8)
                }
            } else {
                
                return String(data: bin.value as Data, encoding: String.Encoding.utf8)
            }
        }
        return nil
    }
    var description : String {
        get {
            return constant ?? "Binary()"
        }
    }
}

class Number: Parsable {
    var constant: String?
    init() { constant = nil }
    init(constant: String) { self.constant = constant }
    func parse(bert: BertObject) -> Any? {
        if let num = bert as? BertNumber {
            if let const = constant {
                if const == "\(num.value)" {
                    return Int(num.value)
                }
            } else {
                return Int(num.value)
            }
        }
        return nil
    }
    var description : String {
        get {
            return constant ?? "Number()"
        }
    }
}


class Chain: Parsable {
    var types: [Model]!
    init(types: [Model]) { self.types = types }
    
    func parse(bert: BertObject) -> Any? {
        for model in types {
            if let obj = model.parse(bert: bert) {
                return obj
            }
        }
        return nil
    }
    
    
    var description : String {
        get {
            var text = ""
            for i in 0..<types.count {
                if i != types.count - 1 {
                    text += "\(types[i].description)|"
                } else {
                    text += "\(types[i].description)"
                }
            }
            return text
        }
    }
    
}

