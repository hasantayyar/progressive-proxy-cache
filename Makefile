.PHONY : all
all: build

VERSION := 1.0.39

build:
	@docker build --tag=cache-proxy .
	@docker tag cache-proxy "cache-proxy:v${VERSION}"
run:
	@docker run -p 3128:3128 -it "cache-proxy:v$(VERSION)"

