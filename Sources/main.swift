import LLVM
import Foundation

import Foundation

extension UnicodeScalar {
    
    var isSpace: Bool {
        return isspace(Int32(self.value)) != 0
    }
    
    var isAlphanumeric: Bool {
        return isalnum(Int32(self.value)) != 0
    }
}


class Lexer {
    
    enum Token {
        
        enum Bracket {
            
            enum `Type` {
                case open
                case closed
            }
            
            case parentheses(Type) // ()
            case braces(Type) // {}
            case brackets(Type) // []
            
            init?(from value: UnicodeScalar) {
                switch value {
                case "(":
                    self = .parentheses(.open)
                case ")":
                    self = .parentheses(.closed)
                case "{":
                    self = .braces(.open)
                case "}":
                    self = .braces(.closed)
                case "[":
                    self = .brackets(.open)
                case "]":
                    self = .brackets(.closed)
                default:
                    return nil
                }
            }
        }
        
        enum Operator: UnicodeScalar {
            case plus = "+"
            case minus = "-"
            case power = "*"
            case divide = "/"
            case modulo = "%"
            case equal = "="
        }
        
        enum Keyword: String {
            case `func` = "func"
            case `if` = "if"
            case `else` = "else"
        }
        
        case number(Double)
        case `operator`(Operator)
        case bracket(Bracket)
        case keyword(Keyword)
        case separator // ; \n
        case apostrophe // '
        case dot // .
        case identifier(String)
        
        init?(character value: UnicodeScalar) {
            if let bracket = Bracket(from: value) {
                self = .bracket(bracket)
            } else if let `operator` = Operator(rawValue: value) {
                self = .operator(`operator`)
            } else if [";", "\n"].contains(value) {
                self = .separator
            } else if value == "." {
                self = .dot
            } else if value == "'" {
                self = .apostrophe
            } else {
                return nil
            }
        }
        
        init?(value: String) {
            guard value.unicodeScalars.count > 0 else { return nil }
            
            if let character = Token.init(character: value.unicodeScalars.first!) {
                self = character
            } else if let keyword = Keyword(rawValue: value) {
                self = .keyword(keyword)
            } else if let number = Double(value) {
                self = .number(number)
            } else {
                self = .identifier(value)
            }
        }
    }
    
    var input: [UnicodeScalar]
    
    private var index = 0
    
    init(input: String) {
        self.input = Array(input.unicodeScalars)
    }
    
    private var currentCharacter: UnicodeScalar? {
        return self.index < self.input.count ? self.input[self.index] : nil
    }
    
    private func read() -> String {
        var result = ""
        while let character = self.currentCharacter, character.isAlphanumeric {
            result.unicodeScalars.append(character)
            self.advance()
        }
        return result
    }
    
    private func advance(by count: Int = 1) {
        self.index += count
    }
    
    private func next() -> Token? {
        while let character = self.currentCharacter, character.isSpace {
            self.advance()
        }
        
        guard let character = self.currentCharacter else {
            return nil
        }
        
        if let token = Token(character: character) {
            self.advance()
            return token
        }
        
        if character.isAlphanumeric {
            let identifier = self.read()
            return Token(value: identifier)
        }
        
        return nil
    }
    
    func tokenize() -> [Token] {
        var result = [Token]()
        while let token = self.next() {
            result.append(token)
        }
        return result
    }
}


class Parser {
    
    indirect enum Expression {
        case number(Double)
        case binary(Expression, Lexer.Token.Operator, Expression)
        case variable(String)
        case condition(Expression, Expression, Expression) // if (eX1) { ex2 } ex3 (else lala)
    }
    
    var tokens: [Lexer.Token]
    
    private var index = 0
    
    
    init(input: [Lexer.Token]) {
        self.tokens = input
    }
    
    private func advance(by count: Int = 1) {
        self.index += count
    }
    
    private func advance(to token: Lexer.Token) throws {
        
    }
    
    private func advance(with token: Lexer.Token) throws {
        
    }
    
    private var currentToken: Lexer.Token? {
        return self.index < self.tokens.count ? self.tokens[self.index] : nil
    }
    
    func parse() -> [Expression] {
        var result = [Expression]()
        
        while self.currentToken != nil {
            guard let expression = self.expression() else {
                continue //TODO: throw error
            }
            
            if case .operator(let `operator`)? = self.currentToken {
                self.advance()
                guard let right = self.expression() else {
                    return [] // TODO: throw error
                }
                result.append(.binary(expression, `operator`, right))
            } else {
                result.append(expression)
            }
        }
        
        return result
    }
    
    private func expression() -> Expression? {
        guard let token = self.currentToken else {
            return nil
        }
        
        switch token {
        case .number(let value):
            self.advance()
            return .number(value)
        case .separator:
            self.advance()
        default:
            break
        }
        
        return nil
    }
}


let tokens = Lexer(input: "5 + 1;").tokenize()
let expressions = Parser(input: tokens).parse()

print(expressions)


func main() throws {
    print("swift print")
    
    let module: Module = Module(name: "main")
    let builder: IRBuilder = IRBuilder(module: module)
    
        let mainType = FunctionType(argTypes: [], returnType: IntType.int64)
        let function = builder.addFunction("main", type: mainType)
        let entry = function.appendBasicBlock(named: "entry")
        builder.positionAtEnd(of: entry)
    
    func emitPrintf() -> Function {
        if let function = module.function(named: "printf") { return function }
        let printfType = FunctionType(argTypes: [PointerType(pointee: IntType.int8)],
                                      returnType: IntType.int32,
                                      isVarArg: true)
        return builder.addFunction("printf", type: printfType)
    }
    
    let helloString = builder.buildGlobalStringPtr("Hello\n")
    let formatString = builder.buildGlobalStringPtr("Value: %f\n")
    let finishString = builder.buildGlobalStringPtr("Finished\n")
    
    let printf = emitPrintf()
    
    builder.buildCall(printf, args: [helloString])
    
    print("start expressions")
    for expression in expressions {
        print("expression - \(expression)")
        switch expression {
        case .binary(let left, let op, let right):
            guard case .number(let left) = left,
                case .number(let right) = right else {
                    continue
            }
            
            let leftValue = builder.buildAlloca(type: FloatType.double, name: "left")
            builder.buildStore(FloatType.double.constant(left), to: leftValue)
            let lhs = builder.buildLoad(leftValue)
            
            let rightValue = builder.buildAlloca(type: FloatType.double, name: "right")
            builder.buildStore(FloatType.double.constant(right), to: rightValue)
            let rhs = builder.buildLoad(rightValue)
            
            print("inside")
            let result: IRValue
            
            switch op {
            case .plus:
                result = builder.buildAdd(lhs, rhs)
            default:
                continue
            }
            
            builder.buildCall(printf, args: [formatString, result])
        default:
            break
        }
    }
    
    builder.buildCall(printf, args: [finishString])
    
    builder.buildRet(90)
    
    try? module.verify()
    
    let path = URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/file")
    let llPath = path.deletingPathExtension().appendingPathExtension("ll")
    if FileManager.default.fileExists(atPath: llPath.path) {
        try FileManager.default.removeItem(at: llPath)
    }
    FileManager.default.createFile(atPath: llPath.path, contents: nil)
    try module.print(to: llPath.path)
    print("Successfully wrote LLVM IR to \(llPath.lastPathComponent)")
    
    
    let objPath = path.deletingPathExtension().appendingPathExtension("o")
    if FileManager.default.fileExists(atPath: objPath.path) {
        try FileManager.default.removeItem(at: objPath)
    }
    
    let targetMachine = try TargetMachine()
    try targetMachine.emitToFile(module: module,
                                 type: .object,
                                 path: objPath.path)
    
    let process = Process()
    process.launchPath = "/usr/local/opt/llvm/bin/lli"
    process.arguments = [llPath.path]
    process.launch()
}

try main()
