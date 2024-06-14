import raylibpy as rl
import math

def vector4_length(v: rl.Vector4) -> float:
    return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z + v.w*v.w)

def vector4_normalize(v: rl.Vector4) -> rl.Vector4:
    length = vector4_length(v)
    return rl.Vector4(v.x / length, v.y / length, v.z / length, v.w / length)
