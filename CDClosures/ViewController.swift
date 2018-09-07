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
        let count = try Model.delete()
        print(count)
        
        var i:Info?
        try Info.insert(cb: { (info) in
            info.title = "title"
            info.message = "msg"
            i = info
        })

        try Model.insert(count: 100) { (idx, m) in
            m.time = Date()
            m.idx = Int32(idx)
            m.name = "111"
            m.info = i
        }
        try Model.update(where: "idx = 4") { (m) in
            m.time = Date()
            m.name = "222"
        }
        try Model.select(where: "idx = 4") { (ms) in
            guard let m = ms.first else { return }
            print("s0 \(m.idx) \(m.name ?? "")")
        }
//        try Model.batchUpdate(where: "idx = 4") { (dict) in
//            dict["name"] = "333"
//        }
//        try Model.select(where: "idx = 4") { (ms) in
//            guard let m = ms.first else { return }
//            print("s1 \(m.idx) \(m.name ?? "")")
//        }
//        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+1) {
//            try? Model.select(where: "idx = 4") { (ms) in
//                guard let m = ms.first else { return }
//                print("s2 \(m.idx) \(m.name ?? "")")
//                print("")
//            }
//        }
//        DispatchQueue.global().async {
//            try? Model.update(where: "idx = 4") { (m) in
//                m.time = Date()
//                m.name = "222"
//            }
//        }
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

    
}

