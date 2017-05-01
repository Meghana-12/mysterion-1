import operator

key1 = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
input1 = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
output1 = [0xDC, 0xB4, 0xFB, 0x8B, 0xA6, 0x1D, 0x81, 0xA1, 0x83, 0x51, 0xB7, 0x6D, 0xF9, 0xF8, 0xCD, 0x47]

key2 = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
input2 = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
output2 = [0x6F, 0xBB, 0x09, 0x5F, 0x92, 0x03, 0xF7, 0x93, 0x62, 0x96, 0x08, 0x05, 0xA5, 0xEF, 0x22, 0x82]

# TODO these are from a Fantomas implementation online, check if accurate
rounds = [0xBFFF, 0x6E90, 0xD16F, 0x4137, 0xFEC8, 0x2FA7, 0x9058, 0xD548, 0x6AB7, 0xBBD8, 0x0427, 0x947F]

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


def lbox(state):
    """
    >>> lbox([0, 0, 0, 0, 0, 0, 0, 1])
    [8, 15, 5, 8, 8, 5, 15, 8]
    >>> lbox([1, 0, 0, 0, 0, 0, 0, 0])
    [1, 8, 15, 5, 8, 8, 5, 15]
    >>> lbox(list(range(8)))
    [10, 14, 1, 3, 2, 15, 3, 13]
    """
    poly = [0b1000, 0b0011, 0b1111, 0b0101, 0b1111, 0b0011, 0b1000]
    for clock in range(8):
        x = state.pop(0)
        for idx in range(7):
            x ^= _gf16_mul(state[idx], poly[idx])
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


def mysterion(key, input):
    x = [ki ^ ii for ki,ii in zip(key,input)]

    # for each round
    for r in range(NR):
        blocks = [tuple(xi for i,xi in enumerate(x) if i%4 == iblock) for iblock in range(4)]

        # S boxes
        blocks = [sbox(block) for block in blocks]

        # L boxes
        sliced = [bitslice(block) for block in blocks]
        tmp = [lbox(lfsr) for lfsr in sliced]
        blocks = [unbitslice(x) for x in tmp]

        # Shift columns
        blocks = shiftcolumns(blocks)

        const = roundconst(r) # round constant

        x = list(blocks[0]) + list(blocks[1]) + list(blocks[2]) + list(blocks[3])
        x = [xi ^ ki ^ cri for xi,ki,cri in zip(x, key, const)]

    return x



# out = mysterion(key1, input1)
# print(['%02x' % x for x in out])
print(['%02x' % x for x in unbitslice(lbox(bitslice((0x10,0x10,0x10,0x10))))])
