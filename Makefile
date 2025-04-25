.DEFAULT_GOAL := help

# Help
help:
	@echo "Usage:"
	@echo "  make tag-major MAJOR=v1    - Tag the latest commit as v1 (or v2, v3...) and push"
	@echo "  make tag-release VERSION=vX.Y.Z - Tag the latest commit with a full version and push"

# Tag the latest commit as a major version (v1, v2, v3, etc.)
tag-major:
ifndef MAJOR
	$(error MAJOR is undefined. Usage: make tag-major MAJOR=v1)
endif
	@git tag -d $(MAJOR) || true
	@git tag $(MAJOR)
	@git push origin $(MAJOR) --force
	@echo "✅ Tagged and pushed $(MAJOR)"

# Tag the latest commit with a specific version (vX.Y.Z)
tag-release:
ifndef VERSION
	$(error VERSION is undefined. Usage: make tag-release VERSION=vX.Y.Z)
endif
	@git tag $(VERSION)
	@git push origin $(VERSION)
	@echo "✅ Tagged and pushed $(VERSION)"
