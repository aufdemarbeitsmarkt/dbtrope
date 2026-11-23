PYTHON ?= python3
VENV   ?= .venv
BIN    := $(VENV)/bin
DBT    := $(BIN)/dbt
TARGET ?= dev

.PHONY: install registry parse check build test docs score clean new-piece new-instrument

install: $(VENV)/.installed

$(VENV)/.installed: pyproject.toml
	$(PYTHON) -m venv $(VENV)
	$(BIN)/pip install --upgrade pip
	$(BIN)/pip install -e .
	touch $@

# Writes macros/registry.sql from the piece and instrument YAML; see scripts/build_registry.py.
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

# Browse every piece, instrument and model, with lineage, at http://localhost:8080. Run make build first.
docs: registry
	$(DBT) docs generate --target $(TARGET)
	$(DBT) docs serve --target $(TARGET)

# make score PIECE=nocturne lists a built piece's notes by bar and beat; leave PIECE out for every piece.
score: registry
	$(DBT) show --select score_listing --target $(TARGET) --limit 1000 $(if $(PIECE),--vars '{piece: $(PIECE)}')

# make new-piece NAME=my_piece, make new-instrument NAME=my_instrument
new-piece: install
	$(BIN)/python scripts/new_model.py piece $(NAME)

new-instrument: install
	$(BIN)/python scripts/new_model.py instrument $(NAME)

clean:
	$(DBT) clean
	rm -f *.duckdb *.duckdb.wal output/*.wav output/*.mid
