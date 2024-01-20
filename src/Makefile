EXTENSION = embedefy
EXTENSION_VERSION ?= 0.2.0
MODULE_big = embedefy
PG_CONFIG = pg_config
DATA = $(wildcard sql/*.sql)
OBJS = embedefy.o api.o strings.o
SHLIB_LINK = -lcurl -ljson-c

all: sql/$(EXTENSION)--$(EXTENSION_VERSION).sql

sql/$(EXTENSION)--$(EXTENSION_VERSION).sql: sql/$(EXTENSION).sql
	cp $< $@

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
