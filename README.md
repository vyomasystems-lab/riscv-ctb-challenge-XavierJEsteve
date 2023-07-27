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

### Challenge2_loop
In test.S, there is an illegal instruction of all zeros:

**Execution from spike --isa=rv32i -d test.elf**
core   0: 0x800001a0 (0x00000000) c.unimp
core   0: exception trap_illegal_instruction, epc 0x800001a0
core   0:           tval 0x00000000

This leads to the processor pointing the pc to the trap_vector at 0x80000004.
Within this trap vector, there are checks to test for User, Supervisor, and Machine ECALLs.
Once it is determined the exception is of another nature, we move to handle_exception.
Within handle_exception, the value of mepc, the value for PC at the time of exception is loaded into a temp register, which is then populated with this sum in addition to the number of bytes that should be skipped in order to move past the exception. This seems valid since the instruction should not be executed again.

```asm
mtvec_handler: # Arrived here from <trap_vector>
  li t1, CAUSE_ILLEGAL_INSTRUCTION  # Since we know it's an illegal instruction we save that code to t1
  csrr t0, mcause                   # check the code that got us here
  bne t0, t1, fail                  # If these aren't equal, we fail
  csrr t0, mepc                     # Check mepc, it holds the PC of illegal instruction
  addi t0, t0, 8                    # +4 for 'j fail', +8 for TEST_PASSFAIL
  csrw mepc, t0
  mret
```
With this change, the execution carries on from TEST_PASSFAIL defined in riscv_test.h.

## Challenge_level_2
### Challenge1_instructions

*TODO: Introduce AAPG tools*


Attempting to use make would reveal in issue in compiling the generated test. There are many instructions with the following:

Error: unrecognized opcode 'rem/mul/div/etc.'

The unrecognized opcodes all appear to be a part of the M extension for multiplication and division operations. Since our target is to test RV32I funcionality, this probably needs to be fixed in the rv32i.yaml (the name also hints at an intention to use RV32I).

Investigating rv32i.yaml shows that  within 'isa-instruction-distribution', 'rel_rv64m' is set to 10, equal to all other tested instructions but notable not 0 and not of the base RV32I. Changing this value to 0 results in proper generation -> compilation -> disassembly.

### Challenge2_exceptions

The AAPG tool makes it possible to test a roughly definable distribution of rv[32|64]g instructions and exceptions. In order to generate ~10 illegal instruction exception calls I created a custom configuration file 'rv32i.yaml' focusing on the following groups/variables:

customer_trap_handler: true

isa-instruction-distribution
  rel_sys.csr: 1
  rel_rv32i.ctrl: 1
  rel_rv32i.compute: 20
  rel_rv32i.data: 20

csr-sections:
  sections: 0x000, 0x200:0x202, 0xff0:0xfff
  I utilized a range from an example demo. A usefull list of CSRs can be found (here)[https://five-embeddev.com/quickref/csrs.html]. There just needs to be some set so that the necessary rel_sys.csr instructions have something to work with. AAPG automatically ignores the xtvec, xepc, xcause and xstatus registers.

As a result, generated tests produce a variable 10-30 exceptions per simulation in spike. Spike simulations however seem to be caught in a loop about 10% of the time. Honestly the lack of explicit documentation and deterministic behavior calls some aspects of the aapg tool into question, but later review of the code base could prove usefule if I have time to revisit this challenge later.

## Challenge_level_3