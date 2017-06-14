.syntax unified
.cpu cortex-m4

.global mysterion_encrypt
.type mysterion_encrypt, %function

.global mysterion_decrypt
.type mysterion_decrypt, %function


.macro byteslice_state
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
    ldrb r0,  [r1, #8]
    orr r9, r9, r12, lsl #8
    orr r8, r8, r11, lsl #8
    orr r7, r7, r10, lsl #8
    orr r6, r6, r0,  lsl #8

    ldrb r12, [r1, #7]
    ldrb r11, [r1, #6]
    ldrb r10, [r1, #5]
    ldrb r0,  [r1, #4]
    orr r9, r9, r12, lsl #16
    orr r8, r8, r11, lsl #16
    orr r7, r7, r10, lsl #16
    orr r6, r6, r0,  lsl #16

    ldrb r12, [r1, #3]
    ldrb r11, [r1, #2]
    ldrb r10, [r1, #1]
    ldrb r0,  [r1, #0]
    orr r9, r9, r12, lsl #24
    orr r8, r8, r11, lsl #24
    orr r7, r7, r10, lsl #24
    orr r6, r6, r0,  lsl #24
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


.macro sbox_inv
    /*
     * Perform the Mysterion inverse sbox
     * r2..r5: state
     * r0..r1: temporary registers
     *
     * Equivalent Python code:
     *
     * b = (state[2] & state[3]) ^ state[1]
     * d = (state[0] | b) ^ state[2]
     * a = (d & state[0]) ^ state[3]
     * c = (a & b) ^ state[0]
     * return [a, b, c, d]
     */
    and r0, r4, r5
    eor r3, r0, r3
    orr r0, r2, r3
    eor r1, r0, r4 // stash d in r1
    and r0, r1, r2
    eor r0, r0, r5 // stash a in r0
    mov r5, r1     // stash pop d
    and r1, r0, r3 // stash (a & b) in r1
    eor r4, r1, r2
    mov r2, r0     // stash pop a
.endm


.macro gf16_mul_lit ra,rb,rc,rd,p0,p1,p2,p3
    /*
     * Bitsliced multiplication of [r2..r5] with the literal polynomials
     * specified in p0,p1,p2,p3, modulo x^4 + x + 1.
     *
     * p0,p1,p2,p3: literal bitsliced polynomial
     * r2..r5: input (unaltered)
     * ra..rd: output
     * r0: temporary register
     */
    and \ra,  r5, #(\p0)
    and \rb, r5, #(\p1)
    and \rc, r5, #(\p2)
    and \rd, r5, #(\p3)

    and r0,  r4,  #(\p1)
    eor \ra,  \ra,  r0
    and r0,  r4,  #(\p2)
    eor \rb, \rb, r0
    and r0,  r4,  #((\p3)^\p0)
    eor \rc, \rc, r0
    and r0,  r4,  #(\p0)
    eor \rd, \rd, r0

    and r0,  r3,  #(\p2)
    eor \ra,  \ra,  r0
    and r0,  r3,  #((\p3)^\p0)
    eor \rb, \rb, r0
    and r0,  r3,  #((\p0)^\p1)
    eor \rc, \rc, r0
    and r0,  r3,  #(\p1)
    eor \rd, \rd, r0

    and r0,  r2,  #((\p3)^\p0)
    eor \ra,  \ra,  r0
    and r0,  r2,  #((\p0)^\p1)
    eor \rb, \rb, r0
    and r0,  r2,  #((\p1)^\p2)
    eor \rc, \rc, r0
    and r0,  r2,  #(\p2)
    eor \rd, \rd, r0
.endm


.macro lbox_rotate_left
    /*
     * For all registers in r2..r5 shift the value one to the left *inside*
     * the byte.
     * r1, r10..r12: temporary registers
     */
    and  r1, r2, #0x7f7f7f7f
    and r10, r3, #0x7f7f7f7f
    and r11, r4, #0x7f7f7f7f
    and r12, r5, #0x7f7f7f7f

    and r2, r2, #0x80808080
    and r3, r3, #0x80808080
    and r4, r4, #0x80808080
    and r5, r5, #0x80808080

    lsr r2, r2, #7
    lsr r3, r3, #7
    lsr r4, r4, #7
    lsr r5, r5, #7

    eor r2, r2, r1, lsl #1
    eor r3, r3, r10, lsl #1
    eor r4, r4, r11, lsl #1
    eor r5, r5, r12, lsl #1
.endm


.macro lbox
    /*
     * Execution of the Lbox on the state:
     * r2..r5: state
     * r6..r9: temporary registers containing accumulator
     * r0, r1, r10..r12: temporary registers
     */

    // push the key, we need the registers
    push {r6-r9}

    gf16_mul_lit r6,r7,r8,r9, 0x73737373, 0x6c6c6c6c, 0x2c2c2c2c, 0xfafafafa
    lbox_rotate_left

    gf16_mul_lit r1,r10,r11,r12, 0xbbbbbbbb, 0x03030303, 0x5b5b5b5b, 0x77777777
    eor r6, r6, r1
    eor r7, r7, r10
    eor r8, r8, r11
    eor r9, r9, r12
    lbox_rotate_left

    gf16_mul_lit r1,r10,r11,r12, 0x08080808, 0x27272727, 0xd0d0d0d0, 0x8e8e8e8e
    eor r6, r6, r1
    eor r7, r7, r10
    eor r8, r8, r11
    eor r9, r9, r12
    lbox_rotate_left

    gf16_mul_lit r1,r10,r11,r12, 0xacacacac, 0x93939393, 0xa2a2a2a2, 0xe0e0e0e0
    eor r6, r6, r1
    eor r7, r7, r10
    eor r8, r8, r11
    eor r9, r9, r12
    lbox_rotate_left

    gf16_mul_lit r1,r10,r11,r12, 0x1a1a1a1a, 0xe4e4e4e4, 0x22222222, 0x83838383
    eor r6, r6, r1
    eor r7, r7, r10
    eor r8, r8, r11
    eor r9, r9, r12
    lbox_rotate_left

    gf16_mul_lit r1,r10,r11,r12, 0x88888888, 0xf2f2f2f2, 0x85858585, 0xb8b8b8b8
    eor r6, r6, r1
    eor r7, r7, r10
    eor r8, r8, r11
    eor r9, r9, r12
    lbox_rotate_left

    gf16_mul_lit r1,r10,r11,r12, 0x6e6e6e6e, 0x60606060, 0xedededed, 0xf7f7f7f7
    eor r6, r6, r1
    eor r7, r7, r10
    eor r8, r8, r11
    eor r9, r9, r12
    lbox_rotate_left

    gf16_mul_lit r1,r10,r11,r12, 0xe7e7e7e7, 0x1b1b1b1b, 0x1a1a1a1a, 0x2f2f2f2f
    eor r2, r6, r1
    eor r3, r7, r10
    eor r4, r8, r11
    eor r5, r9, r12

    pop {r6-r9}
.endm


.macro lbox_inv
    /*
     * Execution of the inverse Lbox on the state:
     * r2..r5: state
     * r6..r9: temporary registers containing accumulator
     * r0, r1, r10..r12: temporary registers
     */

    // push the key, we need the registers
    push {r6-r9}

    gf16_mul_lit r6,r7,r8,r9, 0xcececece, 0x36363636, 0x34343434, 0x5f5f5f5f
    lbox_rotate_left

    gf16_mul_lit r1,r10,r11,r12, 0xe7e7e7e7, 0xd8d8d8d8, 0x58585858, 0xf4f4f4f4
    eor r6, r6, r1
    eor r7, r7, r10
    eor r8, r8, r11
    eor r9, r9, r12
    lbox_rotate_left

    gf16_mul_lit r1,r10,r11,r12, 0x76767676, 0x06060606, 0xb7b7b7b7, 0xefefefef
    eor r6, r6, r1
    eor r7, r7, r10
    eor r8, r8, r11
    eor r9, r9, r12
    lbox_rotate_left

    gf16_mul_lit r1,r10,r11,r12, 0x11111111, 0x4f4f4f4f, 0xa1a1a1a1, 0x1d1d1d1d
    eor r6, r6, r1
    eor r7, r7, r10
    eor r8, r8, r11
    eor r9, r9, r12
    lbox_rotate_left

    gf16_mul_lit r1,r10,r11,r12, 0x58585858, 0x27272727, 0x44444444, 0xc1c1c1c1
    eor r6, r6, r1
    eor r7, r7, r10
    eor r8, r8, r11
    eor r9, r9, r12
    lbox_rotate_left

    gf16_mul_lit r1,r10,r11,r12, 0x35353535, 0xc9c9c9c9, 0x45454545, 0x07070707
    eor r6, r6, r1
    eor r7, r7, r10
    eor r8, r8, r11
    eor r9, r9, r12
    lbox_rotate_left

    gf16_mul_lit r1,r10,r11,r12, 0x10101010, 0xe4e4e4e4, 0x0b0b0b0b, 0x71717171
    eor r6, r6, r1
    eor r7, r7, r10
    eor r8, r8, r11
    eor r9, r9, r12
    lbox_rotate_left

    gf16_mul_lit r1,r10,r11,r12, 0xdddddddd, 0xc0c0c0c0, 0xdadadada, 0xeeeeeeee
    eor r2, r6, r1
    eor r3, r7, r10
    eor r4, r8, r11
    eor r5, r9, r12

    pop {r6-r9}
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
     *     state[i]  =     state[i] & 0xc0c0c0c0
     *     state[i] |= ror(state[i] & 0x30303030, 8)
     *     state[i] |= ror(state[i] & 0x0c0c0c0c, 16)
     *     state[i] |= ror(state[i] & 0x03030303, 24)
     */
     shiftcolumns_inner r2
     shiftcolumns_inner r3
     shiftcolumns_inner r4
     shiftcolumns_inner r5
.endm


.macro shiftcolumns_inv_inner reg
    and r0, \reg, #0xc0c0c0c0
    and r1, \reg, #0x30303030
    orr r0, r0, r1, ror #24
    and r1, \reg, #0x0c0c0c0c
    orr r0, r0, r1, ror #16
    and r1, \reg, #0x03030303
    orr \reg, r0, r1, ror #8
.endm


.macro shiftcolumns_inv
    /*
     * Do inverse shiftcolumns operation, very symmetric with normal
     * shiftcolumns operation.
     *
     * r2..r5: state
     * r0, r1: temporary registers
     *
     * Equivalent python code:
     * r0: tmp[i]
     * r1: expr values (... & ...)
     *
     * for i in range(4):
     *     state[i]  =     state[i] & 0xc0c0c0c0
     *     state[i] |= ror(state[i] & 0x30303030, 24)
     *     state[i] |= ror(state[i] & 0x0c0c0c0c, 16)
     *     state[i] |= ror(state[i] & 0x03030303, 8)
     */
     shiftcolumns_inv_inner r2
     shiftcolumns_inv_inner r3
     shiftcolumns_inv_inner r4
     shiftcolumns_inv_inner r5
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


.macro mysterion_inv_round round_number
    /*
     * Perform one round of the Mysterion block cipher
     * r2..r5: state
     * r0, r1, r6..r12: temporary registers
     */
    add_key
    add_const ((13)-\round_number)
    shiftcolumns_inv
    lbox_inv
    sbox_inv
.endm


mysterion_encrypt:
    /*
     * Do Mysterion block encryption on msg pointed to by r0, with the values
     * pointed to by r1 as key.

     */

    /* Spill the ptr to the output buffer to the stack, because we need a
    register for temporary values. Other temporary registers are pushed
    due to the C calling convention. */
    push {r4-r12}
    push {r0}

    byteslice_state
    byteslice_key

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


mysterion_decrypt:
    /*
     * Do Mysterion block decryption on ciphertext pointed to by r0, with the
     * buffer pointed to by r1 as key.
     */

    /* Spill the ptr to the output buffer to the stack, because we need a
    register for temporary values. Other temporary registers are pushed
    due to the C calling convention. */
    push {r4-r12}
    push {r0}

    byteslice_state
    byteslice_key

    /* From this point [r2..r9] are in use */
    mysterion_inv_round 1
    mysterion_inv_round 2
    mysterion_inv_round 3
    mysterion_inv_round 4
    mysterion_inv_round 5
    mysterion_inv_round 6
    mysterion_inv_round 7
    mysterion_inv_round 8
    mysterion_inv_round 9
    mysterion_inv_round 10
    mysterion_inv_round 11
    mysterion_inv_round 12
    add_key

    /* Put the plaintext address back in the input buffer */
    pop {r0}
    unbyteslice_state

    pop {r4-r12}
    bx lr
