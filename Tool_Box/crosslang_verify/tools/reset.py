import re


def is_reset_signal(name):
    """Check if name is a reset signal. Returns (is_reset, is_active_low)."""
    if not re.search(r'r(?:e)?set|rst', name, re.IGNORECASE):
        return (False, False)
    return (True, is_active_low_reset(name))


def is_active_low_reset(name):
    """Active-low if starts with 'n' or ends with '_n', '_b', '_l'."""
    return bool(re.match(r'^n', name, re.IGNORECASE) or
                re.search(r'_[nbl]$', name, re.IGNORECASE))
