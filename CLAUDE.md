# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands
- Build: `xcodebuild -scheme Oton.FM -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Test: `xcodebuild test -scheme Oton.FM -destination 'platform=iOS Simulator,name=iPhone 15'`
- Run single test: `xcodebuild test -scheme Oton.FM -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:Oton.FMTests/TestClassName/testMethodName`

## Code Style Guidelines
- **Naming**: PascalCase for types (structs, classes), camelCase for properties/methods
- **Imports**: Single imports per line, SwiftUI first, followed by Apple frameworks
- **Error Handling**: Use `do-catch` blocks with descriptive print statements
- **Extensions**: Place extensions at the end of the file
- **Access Control**: Mark private properties explicitly with `private`
- **SwiftUI Patterns**: 
  - Use property wrappers (@State, @StateObject, @Binding) appropriately
  - Chain modifiers on views with one modifier per line
  - Use ZStack/VStack/HStack for layout
  - Keep animations consistent with `.animation(.easeInOut(duration: 0.5), value: someValue)`
- **Architecture**: Favor MVVM pattern with ObservableObject for view models
- **Comments**: Russian comments are acceptable for debugging but should be translated to English for final code