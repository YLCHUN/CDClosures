# CDClosures
CoreData Closures 在原生API基础上进行封装。简化CoreData的使用。

## 示例：
```
// CoreData文件：data.xcdatamodeld  包含模型：Model{idx: Int32, time: Date}
do {
    try registerCDClosures("data") //第一步注册 CoreData 文件

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
```

## 注意事项：
1.CDClosures采用throws进行异常信息传递，可用```do{}catch{}```进行捕获<br>
2.CDClosures包含线程锁，同一个CDClosures的闭包之间禁止嵌套使用<br>
3.CDClosures每个闭包执行后都会默认进行提交，可通过修改```autoSave```属性进行更改<br>
4.CDClosures每个Entity和Class的对应必须是唯一的<br>

