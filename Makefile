# configurable via env or cmd line
DOCKER_TAG   ?= latest
DOCKER_ROOT  ?=
DOCKER_FLAGS ?=

# package details
VERSION  := $(shell git describe --always --long --dirty || echo "0.0.0")
PKG_LIST := $(shell go list ./... | grep -v /vendor/)

all: static

dev: docker-dev
	npm run dev

backend:
	go build -i -v -o bin/backend -ldflags="-X main.version=${VERSION}" .

test:
	go test -short ${PKG_LIST}
	npm run test

build:
	npm run build-css
	npm run build

vet:
	go vet ${PKG_LIST}

lint:
	gometalinter --enable-all --deadline=300s --vendor ./...

static: vet lint
	go build -i -v -o bin/backend-v${VERSION} -tags netgo -ldflags="-extldflags \"-static\" -w -s -X main.version=${VERSION}" .

docker: build
	docker build -t ${DOCKER_ROOT}esi-isk:${DOCKER_TAG} ${DOCKER_FLAGS} .

docker-dev: docker-pg docker-api

docker-pg:
	-@docker kill esi-isk-pg > /dev/null 2>&1
	-@docker rm esi-isk-pg > /dev/null 2>&1
	docker run -d \
    --name esi-isk-pg \
    --hostname esi-isk-pg \
    -e POSTGRES_PASSWORD=default \
    -e POSTGRES_USER=esi-isk \
    -e POSTGRES_DB=esi-isk \
    -v ${PWD}/sql:/docker-entrypoint-initdb.d:ro \
    postgres:alpine > /dev/null

docker-api: docker
	-@docker kill esi-isk > /dev/null 2>&1
	-@docker rm esi-isk > /dev/null 2>&1
	docker run -d \
    -p 8080:8080 \
    --name esi-isk \
    --hostname esi-isk \
    --link esi-isk-pg:postgres \
    -v ${PWD}/public:/public:ro \
    -v ${PWD}/secret:/secret:ro \
    esi-isk /esi-isk --debug > /dev/null

.PHONY: all dev backend test build vet lint static docker docker-dev docker-pg docker-api
