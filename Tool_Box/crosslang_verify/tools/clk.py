import re

def is_clk_signal(inputs):
    '''
    Check if the inputs is a clock signal.
    Returns is_clk
    '''
    for input in inputs:
        if not re.search(r'clk', input[0], re.IGNORECASE):
            return False
        return True
