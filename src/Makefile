all: tclinterp.so
CC=gcc
BUILD=build

tclinterp.so: $(BUILD)/tclinterp.o $(BUILD)/tclinterp_wrap.o
	mkdir -p $(BUILD)
	$(CC) -shared  $(BUILD)/tclinterp.o $(BUILD)/tclinterp_wrap.o /usr/local/lib/libtclstub.a -o $(BUILD)/tclinterp.so

$(BUILD)/tclinterp.o: interp.h interp.c
	mkdir -p $(BUILD)
	$(CC) -c interp.c -fPIC -Wall -O3 -g -march=native -o $(BUILD)/tclinterp.o

$(BUILD)/tclinterp_wrap.o: tclinterp_wrap.c interp.h
	mkdir -p $(BUILD)
	$(CC) -c tclinterp_wrap.c -I/usr/include/tcl -fPIC -O3 -DUSE_TCL_STUBS -o $(BUILD)/tclinterp_wrap.o



clean:
	rm -rf $(BUILD) tclinterp.so
