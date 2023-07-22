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

## Challenge_level_1
### Challenge1_logical
Attempting to compile test.S with riscv32-unknown-elf-gcc results in failure due to multiple instances of the same error. 

[1] test.S:15855: Error: illegal operands `and s7,ra,z4'
[2] test.S:25584: Error: illegal operands `andi s5,t1,s0'

Instruction [1] has an illegal operand 'z4' which is a nonexistant register in the ISA. This could very well have been a mistake and/or mistyped.

Instruction [2] uses the 'andi' sintruction which expects a destination register, source register, and a 12-bit immediate that would be sign-extended and used in the following ALU operation. [2] indicates two source registers instead of providing immediate data which is illegal.

Again, both of these instances could be present due to human error during insertion into test.S. Since both instructions are present in other parts of the test, and I'm not sure what register and immediate data are desired for instructions [1] and [2] respectively, I will remove them for now.

### Challenge2_loop
While the code compiles, spike simulation reveals that there is some logic causing the simulation to run for a long time before spike reports 

*** FAILED *** (tohost = 669)
make: *** [Makefile:11: spike] Error 157

Inspecting the code the desired functionality seems clear:
1. Initialize pointer to .data section which contains test inputs and expected results.
2. Increment pointer (t0)
3. Load inputs and test the result of addition against the stored expected value.
	a. If the two match, resume testing be returning to the start of the loop.
	b. Else, consider the test failed.

The problem with this logic is that the loop continues as an addition of two inputs located at (t0) and 4(t0) matches that at 8(t0).
The program truly starts running away when t0 actually begins to point past the initialized  cases within RVTEST_DATA.
0 + 0 = 0 is constantly tested, and the loop continues.

In order to fix this, an additional counter can be utilized to keep track of the number of tests conducted.
t5 was actually introduced in the original source, holding a value of 3 for the number of test cases, it's just never utilized for branching logic.

Therefore I changed this:
```asm
  la t0, test_cases
  li t5, 3

loop:
  lw t1, (t0)
  lw t2, 4(t0)
  lw t3, 8(t0)
  add t4, t1, t2
  addi t0, t0, 12
  beq t3, t4, loop        # check if sum is correct
  j fail

test_end:
```
To **this**:
  ```asm
    la t0, test_cases 	# Initialize data ptr
    li t5, 3 			# Initialize test counter
  
  loop:   
	beqz t5, test_end	# for t5 tests
	lw t1, (t0)			# load input1
	lw t2, 4(t0)		# load input2
	lw t3, 8(t0)		# load checksum
	add t4, t1, t2		# compute sum
	addi t0, t0, 12		# increment pointer
	addi t5, t5, -1		# decrement test count
	beq t3, t4, loop        # check if sum is correct
	j fail

test_end:
  ```


