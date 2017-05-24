/*
 * C Application Binary Interface (ABI)
 * • Agreement on how to deal with parameters and return values (and a
 * lot more)
 * • If it fits, parameters in r0-r3
 * • Otherwise, a part in r0-r3 and the rest on the stack
 * • Return value in r0
 * • The callee(!) should preserve r4-r12 if it overwrites them
 * • Of course, for private subroutines, you can ignore this ABI completely
 * • But pay attention when calling your assembly from, e.g., C
 */

.syntax unified
.cpu cortex-m4



/*
 * arguments:
 * - r0: pointer to input buffer of 16 octets
 * returns:
 * - {rout0 - 3} bitsliced format of rin data
 */
.macro byteslice rin:req, rout0:req, rout1:req, rout2:req, rout3:req, rtmp:req
    mov \rout0, #0
    mov \rout1, #0
    mov \rout2, #0
    mov \rout3, #0



.endm

.macro for code:req
    \code
.endm

.macro incl code:req
    \code
.endm




.global mysterion
.type mysterion, %function
/*
 * arguments:
 * - r0: pointer to the message buffer, the output will be written here
 * - r1: pointer to the key buffer
 * returns: void
 */
.macro madd i
  .long \i
  mov r0, #(((42)+\i)/7)
.endm


byteslice_msg:
    // Byteslice from msg buffer in 1 chunks of 4, and 2 chunks of 6
    ldrb r5, [r0, #15]
    ldrb r4, [r0, #14]
    ldrb r3, [r0, #13]
    ldrb r2, [r0, #12]

    ldrb r11, [r0, #11]
    ldrb r10, [r0, #10]
    ldrb r9, [r0, #9]
    ldrb r8, [r0, #8]
    ldrb r7, [r0, #7]
    ldrb r6, [r0, #6]
    orr r5, r5, r11, lsl #8
    orr r4, r4, r10, lsl #8
    orr r3, r3, r9, lsl #8
    orr r2, r2, r8, lsl #8
    orr r5, r5, r7, lsl #16
    orr r4, r4, r6, lsl #16

    ldrb r11, [r0, #5]
    ldrb r10, [r0, #4]
    ldrb r9, [r0, #3]
    ldrb r8, [r0, #2]
    ldrb r7, [r0, #1]
    ldrb r6, [r0, #0]
    orr r3, r3, r11, lsl #16
    orr r2, r2, r10, lsl #16
    orr r5, r5, r9, lsl #24
    orr r4, r4, r8, lsl #24
    orr r3, r3, r7, lsl #24
    orr r2, r2, r6, lsl #24

    b mysterion_ret1

.macro unbyteslice_state
    // r0 is destination buffer
    // r2-r5 bytesliced input state
    @mov r11, r5, lsr #24
    @strb [r0, #15], r5, lsr #24

.endm


mysterion:
    push {r4-r12}
    b byteslice_msg
mysterion_ret1:
    pop {r4-r12}
    bx lr
