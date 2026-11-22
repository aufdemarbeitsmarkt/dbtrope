PYTHON ?= python3
VENV   ?= .venv
BIN    := $(VENV)/bin
DBT    := $(BIN)/dbt
TARGET ?= dev

.PHONY: install registry parse check build test clean

install: $(VENV)/.installed

$(VENV)/.installed: pyproject.toml
	$(PYTHON) -m venv $(VENV)
	$(BIN)/pip install --upgrade pip
	$(BIN)/pip install -e .
	touch $@

# Lists the pieces for base/pieces; see scripts/build_registry.py.
registry: install
	$(BIN)/python scripts/build_registry.py

parse: registry
	$(DBT) parse --target $(TARGET)

check: parse
	$(BIN)/python scripts/check_layers.py target/manifest.json

build: check
	$(DBT) build --target $(TARGET)

test: registry
	$(DBT) test --target $(TARGET)

clean:
	$(DBT) clean
	rm -f *.duckdb *.duckdb.wal output/*.wav
