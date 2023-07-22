# See https://gitlab.com/vyoma_systems/common/-/blob/main/LICENSE.vyoma for more details
 
#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  .align 2
  .option norvc
  li TESTNUM, 2

  la t0, test_cases
  li t5, 3

loop:
  beqz t5, test_end	# for t5 tests
  lw t1, (t0)			  # load input1
  lw t2, 4(t0)		  # load input2
  lw t3, 8(t0)		  # load checksum
  add t4, t1, t2		# compute sum
  addi t0, t0, 12		# increment pointer
  addi t5, t5, -1		# decrement test count
  beq t3, t4, loop  # check if sum is correct
  j fail

test_end:

TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

test_cases:
  .word 0x20               # input 1
  .word 0x20               # input 2
  .word 0x40               # sum
  .word 0x03034078
  .word 0x5d70344d
  .word 0x607374C5
  .word 0xcafe
  .word 0x1
  .word 0xcaff

RVTEST_DATA_END