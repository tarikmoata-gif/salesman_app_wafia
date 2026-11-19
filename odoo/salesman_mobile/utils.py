from math import radians, sin, cos, asin, sqrt
def haversine_m(lat1, lon1, lat2, lon2):
    """Distance in meters between two GPS points."""
    p1, p2 = radians(lat1), radians(lat2)
    a = sin((p2-p1)/2)**2 + cos(p1)*cos(p2)*sin(radians(lon2-lon1)/2)**2
    return 2*6371000*asin(sqrt(a))
