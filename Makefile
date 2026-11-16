-include local.mk

PACT_LIB_DIR := $(CURDIR)/provider-go/.lib

.PHONY: broker-up broker-down broker-reset broker-bootstrap demo-broker demo-break demo-new-consumer-field all consumers consumer-ts consumer-python consumer-java provider clean

all: consumers provider

consumers: consumer-ts consumer-python consumer-java

consumer-ts:
	cd consumer-ts && pnpm install --frozen-lockfile && pnpm test

consumer-python:
	cd consumer-python && uv sync && uv run pytest -q

consumer-java:
	cd consumer-java && mvn -B -q test

provider:
	cd provider-go && go run github.com/pact-foundation/pact-go/v2 install -d $(PACT_LIB_DIR)
	cd provider-go && LIBRARY_PATH=$(PACT_LIB_DIR) DYLD_LIBRARY_PATH=$(PACT_LIB_DIR) LD_LIBRARY_PATH=$(PACT_LIB_DIR) go test -count=1 -v ./...

broker-up:
	docker compose up -d --wait

broker-down:
	docker compose down -v

broker-bootstrap:
	./pipelines/bootstrap.sh

broker-reset: broker-down broker-up broker-bootstrap

demo-broker:
	./pipelines/demo-broker.sh

demo-break:
	./pipelines/demo-break.sh

demo-new-consumer-field:
	./pipelines/demo-new-consumer-field.sh

clean:
	rm -f pacts/*.json
	rm -rf consumer-ts/node_modules consumer-python/.venv consumer-python/.pytest_cache consumer-java/target provider-go/.lib
