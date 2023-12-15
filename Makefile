.PHONY: test coverage/lcov coverage/html
coverage/lcov:
	forge coverage --report lcov
coverage/html: coverage/lcov
	genhtml -o report --branch-coverage lcov.info
