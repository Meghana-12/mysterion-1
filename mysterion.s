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


.macro gf16_mul_lit p0,p1,p2,p3
    /*
     * Bitsliced multiplication of [r2..r5] with the literal polynomials
     * specified in p0,p1,p2,p3, modulo x^4 + x + 1.
     * - p0,p1,p2,p3: literal bitsliced polynomial
     * - [r2..r5]: input (unaltered)
     * - [r1,r10..12]: output
     * - [r0]: temporary value
     */
    and r1,  r5, #(\p0)
    and r10, r5, #(\p1)
    and r11, r5, #(\p2)
    and r12, r5, #(\p3)

    and r0,  r4,  #(\p1)
    eor r1,  r1,  r0
    and r0,  r4,  #(\p2)
    eor r10, r10, r0
    and r0,  r4,  #((\p3)^\p0)
    eor r11, r11, r0
    and r0,  r4,  #(\p0)
    eor r12, r12, r0

    and r0,  r3,  #(\p2)
    eor r1,  r1,  r0
    and r0,  r3,  #((\p3)^\p0)
    eor r10, r10, r0
    and r0,  r3,  #((\p0)^\p1)
    eor r11, r11, r0
    and r0,  r3,  #(\p1)
    eor r12, r12, r0

    and r0,  r2,  #((\p3)^\p0)
    eor r1,  r1,  r0
    and r0,  r2,  #((\p0)^\p1)
    eor r10, r10, r0
    and r0,  r2,  #((\p1)^\p2)
    eor r11, r11, r0
    and r0,  r2,  #(\p2)
    eor r12, r12, r0
.endm


.macro lbox
    /*
     * Execution of the Lbox on the state:
     * - State: [r2..r5]
     * - Temporary registers: [r0, r1, r10..r12]
     */

    /* Round 1 */
    gf16_mul_lit 0x55555555,0x1c1c1c1c,0x36363636,0x3e3e3e3e
    eor r0, r1, r1, lsl #1 /* accumulate the result for reg[0] */
    eor r0, r0, r1, lsl #2
    eor r0, r0, r1, lsl #3
    eor r0, r0, r1, lsl #4
    eor r0, r0, r1, lsl #5
    eor r0, r0, r1, lsl #6
    eor r0, r0, r1, lsl #7
    and r0, r0, #0x80808080 /* masked addition of first polynomial */
    eor r2, r2, r0
    eor r0, r10, r10, lsl #1 /* accumulate the result for reg[1] */
    eor r0, r0, r10, lsl #2
    eor r0, r0, r10, lsl #3
    eor r0, r0, r10, lsl #4
    eor r0, r0, r10, lsl #5
    eor r0, r0, r10, lsl #6
    eor r0, r0, r10, lsl #7
    and r0, r0, #0x80808080 /* masked addition of first polynomial */
    eor r3, r3, r0
    eor r0, r11, r11, lsl #1 /* accumulate the result for reg[2] */
    eor r0, r0, r11, lsl #2
    eor r0, r0, r11, lsl #3
    eor r0, r0, r11, lsl #4
    eor r0, r0, r11, lsl #5
    eor r0, r0, r11, lsl #6
    eor r0, r0, r11, lsl #7
    and r0, r0, #0x80808080 /* masked addition of first polynomial */
    eor r4, r4, r0
    eor r0, r12, r12, lsl #1 /* accumulate the result for reg[3] */
    eor r0, r0, r12, lsl #2
    eor r0, r0, r12, lsl #3
    eor r0, r0, r12, lsl #4
    eor r0, r0, r12, lsl #5
    eor r0, r0, r12, lsl #6
    eor r0, r0, r12, lsl #7
    and r0, r0, #0x80808080 /* masked addition of first polynomial */
    eor r5, r5, r0

    /* Round 2 */
    gf16_mul_lit 0xaaaaaaaa,0x0e0e0e0e,0x1b1b1b1b,0x1f1f1f1f
    eor r0, r1, r1, lsl #1 /* accumulate the result for reg[0] */
    eor r0, r0, r1, lsl #2
    eor r0, r0, r1, lsl #3
    eor r0, r0, r1, lsl #4
    eor r0, r0, r1, lsl #5
    eor r0, r0, r1, lsl #6
    eor r0, r0, r1, asr #1
    and r0, r0, #0x40404040 /* masked addition of first polynomial */
    eor r2, r2, r0
    eor r0, r10, r10, lsl #1 /* accumulate the result for reg[1] */
    eor r0, r0, r10, lsl #2
    eor r0, r0, r10, lsl #3
    eor r0, r0, r10, lsl #4
    eor r0, r0, r10, lsl #5
    eor r0, r0, r10, lsl #6
    eor r0, r0, r10, asr #1
    and r0, r0, #0x40404040 /* masked addition of first polynomial */
    eor r3, r3, r0
    eor r0, r11, r11, lsl #1 /* accumulate the result for reg[2] */
    eor r0, r0, r11, lsl #2
    eor r0, r0, r11, lsl #3
    eor r0, r0, r11, lsl #4
    eor r0, r0, r11, lsl #5
    eor r0, r0, r11, lsl #6
    eor r0, r0, r11, asr #1
    and r0, r0, #0x40404040 /* masked addition of first polynomial */
    eor r4, r4, r0
    eor r0, r12, r12, lsl #1 /* accumulate the result for reg[3] */
    eor r0, r0, r12, lsl #2
    eor r0, r0, r12, lsl #3
    eor r0, r0, r12, lsl #4
    eor r0, r0, r12, lsl #5
    eor r0, r0, r12, lsl #6
    eor r0, r0, r12, asr #1
    and r0, r0, #0x40404040 /* masked addition of first polynomial */
    eor r5, r5, r0

    /* Round 3 */
    gf16_mul_lit 0x55555555,0x07070707,0x8d8d8d8d,0x8f8f8f8f
    eor r0, r1, r1, lsl #1 /* accumulate the result for reg[0] */
    eor r0, r0, r1, lsl #2
    eor r0, r0, r1, lsl #3
    eor r0, r0, r1, lsl #4
    eor r0, r0, r1, lsl #5
    eor r0, r0, r1, asr #1
    eor r0, r0, r1, asr #2
    and r0, r0, #0x20202020 /* masked addition of first polynomial */
    eor r2, r2, r0
    eor r0, r10, r10, lsl #1 /* accumulate the result for reg[1] */
    eor r0, r0, r10, lsl #2
    eor r0, r0, r10, lsl #3
    eor r0, r0, r10, lsl #4
    eor r0, r0, r10, lsl #5
    eor r0, r0, r10, asr #1
    eor r0, r0, r10, asr #2
    and r0, r0, #0x20202020 /* masked addition of first polynomial */
    eor r3, r3, r0
    eor r0, r11, r11, lsl #1 /* accumulate the result for reg[2] */
    eor r0, r0, r11, lsl #2
    eor r0, r0, r11, lsl #3
    eor r0, r0, r11, lsl #4
    eor r0, r0, r11, lsl #5
    eor r0, r0, r11, asr #1
    eor r0, r0, r11, asr #2
    and r0, r0, #0x20202020 /* masked addition of first polynomial */
    eor r4, r4, r0
    eor r0, r12, r12, lsl #1 /* accumulate the result for reg[3] */
    eor r0, r0, r12, lsl #2
    eor r0, r0, r12, lsl #3
    eor r0, r0, r12, lsl #4
    eor r0, r0, r12, lsl #5
    eor r0, r0, r12, asr #1
    eor r0, r0, r12, asr #2
    and r0, r0, #0x20202020 /* masked addition of first polynomial */
    eor r5, r5, r0

    /* Round 4 */
    gf16_mul_lit 0xaaaaaaaa,0x83838383,0xc6c6c6c6,0xc7c7c7c7
    eor r0, r1, r1, lsl #1 /* accumulate the result for reg[0] */
    eor r0, r0, r1, lsl #2
    eor r0, r0, r1, lsl #3
    eor r0, r0, r1, lsl #4
    eor r0, r0, r1, asr #1
    eor r0, r0, r1, asr #2
    eor r0, r0, r1, asr #3
    and r0, r0, #0x10101010 /* masked addition of first polynomial */
    eor r2, r2, r0
    eor r0, r10, r10, lsl #1 /* accumulate the result for reg[1] */
    eor r0, r0, r10, lsl #2
    eor r0, r0, r10, lsl #3
    eor r0, r0, r10, lsl #4
    eor r0, r0, r10, asr #1
    eor r0, r0, r10, asr #2
    eor r0, r0, r10, asr #3
    and r0, r0, #0x10101010 /* masked addition of first polynomial */
    eor r3, r3, r0
    eor r0, r11, r11, lsl #1 /* accumulate the result for reg[2] */
    eor r0, r0, r11, lsl #2
    eor r0, r0, r11, lsl #3
    eor r0, r0, r11, lsl #4
    eor r0, r0, r11, asr #1
    eor r0, r0, r11, asr #2
    eor r0, r0, r11, asr #3
    and r0, r0, #0x10101010 /* masked addition of first polynomial */
    eor r4, r4, r0
    eor r0, r12, r12, lsl #1 /* accumulate the result for reg[3] */
    eor r0, r0, r12, lsl #2
    eor r0, r0, r12, lsl #3
    eor r0, r0, r12, lsl #4
    eor r0, r0, r12, asr #1
    eor r0, r0, r12, asr #2
    eor r0, r0, r12, asr #3
    and r0, r0, #0x10101010 /* masked addition of first polynomial */
    eor r5, r5, r0

    /* Round 5 */
    gf16_mul_lit 0x55555555,0xc1c1c1c1,0x63636363,0xe3e3e3e3
    eor r0, r1, r1, lsl #1 /* accumulate the result for reg[0] */
    eor r0, r0, r1, lsl #2
    eor r0, r0, r1, lsl #3
    eor r0, r0, r1, asr #1
    eor r0, r0, r1, asr #2
    eor r0, r0, r1, asr #3
    eor r0, r0, r1, asr #4
    and r0, r0, #0x8080808 /* masked addition of first polynomial */
    eor r2, r2, r0
    eor r0, r10, r10, lsl #1 /* accumulate the result for reg[1] */
    eor r0, r0, r10, lsl #2
    eor r0, r0, r10, lsl #3
    eor r0, r0, r10, asr #1
    eor r0, r0, r10, asr #2
    eor r0, r0, r10, asr #3
    eor r0, r0, r10, asr #4
    and r0, r0, #0x8080808 /* masked addition of first polynomial */
    eor r3, r3, r0
    eor r0, r11, r11, lsl #1 /* accumulate the result for reg[2] */
    eor r0, r0, r11, lsl #2
    eor r0, r0, r11, lsl #3
    eor r0, r0, r11, asr #1
    eor r0, r0, r11, asr #2
    eor r0, r0, r11, asr #3
    eor r0, r0, r11, asr #4
    and r0, r0, #0x8080808 /* masked addition of first polynomial */
    eor r4, r4, r0
    eor r0, r12, r12, lsl #1 /* accumulate the result for reg[3] */
    eor r0, r0, r12, lsl #2
    eor r0, r0, r12, lsl #3
    eor r0, r0, r12, asr #1
    eor r0, r0, r12, asr #2
    eor r0, r0, r12, asr #3
    eor r0, r0, r12, asr #4
    and r0, r0, #0x8080808 /* masked addition of first polynomial */
    eor r5, r5, r0

    /* Round 6 */
    gf16_mul_lit 0xaaaaaaaa,0xe0e0e0e0,0xb1b1b1b1,0xf1f1f1f1
    eor r0, r1, r1, lsl #1 /* accumulate the result for reg[0] */
    eor r0, r0, r1, lsl #2
    eor r0, r0, r1, asr #1
    eor r0, r0, r1, asr #2
    eor r0, r0, r1, asr #3
    eor r0, r0, r1, asr #4
    eor r0, r0, r1, asr #5
    and r0, r0, #0x04040404 /* masked addition of first polynomial */
    eor r2, r2, r0
    eor r0, r10, r10, lsl #1 /* accumulate the result for reg[1] */
    eor r0, r0, r10, lsl #2
    eor r0, r0, r10, asr #1
    eor r0, r0, r10, asr #2
    eor r0, r0, r10, asr #3
    eor r0, r0, r10, asr #4
    eor r0, r0, r10, asr #5
    and r0, r0, #0x04040404 /* masked addition of first polynomial */
    eor r3, r3, r0
    eor r0, r11, r11, lsl #1 /* accumulate the result for reg[2] */
    eor r0, r0, r11, lsl #2
    eor r0, r0, r11, asr #1
    eor r0, r0, r11, asr #2
    eor r0, r0, r11, asr #3
    eor r0, r0, r11, asr #4
    eor r0, r0, r11, asr #5
    and r0, r0, #0x04040404 /* masked addition of first polynomial */
    eor r4, r4, r0
    eor r0, r12, r12, lsl #1 /* accumulate the result for reg[3] */
    eor r0, r0, r12, lsl #2
    eor r0, r0, r12, asr #1
    eor r0, r0, r12, asr #2
    eor r0, r0, r12, asr #3
    eor r0, r0, r12, asr #4
    eor r0, r0, r12, asr #5
    and r0, r0, #0x04040404 /* masked addition of first polynomial */
    eor r5, r5, r0

    /* Round 7 */
    gf16_mul_lit 0x55555555,0x70707070,0xd8d8d8d8,0xf8f8f8f8
    eor r0, r1, r1, lsl #1 /* accumulate the result for reg[0] */
    eor r0, r0, r1, asr #1
    eor r0, r0, r1, asr #2
    eor r0, r0, r1, asr #3
    eor r0, r0, r1, asr #4
    eor r0, r0, r1, asr #5
    eor r0, r0, r1, asr #6
    and r0, r0, #0x02020202 /* masked addition of first polynomial */
    eor r2, r2, r0
    eor r0, r10, r10, lsl #1 /* accumulate the result for reg[1] */
    eor r0, r0, r10, asr #1
    eor r0, r0, r10, asr #2
    eor r0, r0, r10, asr #3
    eor r0, r0, r10, asr #4
    eor r0, r0, r10, asr #5
    eor r0, r0, r10, asr #6
    and r0, r0, #0x02020202 /* masked addition of first polynomial */
    eor r3, r3, r0
    eor r0, r11, r11, lsl #1 /* accumulate the result for reg[2] */
    eor r0, r0, r11, asr #1
    eor r0, r0, r11, asr #2
    eor r0, r0, r11, asr #3
    eor r0, r0, r11, asr #4
    eor r0, r0, r11, asr #5
    eor r0, r0, r11, asr #6
    and r0, r0, #0x02020202 /* masked addition of first polynomial */
    eor r4, r4, r0
    eor r0, r12, r12, lsl #1 /* accumulate the result for reg[3] */
    eor r0, r0, r12, asr #1
    eor r0, r0, r12, asr #2
    eor r0, r0, r12, asr #3
    eor r0, r0, r12, asr #4
    eor r0, r0, r12, asr #5
    eor r0, r0, r12, asr #6
    and r0, r0, #0x02020202 /* masked addition of first polynomial */
    eor r5, r5, r0

    /* Round 8 */
    gf16_mul_lit 0xaaaaaaaa,0x38383838,0x6c6c6c6c,0x7c7c7c7c
    eor r0, r1, r1, asr #1 /* accumulate the result for reg[0] */
    eor r0, r0, r1, asr #2
    eor r0, r0, r1, asr #3
    eor r0, r0, r1, asr #4
    eor r0, r0, r1, asr #5
    eor r0, r0, r1, asr #6
    eor r0, r0, r1, asr #7
    and r0, r0, #0x01010101 /* masked addition of first polynomial */
    eor r2, r2, r0
    eor r0, r10, r10, asr #1 /* accumulate the result for reg[1] */
    eor r0, r0, r10, asr #2
    eor r0, r0, r10, asr #3
    eor r0, r0, r10, asr #4
    eor r0, r0, r10, asr #5
    eor r0, r0, r10, asr #6
    eor r0, r0, r10, asr #7
    and r0, r0, #0x01010101 /* masked addition of first polynomial */
    eor r3, r3, r0
    eor r0, r11, r11, asr #1 /* accumulate the result for reg[2] */
    eor r0, r0, r11, asr #2
    eor r0, r0, r11, asr #3
    eor r0, r0, r11, asr #4
    eor r0, r0, r11, asr #5
    eor r0, r0, r11, asr #6
    eor r0, r0, r11, asr #7
    and r0, r0, #0x01010101 /* masked addition of first polynomial */
    eor r4, r4, r0
    eor r0, r12, r12, asr #1 /* accumulate the result for reg[3] */
    eor r0, r0, r12, asr #2
    eor r0, r0, r12, asr #3
    eor r0, r0, r12, asr #4
    eor r0, r0, r12, asr #5
    eor r0, r0, r12, asr #6
    eor r0, r0, r12, asr #7
    and r0, r0, #0x01010101 /* masked addition of first polynomial */
    eor r5, r5, r0
.endm


mysterion:
    push {r4-r12}
    byteslice_msg
    byteslice_key

    /* Spill the ptr to the output buffer to the stack, cause we need a
    register for temporary values */
    push {r0}


    /* From this point [r2..r9] are in use */
    add_key
    sbox
    lbox

    pop {r0}
    mov r0, r3

    pop {r4-r12}
    bx lr
