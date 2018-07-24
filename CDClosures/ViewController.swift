//
//  ViewController.swift
//  CDClosures
//
//  Created by YLCHUN on 2018/7/21.
//  Copyright © 2018年 ylchun. All rights reserved.
//

import UIKit
 
func cdbTest() {
    do {
        try registerCDClosures("data")
        
        try Model.delete(where:"idx = 3")
        try Model.delete()
        
        try Model.insert(count: 100) { (idx, m) in
            m.time = Date()
            m.idx = Int32(idx)
        }
        try Model.insert() { (m) in
            m.time = Date()
            m.idx = 101
        }
        
        try Model.update(where: "idx = 4") { (m) in
            m.time = Date()
        }
        
        try Model.select(range: (10, 10), sorts: [("time", .asc)]) { (ms) in
            for m in ms {
                print("idx:\(m.idx)")
            }
        }
    } catch let e {
        print("\(e)")
    }
}

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cdbTest()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

