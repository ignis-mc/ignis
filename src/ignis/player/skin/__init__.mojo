"""Player skins, ported from Dragonfly `server/player/skin`."""

from .animation import (
    ANIMATION_BODY_128X128,
    ANIMATION_BODY_32X32,
    ANIMATION_HEAD,
    Animation,
    AnimationType,
)
from .cape import Cape
from .model_config import ModelConfig, decode_model_config
from .skin import Skin
