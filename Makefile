PACKAGE := Packages/ReArcKit

.PHONY: bootstrap project build test app open format lint clean

# Install development tools listed in the Brewfile.
bootstrap:
	brew bundle

# Generate ReArc.xcodeproj from project.yml.
project:
	xcodegen generate

# Build and test the Swift package (no Xcode project needed).
build:
	swift build --package-path $(PACKAGE)

test:
	swift test --package-path $(PACKAGE)

# Build the .app bundle.
app: project
	xcodebuild -project ReArc.xcodeproj -scheme ReArc -configuration Debug -derivedDataPath .build/DerivedData -skipMacroValidation $(XCODEBUILD_FLAGS) build

open: project
	open ReArc.xcodeproj

format:
	swift format --in-place --recursive App Packages

lint:
	swift format lint --strict --recursive App Packages

clean:
	rm -rf .build $(PACKAGE)/.build ReArc.xcodeproj
