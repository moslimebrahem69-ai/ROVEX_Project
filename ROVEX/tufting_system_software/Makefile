# Top-level convenience Makefile.
#
#   make test      - run both the Python and the C test suites
#   make firmware  - build the firmware binary
#   make demo      - run the full pipeline against the example design,
#                    using the simulated hardware backend
#   make clean     - remove all build artifacts

.PHONY: test test-python test-firmware firmware demo clean

test: test-python test-firmware

test-python:
	python3 -m unittest discover -s edge_ai/tests -v

test-firmware:
	$(MAKE) -C firmware test

firmware:
	$(MAKE) -C firmware all

demo: firmware
	python3 -m edge_ai.cli --pattern examples/sample_flower_design.json \
	                        --out examples/optimized_path.csv
	./firmware/bin/ROVEX examples/optimized_path.csv sim examples/motor_commands.log

clean:
	$(MAKE) -C firmware clean
	rm -f examples/optimized_path.csv examples/motor_commands.log
