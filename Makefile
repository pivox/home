PYTHON ?= /usr/bin/python3

.PHONY: test build validate ios-build project preview

test:
	./scripts/swift-test.sh

build:
	./scripts/swift-build.sh --target DeuxUI

validate:
	$(PYTHON) scripts/validate.py

ios-build:
	./scripts/ios-build.sh

project:
	$(PYTHON) scripts/generate_project.py

preview:
	./scripts/render-preview.sh
