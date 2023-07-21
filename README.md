# riscv_ctb_challenges

Fri July 21 : 
* Executed 'source setup/sh'
* Tested git push


## Tutorial justifications
#### (tutorial/directed)
Executing 'make' will:
1. Optionally clean output files
2. Compile test.S into a RV32I executable 'test.elf'
3. Use rv32 toolchain to produce objdump of test.elf into test.disass
4. Check test.elf against spike simulator
    a. Open successful simulation, produce another dump 'test_spike.dump' from test.elf. This file shows a simulated run of the executable.

#### (tutorial/aapg_random)
Analysis of make (first and only file present):
all: gen compile disass spike

# Use the aapg tool to generate work/, config.ini, test_template.S, test.ld, and test.S
gen: clean
	aapg setup
	aapg gen --asm_name test --output_dir $(PWD) --arch rv32

* What are these generated files?
    - work/     : directory which contains library files and supporting assembly (crt.S) which are used for following compilation.
    - config.ini        : ????
    - test_template.S   : ???
    - test.ld   : Defines sections for test
    - test.S    : Random Assembly Program Generated using aapg. Comes with a 'Seed' i.e. 11490793650929849734

# Use generated test.ld, test.S and crt.S to compile test.elf
compile:
	riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -I$(PWD)/work/common -T$(PWD)/test.ld test.S $(PWD)/work/common/crt.S -o test.elf

# Disassemble the same test.elf into test.disass
disass: compile
	@echo '[UpTickPro] Test Disassembly ------'
	riscv32-unknown-elf-objdump -D test.elf > test.disass

# Check against spike
spike: compile
	@echo '[UpTickPro] Spike Run ------'
	spike --isa=rv32i test.elf 
	spike --log-commits --log  test_spike.dump --isa=rv32i +signature=test_spike_signature.log test.elf

clean:
	@echo '[UpTickPro] Clean ------'
	rm -rf work *.elf *.disass *.log *.dump *.ld *.S *.ini
