PYTHON ?= python3
VENV   ?= .venv
BIN    := $(VENV)/bin
DBT    := $(BIN)/dbt
TARGET ?= dev

.PHONY: install parse check build test docs score clean new-piece new-instrument new-effect

install: $(VENV)/.installed

$(VENV)/.installed: pyproject.toml
	$(PYTHON) -m venv $(VENV)
	$(BIN)/pip install --upgrade pip
	$(BIN)/pip install -e .
	touch $@

# make build PIECE=nocturne (or PIECE=path/to/piece.yml) renders one piece, PIECE=all every piece in pieces/.
# dbt build stops without PIECE, so nothing renders every piece by accident (macros/require_piece.sql).
PIECE_VARS := $(if $(PIECE),--vars '{piece: $(PIECE)}')

parse: install
	$(DBT) parse --target $(TARGET)

check: parse
	$(BIN)/python scripts/check_layers.py target/manifest.json

build: check
	$(DBT) build --target $(TARGET) $(PIECE_VARS)

test: install
	$(DBT) test --target $(TARGET) $(PIECE_VARS)

# Browse every model and the piece and instrument tables, with lineage, at http://localhost:8080. Run make build first.
docs: install
	$(DBT) docs generate --target $(TARGET)
	$(DBT) docs serve --target $(TARGET)

# make score PIECE=nocturne lists a built piece's notes by bar and beat; PIECE=all or no PIECE for every built piece.
score: install
	$(DBT) show --select score_listing --target $(TARGET) --limit 1000 $(if $(PIECE),--vars '{piece: $(PIECE)}')

# make new-piece NAME=my_piece, make new-instrument NAME=my_instrument, make new-effect NAME=my_effect
new-piece: install
	$(BIN)/python scripts/new_from_template.py piece $(NAME)

new-instrument: install
	$(BIN)/python scripts/new_from_template.py instrument $(NAME)

new-effect: install
	$(BIN)/python scripts/new_from_template.py effect $(NAME)

clean:
	$(DBT) clean
	rm -f *.duckdb *.duckdb.wal output/*.wav output/*.mid
