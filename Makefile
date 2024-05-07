ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

HFUZZ_ROOT := $(ROOT_DIR)/honggfuzz

FUZZING_WIRESHARK_DIR := $(ROOT_DIR)/fuzzing-wireshark
FUZZING_WIRESHARK_BUILD_DIR := $(ROOT_DIR)/fuzzing-wireshark-build

FUZZING_CC := $(HFUZZ_ROOT)/hfuzz_cc/hfuzz-clang
FUZZING_CXX := $(HFUZZ_ROOT)/hfuzz_cc/hfuzz-clang++
FUZZING_TARGET := $(FUZZING_WIRESHARK_BUILD_DIR)/run/tshark

FUZZING_CORPUS_DIR := $(ROOT_DIR)/corpus
FUZZING_CAMPAIGN_DIR := $(ROOT_DIR)/campaign

FUZZING_REPORT_DIR := $(ROOT_DIR)/fuzzing-report

FUZZING_COV_DIR := $(ROOT_DIR)/fuzzing-cov
FUZZING_COV_COUNTER_FILE := $(FUZZING_COV_DIR)/counter.txt

# FUZZING_PROFRAW_FILENAME := %cfuzzingbruh.profraw
FUZZING_PROFDATA_FILENAME := ./fuzzing-cov/indexed.profdata
PROBING_PROFRAW_FILENAME := probing.profraw
# PROBING_PROFRAW_FILENAME := ./fuzzing-wireshark-build/default.profraw

CFLAGS := -g -O1 -fsanitize=address,undefined -fsanitize-address-use-after-return=always -fno-omit-frame-pointer -fprofile-instr-generate -fcoverage-mapping
ASAN_OPTIONS=detect_stack_use_after_return=1:detect_leaks=0
LSAN_OPTIONS=suppressions=$(ROOT_DIR)/lsan.supp
UBSAN_OPTIONS=suppressions=$(ROOT_DIR)/ubsan.supp

all: build
.PHONY: all build build-fuzzing build-probing rebuild rebuild-fuzzing rebuild-probing clean clean-fuzzing clean-probing run-fuzzing
.ONESHELL:

build: build-fuzzing build-probing
clean: clean-fuzzing clean-probing
rebuild: rebuild-fuzzing rebuild-probing

build-fuzzing:
	##### Building wireshark for fuzzing ##### 
	sudo $(FUZZING_WIRESHARK_DIR)/tools/debian-setup.sh
	mkdir -p $(FUZZING_WIRESHARK_BUILD_DIR)
	cd $(FUZZING_WIRESHARK_BUILD_DIR)
	export WIRESHARK_VERSION_EXTRA=-fuzzing
	export CC=$(FUZZING_CC)
	export CXX=$(FUZZING_CXX)
	export CFLAGS="$(CFLAGS)"
	export CXXFLAGS="$(CFLAGS)"
	export ASAN_OPTIONS="$(ASAN_OPTIONS)"
	export LSAN_OPTIONS="$(LSAN_OPTIONS)"
	export UBSAN_OPTIONS="$(UBSAN_OPTIONS)"
	cmake -G Ninja $(FUZZING_WIRESHARK_DIR)
	cmake --build . -j`nproc`

clean-fuzzing:
	##### Cleaning wireshark for fuzzing ##### 
	rm -rf $(FUZZING_WIRESHARK_BUILD_DIR)

rebuild-fuzzing: clean-fuzzing build-fuzzing

run-fuzzing: $(FUZZING_CAMPAIGN_DIR)
	##### Running honggfuzz on wireshark for fuzzing #####
	mkdir -p $(FUZZING_COV_DIR)
	export ASAN_OPTIONS="$(ASAN_OPTIONS)"
	export LSAN_OPTIONS="$(LSAN_OPTIONS)"
	export UBSAN_OPTIONS="$(UBSAN_OPTIONS)"
	# $(HFUZZ_ROOT)/honggfuzz -t10 -i $(FUZZING_CAMPAIGN_DIR) --keep_output -n$(shell nproc) -- ./llvm-profile-run.sh $(FUZZING_COV_DIR) $(FUZZING_COV_COUNTER_FILE) $(FUZZING_TARGET) -r ___FILE___
	$(HFUZZ_ROOT)/honggfuzz -t10 -i $(FUZZING_CAMPAIGN_DIR) --keep_output -n$(shell nproc) -- $(FUZZING_TARGET) -r ___FILE___

run-probing:
ifndef PROBE_INPUT
	$(error PROBE_INPUT is not set: `make $@ PROBE_INPUT="..."`)
endif

	##### Running honggfuzz on wireshark for probing #####
	export ASAN_OPTIONS="$(ASAN_OPTIONS)"
	export LSAN_OPTIONS="$(LSAN_OPTIONS)"
	export UBSAN_OPTIONS="$(UBSAN_OPTIONS)"
	export LLVM_PROFILE_FILE="$(PROBING_PROFRAW_FILENAME)"
	$(FUZZING_TARGET) -r $(PROBE_INPUT)

$(FUZZING_CAMPAIGN_DIR):
	cp -r $(FUZZING_CORPUS_DIR) $(FUZZING_CAMPAIGN_DIR)

cleancov-fuzzing:
	rm -rf $(FUZZING_COV_DIR)

# report-fuzzing:
# 	##### Generating coverage report for fuzzing #####
# 	# find $(FUZZING_WIRESHARK_BUILD_DIR) -name default.profraw | xargs llvm-profdata merge -o main.profdata
# 	llvm-cov export $(FUZZING_WIRESHARK_BUILD_DIR)/run/tshark -instr-profile=$(FUZZING_PROFDATA_FILENAME) --format=lcov > lcov.info
# 	llvm-cov report $(FUZZING_WIRESHARK_BUILD_DIR)/run/tshark -instr-profile=$(FUZZING_PROFDATA_FILENAME)

report-probing:
	llvm-profdata merge -o indexed.profdata $(PROBING_PROFRAW_FILENAME)
	llvm-cov export $(FUZZING_WIRESHARK_BUILD_DIR)/run/tshark /home/themmokhtar/Desktop/projects/wireshark-fuzzer/fuzzing-wireshark-build/run/libwiretap.so.14.1.4 -instr-profile=indexed.profdata --format=lcov > lcov.info
	llvm-cov report $(FUZZING_WIRESHARK_BUILD_DIR)/run/tshark /home/themmokhtar/Desktop/projects/wireshark-fuzzer/fuzzing-wireshark-build/run/libwiretap.so.14.1.4 -instr-profile=indexed.profdata

	# llvm-profdata merge --text -o indexed.profdata $(PROBING_PROFRAW_FILENAME) 
	# # llvm-cov export $(FUZZING_WIRESHARK_BUILD_DIR)/run/tshark -instr-profile=$(PROBING_PROFRAW_FILENAME) --format=lcov > lcov.info
	# llvm-cov report $(FUZZING_WIRESHARK_BUILD_DIR)/run/tshark -instr-profile=indexed.profdata