.PHONY: generate open build test verify acceptance help

help:
	@echo "LocusSweep"
	@echo "  make generate   - xcodegen → LocusSweep.xcodeproj"
	@echo "  make open       - generate + open in Xcode"
	@echo "  make build      - unsigned local Debug build (macOS + Xcode required)"
	@echo "  make test       - LocusSweepCore unit tests (SwiftPM; Linux OK)"
	@echo "  make verify     - Linux static verify (same as test; no tag)"
	@echo "  make acceptance - print path to ACCEPTANCE.md checklist"

generate:
	@command -v xcodegen >/dev/null || (echo "Install XcodeGen: brew install xcodegen" && exit 1)
	xcodegen generate

open: generate
	open LocusSweep.xcodeproj

build: generate
	xcodebuild -scheme LocusSweep -configuration Debug -destination 'platform=macOS' \
		CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=YES build

test:
	swift test

verify: test
	@echo "Linux static verify passed (LocusSweepCore). No tag."

acceptance:
	@echo "Manual acceptance checklist: ACCEPTANCE.md"
