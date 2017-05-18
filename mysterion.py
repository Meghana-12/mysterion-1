import operator


NR = 12
B = 4
S = 4
L = 8


def roundconst(i): # TODO
    block = [0] * 16

    for idx in range(4):
        lfsr_in = [0, 0, 0, 0, 0, 0, 0, 0]
        lfsr_in[idx*2 + 1] = i
        tmp = lbox(lfsr_in)
        block[4 * idx] = (tmp[0] << 4) | tmp[1]
    return block


def sbox(block):
    a = (block[0] & block[1]) ^ block[2]
    c = (block[1] | block[2]) ^ block[3]
    d = (a & block[3]) ^ block[0]
    b = (c & block[0]) ^ block[1]
    return (a,b,c,d)


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
    ...     y1.append(_gf16_mul(z, 8))

    >>> x2 = bitslice_32x4([x % 16 for x in range(32)])
    >>> z = bitslice_32x4([8]*32)
    >>> y2 = unbitslice_32x4(_gf16_mul2(x2, z))

    >>> y1 == y2
    True
    """
    a = a[:]
    b = b[:]

    # a, b lists of length 4
    ret = [0, 0, 0, 0]

    ret[0] ^= a[0] & b[0] # add
    ret[1] ^= a[1] & b[0]
    ret[2] ^= a[2] & b[0]
    ret[3] ^= a[3] & b[0]
    a[0]   ^= a[3] # reduce

    ret[0] ^= a[3] & b[1] # add
    ret[1] ^= a[0] & b[1]
    ret[2] ^= a[1] & b[1]
    ret[3] ^= a[2] & b[1]
    a[3]   ^= a[2] # reduce

    ret[0] ^= a[2] & b[2] # add
    ret[1] ^= a[3] & b[2]
    ret[2] ^= a[0] & b[2]
    ret[3] ^= a[1] & b[2]
    a[2]   ^= a[1] # reduce

    ret[0] ^= a[1] & b[3] # add
    ret[1] ^= a[2] & b[3]
    ret[2] ^= a[3] & b[3]
    ret[3] ^= a[0] & b[3]
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
            ret[j] |= ((x[i] & (1 << j)) >> j) << i
    return ret

def unbitslice_32x4(x):
    # x is a list of 4 32-bit numbers
    ret = [0] * 32
    for i in range(4):
        for j in range(32):
            ret[j] |= ((x[i] & (1 << j)) >> j) << i
    return ret


def lbox2(state):
    """
    >>> x = [0, 0, 0, 0, 0, 0, 0, 1]
    >>> y = unbitslice_32x4(lbox2(bitslice_32x4(x * 4)))
    >>> y == lbox(x) * 4
    True

    >>> x = [1, 0, 0, 0, 0, 0, 0, 0]
    >>> y = unbitslice_32x4(lbox2(bitslice_32x4(x * 4)))
    >>> y == lbox(x) * 4
    True

    >>> x = list(range(8))
    >>> y = unbitslice_32x4(lbox2(bitslice_32x4(x * 4)))
    >>> y == lbox(x) * 4
    True
    """

    # state is a list of 4 32-bit numbers (in bitsliced form!)
    def poly(n):
        """
        Function to generate a polynomial in bitsliced format for a specific
        round. This function is pure and the results are to be hardcoded in
        the actual product.
        """
        poly_norm = [0, 0b1000, 0b0011, 0b1111, 0b0101, 0b1111, 0b0011, 0b1000]
        # poly_norm = poly_norm[8-n:7] + poly_norm[n:]
        poly_norm = poly_norm[-n:] + poly_norm[:-n]
        return bitslice_32x4(poly_norm * 4)

    for clock in range(8):
        x = _gf16_mul2(poly(clock), state)
        accs = []
        for reg in range(4): # reg for register
            acc = 0
            for i in range(8):
                acc ^= x[reg] << i
            accs.append(acc)
            # state[reg] &= state[reg] & ~(0x80808080 >> clock)
            state[reg] ^= (acc & 0x80808080) >> 7 << clock


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


if __name__ == "__main__":
    import doctest
    doctest.testmod()
