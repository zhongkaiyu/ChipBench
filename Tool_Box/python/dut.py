class TopModule:
    def __init__(self):
        self.Q = 0

    def eval(self, inputs):
        rst_n = inputs.get("rst_n", 1)
        if rst_n == 0:
            self.Q = 0
        else:
            old_Q = self.Q & 0xF
            new_bit3 = (~old_Q) & 1
            shifted = (old_Q >> 1) & 0x7
            self.Q = ((new_bit3 << 3) | shifted) & 0xF
        return {"Q": self.Q}
