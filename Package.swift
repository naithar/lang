import PackageDescription

let package = Package(
    name: "lang",
	dependencies: [
		.Package(url: "https://github.com/trill-lang/LLVMSwift.git", majorVersion: 0)
	]
)
