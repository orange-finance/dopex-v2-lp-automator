.PHONY: test coverage/lcov coverage/html
coverage:
	forge coverage --no-match-test "Skip"
coverage/lcov:
	forge coverage --no-match-test "Skip" --report lcov
coverage/html: coverage/lcov
	genhtml -o report --branch-coverage lcov.info
