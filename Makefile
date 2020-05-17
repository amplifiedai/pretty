.PHONY: check clean

check: deps lib/pretty.ex
	mix format --check-formatted --dry-run --check-equivalent
	mix compile --warnings-as-errors
	mix coveralls.html
	mix credo --strict
	mix dialyzer
	mix docs
	@echo "OK"

mix.lock: mix.exs
	mix deps.get
	mix deps.unlock --unused
	mix deps.clean --unused
	touch $@

deps: mix.lock
	mix deps.get
	touch $@

lib/pretty.ex: README.md
	touch $@

clean:
	rm -rf _build/test/lib _build/dev/lib _build/prod/lib cover deps doc
