import operator


NR = 12
B = 4
S = 4
L = 8


def roundconst(i):
    # TODO Use constants
    block = [0] * 16

    for idx in range(4):
        lfsr_in = [0, 0, 0, 0, 0, 0, 0, 0]
        lfsr_in[idx*2 + 1] = i
        tmp = lbox(lfsr_in)
        block[4 * idx] = (tmp[0] << 4) | tmp[1]
    return block


def sbox(block):
    """Bitsliced implementation of the s-box"""
    a = (block[0] & block[1]) ^ block[2]
    c = (block[1] | block[2]) ^ block[3]
    d = (a & block[3]) ^ block[0]
    b = (c & block[0]) ^ block[1]
    return [a,b,c,d]


def sbox_inv(block):
    """Bitsliced implementation of the inverse s-box
    >>> x = [1, 2, 3, 4]
    >>> sbox_inv(sbox(x))
    [1, 2, 3, 4]
    """
    b = (block[2] & block[3]) ^ block[1]
    d = (block[0] | b) ^ block[2]
    a = (d & block[0]) ^ block[3]
    c = (a & b) ^ block[0]
    return [a, b, c, d]


def _gf16_mul(a, b, p=0b10011):
    """
    Safely multiply two numbers in GF(2^4)
    """
    ret = 0
    for _ in range(4):
        ret ^= (b & 1) * a
        a <<= 1
        a ^= (a >> 4) * p
        b >>= 1
    return ret

def _gf16_mul2(a, b):
    """
    >>> x1 = [x % 16 for x in range(32)]
    >>> y1 = []
    >>> for z in x1:
    ...     y1.append(_gf16_mul(z, 7))

    >>> x2 = bitslice_32x4(x1)
    >>> z = bitslice_32x4([7]*32)
    >>> y2 = unbitslice_32x4(_gf16_mul2(x2, z))

    >>> y1 == y2
    True
    """
    # a, b lists of length 4
    ret = [0, 0, 0, 0]

    ret[0] ^= a[0] & b[3]
    ret[1] ^= a[1] & b[3]
    ret[2] ^= a[2] & b[3]
    ret[3] ^= a[3] & b[3] # add
    a[3]   ^= a[0] # reduce

    ret[0] ^= a[1] & b[2]
    ret[1] ^= a[2] & b[2]
    ret[2] ^= a[3] & b[2]
    ret[3] ^= a[0] & b[2] # add
    a[0]   ^= a[1] # reduce

    ret[0] ^= a[2] & b[1]
    ret[1] ^= a[3] & b[1]
    ret[2] ^= a[0] & b[1]
    ret[3] ^= a[1] & b[1] # add
    a[1]   ^= a[2] # reduce

    ret[0] ^= a[3] & b[0]
    ret[1] ^= a[0] & b[0]
    ret[2] ^= a[1] & b[0]
    ret[3] ^= a[2] & b[0] # add
    # reduction unneccesary

    return ret


def bitslice_32x4(x):
    """
    >>> x = [x % 16 for x in range(32)]
    >>> y = bitslice_32x4(x)
    >>> z = unbitslice_32x4(y)
    >>> x == z
    True
    """
    # x is a list of 32 4-bit numbers
    ret = [0, 0, 0, 0]
    for i in range(32):
        for j in range(4):
            ret[3-j] |= ((x[31-i] & (1 << j)) >> j) << i
    return ret

def unbitslice_32x4(x):
    # x is a list of 4 32-bit numbers
    ret = [0] * 32
    for i in range(4):
        for j in range(32):
            ret[31-j] |= ((x[3-i] & (1 << j)) >> j) << i
    return ret


def byteslice(x):
    """
    >>> x = list(range(16))
    >>> expected = [0x0004080c, 0x0105090d, 0x02060a0e, 0x03070b0f]
    >>> unbyteslice(byteslice(x)) == x
    True
    >>> byteslice(x) == expected
    True
    """
    ret = [0] * 4
    for i in range(4):
        for j in range(4):
            ret[i] |= x[4*j + i] << ((3 - j) * 8)
    return ret


def unbyteslice(x):
    ret = [0] * 16
    for i in range(4):
        for j in range(4):
            shift = (3 - j) * 8
            ret[4*j + i] = (x[i] & (0xff << shift)) >> shift
    return ret


def poly(n):
    """
    Function to generate a polynomial in bitsliced format for a specific
    round. This function is pure and the results are to be hardcoded in
    the actual product.
    """
    poly_norm = [0, 0b1000, 0b0011, 0b1111, 0b0101, 0b1111, 0b0011, 0b1000]
    poly_norm = poly_norm[-n:] + poly_norm[:-n]
    return bitslice_32x4(poly_norm * 4)


def lbox2(state):
    """
    >>> x = [0, 0, 0, 0, 0, 0, 0, 1]
    >>> y = unbitslice_32x4(lbox2(bitslice_32x4(x * 4)))
    >>> y == lbox(x) * 4 or (y[:8], lbox(x))
    True

    >>> x = [1, 0, 0, 0, 0, 0, 0, 0]
    >>> y = unbitslice_32x4(lbox2(bitslice_32x4(x * 4)))
    >>> y == lbox(x) * 4 or (y[:8], lbox(x))
    True

    >>> x = list(range(1,9))
    >>> y = unbitslice_32x4(lbox2(bitslice_32x4(x * 4)))
    >>> y == lbox(x) * 4 or (y[:8], lbox(x))
    True

    Check that the bitsliced polynomial matches to polynomials as needed in the
    state's "bytesliced" representation.
    >>> x = [0] * 25 + [0b1000, 0b0011, 0b1111, 0b0101, 0b1111, 0b0011, 0b1000]
    >>> bitslice_32x4(x) == [0b01010101, 0b00011100, 0b00110110, 0b00111110]
    True
    """
    # state is a list of 4 32-bit numbers (in bitsliced form!)

    for clock in range(8):
        x = _gf16_mul2(poly(clock), state)
        for reg in range(4): # reg for register
            acc = 0
            for i in range(8-clock):
                acc ^= x[reg] << i
            for i in range(1, clock+1):
                acc ^= x[reg] >> i
            state[reg] ^= acc & (0x80808080 >> clock)

    return state


def lbox3(state):
    mat = [
        [0b0001, 0b1000, 0b0011, 0b1111, 0b0101, 0b1111, 0b0011, 0b1000],
        [0b1000, 0b1101, 0b0011, 0b0010, 0b0001, 0b0100, 0b0100, 0b1111],
        [0b1111, 0b1101, 0b1111, 0b1001, 0b0100, 0b1011, 0b0110, 0b0101],
        [0b0101, 0b0001, 0b0110, 0b1001, 0b1011, 0b0010, 0b0100, 0b1000],
        [0b1000, 0b1001, 0b1010, 0b0111, 0b0111, 0b1010, 0b1001, 0b1000],
        [0b1000, 0b0100, 0b0010, 0b1011, 0b1001, 0b0110, 0b0001, 0b0101],
        [0b0101, 0b0110, 0b1011, 0b0100, 0b1001, 0b1111, 0b1001, 0b1111],
        [0b1111, 0b0100, 0b0100, 0b0001, 0b0010, 0b0011, 0b1101, 0b1000]
    ]
    for i in range(8):
        mat[i] = mat[i][i:] + mat[i][:i]
    mat = zip(*mat)
    mat = [bitslice_32x4(row * 4) for row in mat]

    acc = [0] * 4
    for i in range(8):
        print(_gf16_mul2(mat[i][:], state[:]), acc)
        for j, x in enumerate(_gf16_mul2(mat[i][:], state[:])):
            acc[j] ^= x
        # rotate state left inside bytes by 1
        state = [((x << 1) & 0xfefefefe) | (x >> 7) & 0x01010101 for x in state]
    return acc


def lbox2_inv(state):
    """
    >>> lbox2([0, 0, 0, 1])
    [219, 102, 66, 102]
    >>> lbox2_inv([219, 102, 66, 102])
    [0, 0, 0, 1]
    """
    # state is a list of 4 32-bit numbers (in bitsliced form!)
    for clock in reversed(range(8)):
        x = _gf16_mul2(poly(clock), state)
        for reg in range(4): # reg for register
            acc = 0
            for i in range(8-clock):
                acc ^= x[reg] << i
            for i in range(1, clock+1):
                acc ^= x[reg] >> i
            state[reg] ^= acc & (0x80808080 >> clock)

    return state


def lbox(state):
    """
    >>> lbox([0, 0, 0, 0, 0, 0, 0, 1])
    [8, 15, 5, 8, 8, 5, 15, 8]
    >>> lbox([1, 0, 0, 0, 0, 0, 0, 0])
    [1, 8, 15, 5, 8, 8, 5, 15]
    >>> lbox(list(range(8)))
    [10, 14, 1, 3, 2, 15, 3, 13]
    """
    poly = [0, 0b1000, 0b0011, 0b1111, 0b0101, 0b1111, 0b0011, 0b1000]
    for clock in range(8):
        x = state[0]
        acc = []
        ops = []
        for idx in range(8):
            x ^= _gf16_mul(state[idx], poly[idx])
            acc.append(_gf16_mul(state[idx], poly[idx]))
            ops.append((state[idx], poly[idx]))
        state.pop(0)
        state.append(x)
    return state


def lbox_inv(state):
    """
    >>> lbox([0, 0, 0, 0, 0, 0, 0, 1])
    [8, 15, 5, 8, 8, 5, 15, 8]
    >>> lbox_inv([8, 15, 5, 8, 8, 5, 15, 8])
    [0, 0, 0, 0, 0, 0, 0, 1]
    >>> lbox_inv(lbox(list(range(8))))
    [0, 1, 2, 3, 4, 5, 6, 7]
    """
    poly = [0b1000, 0b0011, 0b1111, 0b0101, 0b1111, 0b0011, 0b1000, 0]
    for clock in range(8):
        x = state[7]
        for idx in range(8):
            x ^= _gf16_mul(state[idx], poly[idx])
        state.pop(7)
        state = [x] + state[:]
    return state


def bitslice(block):
    lfsr = 8*[0]
    for ialpha in range(4): # degree of alpha
        for ix in range(8): # for each value to be in LSFR state
            lfsr[7-ix] |= ((block[3-ialpha] & (1 << ix)) >> ix) << ialpha
    return lfsr


def unbitslice(lfsr):
    out = 4*[0]
    for ialpha in range(4): # for each value to be in LSFR state
        for ix in range(8): # degree of alpha
            out[3-ialpha] |= ((lfsr[7-ix] & (1 << ialpha)) >> ialpha) << ix
    return tuple(out)


def shiftcolumns(blocks):
    mask = 0b11000000
    out = 4 * [None]
    for i in range(4): # block
        out[i] = [0,0,0,0]
        for j in range(4): # row
            for k in range(4): # bit pair
                out[i][j] |= blocks[(i+4-k)%4][j] & (mask >> 2*k)
    return [tuple(lst) for lst in out]


def ror(x, n):
    """
    >>> ror(0b00110000000000000000000000000001, 2) == 0b01001100000000000000000000000000
    True
    """
    hi = x & ((0xffffffff >> n) << n)
    lo = x & (0xffffffff >> (32 - n))
    hi >>= n
    lo <<= 32 - n
    return hi | lo


def shiftcolumns2(state):
    out = [None] * 4
    for i in range(4):
        out[i]  =     state[i] & 0xc0c0c0c0
        out[i] |= ror(state[i] & 0x30303030, 8)
        out[i] |= ror(state[i] & 0x0c0c0c0c, 16)
        out[i] |= ror(state[i] & 0x03030303, 24)
    return out

def shiftcolumns2_inv(state):
    out = [None] * 4
    for i in range(4):
        out[i]  =     state[i] & 0xc0c0c0c0
        out[i] |= ror(state[i] & 0x30303030, 24)
        out[i] |= ror(state[i] & 0x0c0c0c0c, 16)
        out[i] |= ror(state[i] & 0x03030303, 8)
    return out


def mysterion(key, msg):
    """
    >>> msg = [0x1, 0x1, 0x0, 0x0,0xB2, 0xC3, 0xD4, 0xE5,0xF6, 0x07, 0x18, 0x29,0x3A, 0x4B, 0x5C, 0x6D]
    >>> key = [0x2, 0x5, 0x6, 0x7,0x52, 0xF3, 0xE1, 0xF2,0x13, 0x24, 0x35, 0x46,0x5B, 0x6C, 0x7D, 0x88]
    >>> "".join("{:02x}".format(x) for x in mysterion(key, msg))
    'cd1a8e640087c2db3886e646c7e33def'
    """
    state = [x for x in msg]

    # Add key one time extra in the beginning
    state = [x ^ y for x, y in zip(key, msg)]

    for round_number in range(1, NR+1):
        # Split the state into blocks
        blocks = [state[i*4:(i+1)*4] for i in range(4)]

        # S boxes
        blocks = [sbox(block) for block in blocks]

        # L boxes
        sliced = [bitslice(block) for block in blocks]
        tmp = [lbox(lfsr) for lfsr in sliced]
        blocks = [unbitslice(x) for x in tmp]

        # Shift columns
        blocks = shiftcolumns(blocks)

        # Restore the state from block representation
        state = list(blocks[0]) + list(blocks[1]) + list(blocks[2]) + list(blocks[3])

        # Add round constant and key
        const = roundconst(round_number)
        state = [xi ^ ki ^ cri for xi,ki,cri in zip(state, key, const)]
    return state


def mysterion2(key_norm, msg_norm):
    """
    >>> msg = [0x1, 0x1, 0x0, 0x0,0xB2, 0xC3, 0xD4, 0xE5,0xF6, 0x07, 0x18, 0x29,0x3A, 0x4B, 0x5C, 0x6D]
    >>> key = [0x2, 0x5, 0x6, 0x7,0x52, 0xF3, 0xE1, 0xF2,0x13, 0x24, 0x35, 0x46,0x5B, 0x6C, 0x7D, 0x88]
    >>> "".join("{:02x}".format(x) for x in mysterion2(key, msg))
    'cd1a8e640087c2db3886e646c7e33def'
    """
    key = byteslice(key_norm)
    state = byteslice(msg_norm)
    for i in range(4): state[i] ^= key[i]

    round_consts_norm = [roundconst(n+1) for n in range(NR)]
    round_consts = [byteslice(x) for x in round_consts_norm]

    for i in range(NR):
        state = sbox(state)
        state = lbox2(state)
        state = shiftcolumns2(state)
        for j in range(4):
            state[j] ^= key[j] ^ round_consts[i][j]

    return unbyteslice(state)


def mysterion2_inv(key_norm, ciphertext_norm):
    """
    >>> msg = [0x1, 0x1, 0x0, 0x0,0xB2, 0xC3, 0xD4, 0xE5,0xF6, 0x07, 0x18, 0x29,0x3A, 0x4B, 0x5C, 0x6D]
    >>> key = [0x2, 0x5, 0x6, 0x7,0x52, 0xF3, 0xE1, 0xF2,0x13, 0x24, 0x35, 0x46,0x5B, 0x6C, 0x7D, 0x88]
    >>> ct = mysterion2(key, msg)
    >>> restored = mysterion2_inv(key, ct)
    >>> msg == restored
    True
    """
    key = byteslice(key_norm)
    state = byteslice(ciphertext_norm)

    round_consts_norm = reversed([roundconst(n+1) for n in range(NR)])
    round_consts = [byteslice(x) for x in round_consts_norm]

    for i in range(NR):
        for j in range(4):
            state[j] ^= key[j] ^ round_consts[i][j]
        state = shiftcolumns2_inv(state)
        state = lbox2_inv(state)
        state = sbox_inv(state)
    for i in range(4): state[i] ^= key[i]

    return unbyteslice(state)


def print_state_sbox(state):
    print("PRINT_STATE_SBOX:")
    for x in state:
        x1 = (x >> 24) & 0xFF
        x2 = (x >> 16) & 0xFF
        x3 = (x >> 8) & 0xFF
        x4 = x & 0xFF
        print("... {:08b} {:08b} {:08b} {:08b}".format(x1, x2, x3, x4))
    print()


def print_state_lbox(state):
    print("PRINT_STATE_LBOX:")
    for i, x in enumerate(state):
        print("{:04b}".format(x), end=" ")
        if i % 8 == 7: print()
    print()


if __name__ == "__main__":
    import doctest
    doctest.testmod()
