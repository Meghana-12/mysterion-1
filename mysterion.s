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

.global mysterion
.type mysterion, %function


.macro byteslice_msg
    /*
     * Byteslice from msg buffer in 1 chunk of 4, and 2 chunks of 6
     * r0: pointer to msg/state
     * r2..r5: bytesliced (output) state
     */
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
.endm


.macro byteslice_key
    /*
     * Byteslice from key buffer in 1 chunk of 4, and 4 chunks of 3
     * r1: pointer to key
     * r6..r9: bytesliced (output) key
     */
    ldrb r9, [r1, #15]
    ldrb r8, [r1, #14]
    ldrb r7, [r1, #13]
    ldrb r6, [r1, #12]

    ldrb r12, [r1, #11]
    ldrb r11, [r1, #10]
    ldrb r10, [r1, #9]
    orr r9, r9, r12, lsl #8
    orr r8, r8, r11, lsl #8
    orr r7, r7, r10, lsl #8

    ldrb r12, [r1, #8]
    ldrb r11, [r1, #7]
    ldrb r10, [r1, #6]
    orr r6, r6, r12, lsl #8
    orr r9, r9, r11, lsl #16
    orr r8, r8, r10, lsl #16

    ldrb r12, [r1, #5]
    ldrb r11, [r1, #4]
    ldrb r10, [r1, #3]
    orr r7, r7, r12, lsl #16
    orr r6, r6, r11, lsl #16
    orr r9, r9, r10, lsl #24

    ldrb r12, [r1, #2]
    ldrb r11, [r1, #1]
    ldrb r10, [r1, #0]
    orr r8, r8, r12, lsl #24
    orr r7, r7, r11, lsl #24
    orr r6, r6, r10, lsl #24
.endm


.macro unbyteslice_state
    /*
     * r0 is destination buffer
     * r2-r5 bytesliced input state (*this input is consumed during execution*)
     */
    strb r2, [r0, #12]
    strb r3, [r0, #13]
    strb r4, [r0, #14]
    strb r5, [r0, #15]

    lsr r2, r2, #8
    lsr r3, r3, #8
    lsr r4, r4, #8
    lsr r5, r5, #8

    strb r2, [r0, #8]
    strb r3, [r0, #9]
    strb r4, [r0, #10]
    strb r5, [r0, #11]

    lsr r2, r2, #8
    lsr r3, r3, #8
    lsr r4, r4, #8
    lsr r5, r5, #8

    strb r2, [r0, #4]
    strb r3, [r0, #5]
    strb r4, [r0, #6]
    strb r5, [r0, #7]

    lsr r2, r2, #8
    lsr r3, r3, #8
    lsr r4, r4, #8
    lsr r5, r5, #8

    strb r2, [r0]
    strb r3, [r0, #1]
    strb r4, [r0, #2]
    strb r5, [r0, #3]
.endm


.macro add_key
    eor r2, r2, r6
    eor r3, r3, r7
    eor r4, r4, r8
    eor r5, r5, r9
.endm


.macro sbox
    /*
     * Equivalent Python code:
     *
     * a = (state[0] & state[1]) ^ state[2] # Use r10
     * state[2] = (state[1] | state[2]) ^ state[3]
     * state[3] = (a & state[3]) ^ state[0]
     * state[1] = (state[2] & state[0]) ^ state[1] # new state[2] value
     *            ^~~~~~~~~~~~~~ Use r11
     * state[0] = a
     */
    and r10, r2, r3
    eor r10, r10, r4
    orr r4, r4, r3
    eor r4, r4, r5
    and r5, r5, r10
    eor r5, r5, r2
    and r11, r4, r2
    eor r3, r3, r11
    mov r2, r10
.endm


mysterion:
    push {r4-r12}
    byteslice_msg
    byteslice_key
    /* From this point [r0, r2..r9] are in use */
    add_key
    sbox
    mov r0, r3

    pop {r4-r12}
    bx lr
