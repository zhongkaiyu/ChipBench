class LFSRCore:
    def compute(self, Q):
        new_bit3 = (~Q) & 1
        shifted = (Q >> 1) & 0x7
        return ((new_bit3 << 3) | shifted) & 0xF


class TopModule:
    def __init__(self):
        self.Q = 0
        self.core = LFSRCore()

    def eval(self, inputs):
        if inputs.get("rst_n", 1) == 0:
            self.Q = 0
        else:
            self.Q = self.core.compute(self.Q)
        return {"Q": self.Q}
