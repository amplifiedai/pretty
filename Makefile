.PHONY: check clean

check: deps lib/pretty.ex
	mix format --check-formatted --dry-run --check-equivalent
	mix compile --warnings-as-errors
	mix coveralls.html
	mix credo --strict
	mix dialyzer --halt-exit-status
	mix docs
	@echo "OK"

deps: mix.lock
	mix deps.get

lib/pretty.ex: README.md
	touch $@

clean:
	rm -rf _build/test/lib _build/dev/lib _build/prod/lib cover deps doc
