# See https://gitlab.com/vyoma_systems/common/-/blob/main/LICENSE.vyoma for more details
 
#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  .align 2
  .option norvc

  li TESTNUM, 2
illegal_instruction:
  .word 0              
  j fail
  TEST_PASSFAIL

  .align 8
  .global mtvec_handler
mtvec_handler: # Arrived here from <trap_vector>
  li t1, CAUSE_ILLEGAL_INSTRUCTION  # Since we know it's an illegal instruction we save that code to t1
  csrr t0, mcause                   # check the code that got us here
  bne t0, t1, fail                  # If these aren't equal, we fail
  csrr t0, mepc                     # Check mepc, it holds the PC of illegal instruction
  addi t0, t0, 8                    # +4 for 'j fail', +8 for TEST_PASSFAIL
  csrw mepc, t0
  mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END