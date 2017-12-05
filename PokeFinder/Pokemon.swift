//
//  Pokemon.swift
//  PokeFinder
//
//  Created by 呂易軒 on 2017/11/27.
//  Copyright © 2017年 呂易軒. All rights reserved.
//

import Foundation

class Pokemon {
    
    private var _name: String!
    
    var name: String{
        
        if _name == nil{
            _name = ""
        }
        
        return _name
    }
    
    init(name: String){
        
        self._name = name
    }

}
