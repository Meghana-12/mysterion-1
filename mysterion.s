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
     * r0:  destination buffer
     * r2..r5: bytesliced input state (*this is consumed during execution*)
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


.macro add_const round_number
    /*
     * Add the round constant to the state
     * r2: state[0]
     * r0: temporary register
     */
    .if \round_number == 1
        movw r0, 0xf48f
        movt r0, 0x8df2
    .elseif \round_number == 2
        movw r0, 0xd83d
        movt r0, 0x39d4
    .elseif \round_number == 3
        movw r0, 0x2cb2
        movt r0, 0xb426
    .elseif \round_number == 4
        movw r0, 0x9369
        movt r0, 0x6198
    .elseif \round_number == 5
        movw r0, 0x67e6
        movt r0, 0xec6a
    .elseif \round_number == 6
        movw r0, 0x4b54
        movt r0, 0x584c
    .elseif \round_number == 7
        movw r0, 0xbfdb
        movt r0, 0xd5be
    .elseif \round_number == 8
        movw r0, 0x16c1
        movt r0, 0xc213
    .elseif \round_number == 9
        movw r0, 0xe24e
        movt r0, 0x4fe1
    .elseif \round_number == 10
        movw r0, 0xcefc
        movt r0, 0xfbc7
    .elseif \round_number == 11
        movw r0, 0x3a73
        movt r0, 0x7635
    .elseif \round_number == 12
        movw r0, 0x85a8
        movt r0, 0xa38b
    .else
        .error "Round number must be in 1..12"
    .endif
    eor r2, r2, r0
.endm


.macro add_key
    /*
     * Add the key to the state
     * r2..r5: state
     * r6..r9: key
     */
    eor r2, r2, r6
    eor r3, r3, r7
    eor r4, r4, r8
    eor r5, r5, r9
.endm


.macro sbox
    /*
     * Perform the Mysterion sbox
     * r2..r5: state
     * r0..r1: temporary registers
     *
     * Equivalent Python code:
     *
     * a = (state[0] & state[1]) ^ state[2] # Use r0
     * state[2] = (state[1] | state[2]) ^ state[3]
     * state[3] = (a & state[3]) ^ state[0]
     * state[1] = (state[2] & state[0]) ^ state[1] # new state[2] value
     *            ^~~~~~~~~~~~~~~~~~~~~ Use r1
     * state[0] = a
     */
    and r0, r2, r3
    eor r0, r0, r4
    orr r4, r4, r3
    eor r4, r4, r5
    and r5, r5, r0
    eor r5, r5, r2
    and r1, r4, r2
    eor r3, r3, r1
    mov r2, r0
.endm


.macro gf16_mul_lit p0,p1,p2,p3
    /*
     * Bitsliced multiplication of [r2..r5] with the literal polynomials
     * specified in p0,p1,p2,p3, modulo x^4 + x + 1.
     *
     * p0,p1,p2,p3: literal bitsliced polynomial
     * r2..r5: input (unaltered)
     * r1,r10..12: output
     * r0: temporary register
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
     * r2..r5: state
     * r0, r1, r10..r12: temporary registers
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


.macro shiftcolumns_inner reg
    and r0, \reg, #0xc0c0c0c0
    and r1, \reg, #0x30303030
    orr r0, r0, r1, ror #8
    and r1, \reg, #0x0c0c0c0c
    orr r0, r0, r1, ror #16
    and r1, \reg, #0x03030303
    orr \reg, r0, r1, ror #24
.endm


.macro shiftcolumns
    /*
     * Do shiftcolumns operation.
     *
     * r2..r5: state
     * r0, r1: temporary registers
     *
     * Equivalent python code:
     * r0: tmp[i]
     * r1: expr values (... & ...)
     *
     * for i in range(4):
     *     tmp[i]  =     state[i] & 0xc0c0c0c0
     *     tmp[i] |= ror(state[i] & 0x30303030, 8)
     *     tmp[i] |= ror(state[i] & 0x0c0c0c0c, 16)
     *     tmp[i] |= ror(state[i] & 0x03030303, 24)
     *     state[i] = tmp[i]
     */
     shiftcolumns_inner r2
     shiftcolumns_inner r3
     shiftcolumns_inner r4
     shiftcolumns_inner r5
.endm


.macro mysterion_round round_number
    /*
     * Perform one round of the Mysterion block cipher
     * r2..r5: state
     * r0, r1, r6..r12: temporary registers
     */
    sbox
    lbox
    shiftcolumns
    add_const \round_number
    add_key
.endm


mysterion:
    /*
     * Do Mysterion block encryption on msg pointed to by r0, with the values
     * pointed to by r1 as key. This function follows the C calling convention.
     */

    push {r4-r12}
    byteslice_msg
    byteslice_key

    /* Spill the ptr to the output buffer to the stack, because we need a
    register for temporary values */
    push {r0}

    /* From this point [r2..r9] are in use */
    add_key
    mysterion_round 1
    mysterion_round 2
    mysterion_round 3
    mysterion_round 4
    mysterion_round 5
    mysterion_round 6
    mysterion_round 7
    mysterion_round 8
    mysterion_round 9
    mysterion_round 10
    mysterion_round 11
    mysterion_round 12

    /* Put the ciphertext back in the input buffer */
    pop {r0}
    unbyteslice_state

    pop {r4-r12}
    bx lr
