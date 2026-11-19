import importlib.util, pathlib
s = importlib.util.spec_from_file_location('u', pathlib.Path(__file__).parent.parent/'utils.py'); u = importlib.util.module_from_spec(s); s.loader.exec_module(u)
h = u.haversine_m
assert h(24.4672, 39.6024, 24.4672, 39.6024) < 0.01
assert 40 < h(24.4672, 39.6024, 24.46756, 39.6024) < 41
assert 55 < h(24.4672, 39.6024, 24.46770, 39.6024) < 57
assert 110_000 < h(0, 0, 0, 1) < 112_000
print("geo tests OK")
