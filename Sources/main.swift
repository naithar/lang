import LLVM
import Foundation

import Foundation

extension UnicodeScalar {
    
    var isSpace: Bool {
        guard UnicodeScalar("\n") != self && UnicodeScalar("\r") != self else {
            return false
        }
        
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
            case chevrons(Type) // <>
            
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
                case "<":
                    self = .chevrons(.open)
                case ">":
                    self = .chevrons(.closed)
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
            case `return` = "return"
        }
        
        case number(Int)
        case `operator`(Operator)
        case bracket(Bracket)
        case keyword(Keyword)
        case separator // ; \n
        case apostrophe // '
        case dot // .
        case colon // :
        case backtick // `
        case coma // ,
        case identifier(String)
        
        init?(character value: UnicodeScalar) {
            if let bracket = Bracket(from: value) {
                self = .bracket(bracket)
            } else if let `operator` = Operator(rawValue: value) {
                self = .operator(`operator`)
            } else if [";", "\n", "\r"].contains(value) {
                self = .separator
            } else if value == "." {
                self = .dot
            } else if value == ":" {
                self = .colon
            } else if value == "'" {
                self = .apostrophe
            } else if value == "`" {
                self = .backtick
            } else if value == "," {
                self = .coma
            } else {
                return nil
            }
        }
        
        init?(string value: String) {
            guard value.unicodeScalars.count > 0 else { return nil }
            
            if let character = Token.init(character: value.unicodeScalars.first!) {
                self = character
            } else if ["\r\n", "\n", "\r"].contains(value) {
                self = .separator
            } else if let keyword = Keyword(rawValue: value) {
                self = .keyword(keyword)
            } else if let number = Int(value) {
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
            return Token(string: identifier)
        }
        
        return nil
    }
    
    func tokenize() -> [Token] {
        var result = [Token]()
        while let token = self.next() {
            if case .separator? = result.last,
                case .separator = token {
                    continue
            }
            result.append(token)
        }
        return result
    }
}

enum ParameterType {
    
    case unknown
    case int
    case double
    case void
    
    init?(value: String) {
        switch value {
        case "Int":
            self = .int
        case "Double":
            self = .double
        case "Void", "":
            self = .void
        default:
            return nil
        }
    }
}

protocol Expressible {
    
}

public struct Parameter: Expressible {
    
    var name: String = ""
    var type = ParameterType.unknown
    
    init(name: String, type: ParameterType) {
        self.name = name
        self.type = type
    }
    
    static func parse(parser: Parser) -> [Parameter]? {
        guard case .bracket(.parentheses(.open))? = parser.currentToken else {
            return nil
        }
        
        parser.advance()
        
        var result = [Parameter]()
        loop: while let token = parser.currentToken {
            switch token {
            case .bracket(.parentheses(.closed)):
                break loop
            default:
                return nil
            }
            
            parser.advance()
        }
        
        return result
    }
}

public struct Return: Expressible {
    
    var type = ParameterType.void
    
    init?(parser: Parser) {
        guard case .bracket(.parentheses(.open))? = parser.currentToken else {
            return nil
        }
        
        parser.advance()
        
        guard case .identifier(let name)? = parser.currentToken,
            let type = ParameterType.init(value: name) else {
                return nil
        }
        
        self.type = type
        
        parser.advance()
        
        guard case .bracket(.parentheses(.closed))? = parser.currentToken else {
            return nil
        }
    }
    
    init(type: ParameterType = .void) {
        self.type = type
    }
}

struct Body: Expressible {
    
    var expressions: [Expression] = []
    
    init?(parser: Parser) {
        
        var prevToken: Lexer.Token?
        loop: while let token = parser.currentToken {
            
            guard let exp = self.parseToken(token: token, parser: parser, prevToken: &prevToken) else {
                break loop
            }
            
            if case .none = exp {
            } else {
                self.expressions.append(exp)
            }
            
            
        }
    }
    
    private func parseToken(token: Lexer.Token, parser: Parser, prevToken: inout Lexer.Token?) -> Expression? {
        switch token {
        case .bracket(.braces(.open)):
            parser.advance()
        case .bracket(.braces(.closed)):
            return nil
        case .operator(let `operator`):
            guard case .number(let left)? = prevToken else {
                return nil
            }
            
            let lhs = Expression.number(Double(left))
            parser.advance()
            
            guard case .number(let right)? = parser.currentToken else {
                return nil
            }
            
            let rhs = Expression.number(Double(right))
            
            return .binary(lhs, `operator`, rhs)
        case .keyword(.return):
            parser.advance()
            
            var result: Expression?
            while result == nil {
                guard let exp = self.parseToken(token: parser.currentToken!, parser: parser, prevToken: &prevToken) else {
                    return nil
                }
                
                if case .none = exp {
                    continue
                }
                
                result = exp
            }
            return .return(result!)
        default:
            parser.advance()
        }
        
        prevToken = token
        
        return Expression.none
    }
    
    init() {}
    
    func build(for builder: IRBuilder) {
        builder.buildRet(builder.buildAdd(IntType.int64.constant(10), IntType.int64.constant(50)))
    }
}

indirect enum Expression: Expressible {
    
    case none
    case number(Double)
    case binary(Expression, Lexer.Token.Operator, Expression)
    case `return`(Expression)
    case call(String, [Any])
    
    init?(call parser: Parser) {
        guard case .identifier(let name)? = parser.currentToken else {
            return nil
        }
        
        parser.advance()
        parser.advance()
        
        self = .call(name, [])
    }
    
    func build(for builder: IRBuilder, to functions: inout [String : LLVM.Function]) {
        let formatString = builder.buildGlobalStringPtr("Value: %d\n")
        builder.buildCall(functions["printf"]!, args: [formatString, builder.buildCall(functions["foo"]!, args: [])])
    }
}

public struct Function: Expressible {
    
    var name: String = ""
    var parameters: [Parameter] = []
    var `return`: Return = Return()
    var body: Body = Body()
    
    init?(parser: lang.Parser) {
        parser.advance()

        guard let nameToken = parser.currentToken,
            case .identifier(let name) = nameToken else {
                return nil
        }

        self.name = name
        
        parser.advance()
        
        guard let parameters = Parameter.parse(parser: parser) else {
            return nil
        }
        
        self.parameters = parameters
        
        parser.advance()
        
        guard let `return` = Return.init(parser: parser) else {
            return nil
        }
        
        self.return = `return`
        
        parser.advance()
        
        guard let body = Body(parser: parser) else {
            return nil
        }
        
        self.body = body
        
        parser.advance()
    }
    
    
    func build(for builder: IRBuilder, to functions: inout [String : LLVM.Function]) {
        let function = builder.addFunction(self.name, type: self.param())
        builder.positionAtEnd(of: function.appendBasicBlock(named: "entry"))
        
        self.body.build(for: builder)
        
        functions[self.name] = function
    }
    
    func param() -> FunctionType {
        return FunctionType(argTypes: [], returnType: IntType.int64)
    }
}

class Program {
    
//    indirect enum Expression {
//        case number(Double)
//    }
    
    public typealias LLVMF = LLVM.Function
    
    var expressions: [Expressible] = []
    
    init(input: [Expressible]) {
        self.expressions = input
    }
    
    func run(builder: LLVM.IRBuilder, module: LLVM.Module) {
        
        var functions = [String : LLVMF]()

        functions["value"] = builder.addFunction("value", type: FunctionType.init(argTypes: [], returnType: IntType.int64))
        builder.positionAtEnd(of: functions["value"]!.appendBasicBlock(named: "entry"))
        builder.buildRet(10)
        
        self.expressions.flatMap { $0 as? lang.Function }.forEach { $0.build(for: builder, to: &functions) }
        
        
        let mainType = FunctionType(argTypes: [], returnType: IntType.int64)
        let function = builder.addFunction("main", type: mainType)
        let entry = function.appendBasicBlock(named: "entry")
        builder.positionAtEnd(of: entry)
        
        func emitPrintf() -> LLVM.Function {
            if let function = module.function(named: "printf") { return function }
            let printfType = FunctionType(argTypes: [PointerType(pointee: IntType.int8)],
                                          returnType: IntType.int32,
                                          isVarArg: true)
            
            functions["printf"] = builder.addFunction("printf", type: printfType)
            return functions["printf"]!
            
        }
        
        let helloString = builder.buildGlobalStringPtr("Hello\n")
        let formatString = builder.buildGlobalStringPtr("Value: %d\n")
        let finishString = builder.buildGlobalStringPtr("Finished\n")
        
        let printf = emitPrintf()
        
        builder.buildCall(printf, args: [helloString])
        
        print("start expressions")
        
        
        //    for expression in expressions {
        //        print("expression - \(expression)")
        //        switch expression {
        //        case .binary(let left, let op, let right):
        //            guard case .number(let left) = left,
        //                case .number(let right) = right else {
        //                    continue
        //            }
        //
        //            let leftValue = builder.buildAlloca(type: FloatType.double, name: "left")
        //            builder.buildStore(FloatType.double.constant(left), to: leftValue)
        //            let lhs = builder.buildLoad(leftValue)
        //
        //            let rightValue = builder.buildAlloca(type: FloatType.double, name: "right")
        //            builder.buildStore(FloatType.double.constant(right), to: rightValue)
        //            let rhs = builder.buildLoad(rightValue)
        //
        //            print("inside")
        //            let result: IRValue
        //
        //            switch op {
        //            case .plus:
        //                result = builder.buildAdd(lhs, rhs)
        //            default:
        //                continue
        //            }
        //
        //            builder.buildCall(printf, args: [formatString, result])
        //        default:
        //            break
        //        }
        //    }
        
        builder.buildCall(printf, args: [finishString])
        
        let leftValue = builder.buildAlloca(type: IntType.int64, name: "left")
        let result = builder.buildCall(functions["value"]!, args: [])
        builder.buildStore(result, to: leftValue)
        let lhs = builder.buildLoad(leftValue)
        
        builder.buildCall(printf, args: [formatString, lhs])
        
        self.expressions.flatMap { $0 as? Expression }.forEach { $0.build(for: builder, to: &functions) }
        
        builder.buildRet(90)
    }
    
}

class Parser {
    
//    indirect enum Expression {
//        case number(Double)
//        case binary(Expression, Lexer.Token.Operator, Expression)
//        case variable(String)
//        case condition(Expression, Expression, Expression) // if (eX1) { ex2 } ex3 (else lala)
//    }
    
    var tokens: [Lexer.Token]
    
    private var index = 0
    
    
    init(input: [Lexer.Token]) {
        self.tokens = input
    }
    
    func advance(by count: Int = 1) {
        self.index += count
    }
    
    func advance(to token: Lexer.Token) throws {
        
    }
    
    func advance(with token: Lexer.Token) throws {
        
    }
    
    var currentToken: Lexer.Token? {
        return self.index < self.tokens.count ? self.tokens[self.index] : nil
    }
    
    func parse() -> [Expressible] {
        var result = [Expressible]()
        
        while let token = self.currentToken {
            switch token {
            case .keyword(.func):
                guard let `func` = lang.Function(parser: self) else {
                    return []
                }
                result.append(`func`)
            case .identifier(let name):
                if result.flatMap({ $0 as? lang.Function }).filter({ $0.name == name }).first != nil,
                    let exp = Expression(call: self) {
                    result.append(exp)
                } else {
                    self.advance()
                }
            default:
                self.advance()
            }
        }
        
        return result
    }
}

let program = "" +
    "func foo() (Int) {" +
        "return 5 + 10" +
    "}" +
    "foo()" +
""

let tokens = Lexer(input: program).tokenize()
let expressions = Parser(input: tokens).parse()

print("Tokens")
print(tokens)
print("Parser")
print(expressions)


func main() throws {
    print("swift print")
    
    let module: Module = LLVM.Module(name: "main")
    let builder: IRBuilder = LLVM.IRBuilder(module: module)
    let program = Program(input: expressions)
    
    program.run(builder: builder, module: module)
    
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
