# Copyright 2024-2025 The Alibaba Wan Team Authors. All rights reserved.
from . import configs, distributed, modules

_lazy_imports = {
    "WanI2V": ".image2video",
    "WanS2V": ".speech2video",
    "WanT2V": ".text2video",
    "WanTI2V": ".textimage2video",
    "WanAnimate": ".animate",
}


def __getattr__(name):
    if name in _lazy_imports:
        import importlib
        module = importlib.import_module(_lazy_imports[name], __name__)
        return getattr(module, name)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")