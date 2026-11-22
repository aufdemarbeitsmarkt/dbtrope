PYTHON ?= python3
VENV   ?= .venv
BIN    := $(VENV)/bin
DBT    := $(BIN)/dbt
TARGET ?= dev

.PHONY: install deps parse check build test clean

install: $(VENV)/.installed

$(VENV)/.installed: pyproject.toml
	$(PYTHON) -m venv $(VENV)
	$(BIN)/pip install --upgrade pip
	$(BIN)/pip install -e .
	touch $@

parse: install
	$(DBT) parse --target $(TARGET)

check: parse
	$(BIN)/python scripts/check_layers.py target/manifest.json

build: check
	$(DBT) build --target $(TARGET)

test: install
	$(DBT) test --target $(TARGET)

clean:
	$(DBT) clean
	rm -f *.duckdb *.duckdb.wal output/*.wav
