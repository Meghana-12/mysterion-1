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

def alpha_reduce(x): # reduce binary-coeff. polynomial of alpha modulo a^4 + a + 1
    alpha_poly = 0b10011
    ibit = 0
    while (x >> (ibit+1)) != 0: # find highest nonzero bit
        ibit += 1

    while x > 15: # reduce whenever power of alpha > 4 spotted
        if x & (1 << ibit):
            x ^= alpha_poly << (ibit-4)
        ibit -= 1
    return x


def roundconst(i): # TODO
    return rounds[i]


def sbox(block):
    a = (block[0] & block[1]) ^ block[2]
    c = (block[1] | block[2]) ^ block[3]
    d = (a & block[3]) ^ block[0]
    b = (c & block[0]) ^ block[1]
    return (a,b,c,d)


def lbox(block):
    print(block)
    poly = [3, 4, 12, 8, 12, 4, 3]

    matrix = [[0,3,12,8,3,3,8,12], [3,13,14,0,14,2,5,2], [4,4,12,5,9,1,7,2], [12,1,14,14,10,7,2,0], [8,0,2,7,10,14,14,1], [12,2,7,1,9,5,12,4], [4,2,5,2,14,0,14,13], [3,12,8,3,3,8,12,3]]

    lsfr = 8*[0]
    for ialpha in range(4): # degree of alpha
        for ix in range(8): # for each value to be in LSFR state
            lsfr[7-ix] |= ((block[3-ialpha] & (1 << ix)) >> ix) << ialpha
            # TODO check if block0..block3 maps to a0..a3 or a3..a0
    lsfr = [0,1,0,0,0,0,0,0]
    print(lsfr)

    lsfrout = 8*[0]
    for iout in range(8):
        for iin in range(8):
            lsfrout[iout] |= lsfr[iin] << matrix[iout][iin]
        lsfrout[iout] = alpha_reduce(lsfrout[iout])
    lsfr = lsfrout

    # for iclk in range(8): # LSFR clock
    #     print(lsfr)
    #     carry = lsfr[7]
    #     next = 8*[0]
    #     next[0] = carry
    #     for ix in range(7): # for each F[2^4] value in the LSFR
    #         next[ix+1] = alpha_reduce(lsfr[ix] + (carry << poly[ix]))
    #     lsfr = next
    # print(lsfr)

    out = 4*[0]
    for ialpha in range(4): # for each value to be in LSFR state
        for ix in range(8): # degree of alpha
            out[3-ialpha] |= ((lsfr[7-ix] & (1 << ialpha)) >> ialpha) << ix
    print(out)
    return out


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
    blocks = [tuple(xi for i,xi in enumerate(x) if i%4 == iblock) for iblock in range(4)]

    # for each round
    for r in range(NR):
        # S boxes
        for j in range(B):
            blocks = [sbox(block) for block in blocks]

        # L boxes
        for j in range(B):
            blocks = [lbox(block) for block in blocks]

        # Shift columns
        for k in range(S):
            blocks = shiftcolumns(blocks)

        roundconst = roundconst(r) # round constant
        x = [xi ^ ki ^ cri for xi,ki,cri in zip(key, input, roundconst)]

    return x



#print(mysterion(key1, input1))
print(['%02x' % x for x in lbox((0,0,0,0))])