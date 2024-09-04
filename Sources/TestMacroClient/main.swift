import TestMacro

let a = 17
let b = 25

let (result, code) = #stringify(a + b)

print("The value \(result) was produced by the code \"\(code)\"")

@InitDecodable
struct Seungchan {
    let name: String
    let age: Int
}


