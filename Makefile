PYTHON ?= python3
VENV   ?= .venv
BIN    := $(VENV)/bin
DBT    := $(BIN)/dbt
TARGET ?= dev

.PHONY: install registry parse check build test clean new-piece new-instrument

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

# make new-piece NAME=my_piece, make new-instrument NAME=my_instrument
new-piece: install
	$(BIN)/python scripts/new_model.py piece $(NAME)

new-instrument: install
	$(BIN)/python scripts/new_model.py instrument $(NAME)

clean:
	$(DBT) clean
	rm -f *.duckdb *.duckdb.wal output/*.wav
