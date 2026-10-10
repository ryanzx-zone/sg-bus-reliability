import json
import sys

from lta import BASE, fetch_all

# Reference data barely changes, so download once and reuse (data/ is gitignored)
CACHE = BASE / "data" / "reference"

USAGE = """Usage:
  python explore_route.py 151              list every stop on service 151, in order
  python explore_route.py 12345 67890      list services that go from stop 12345 to stop 67890"""


def cached(dataset):
    path = CACHE / f"{dataset}.json"
    if not path.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(fetch_all(dataset)))
    return json.loads(path.read_text())


args = sys.argv[1:]
if len(args) not in (1, 2):
    sys.exit(USAGE)

routes = cached("BusRoutes")
names = {s["BusStopCode"]: f'{s["Description"]} ({s["RoadName"]})' for s in cached("BusStops")}

if len(args) == 1:
    service = args[0].upper()
    for direction in (1, 2):
        stops = sorted(
            (r for r in routes if r["ServiceNo"] == service and r["Direction"] == direction),
            key=lambda r: r["StopSequence"],
        )
        if not stops:
            continue
        print(f"\nService {service}, direction {direction}:")
        for r in stops:
            print(f'  {r["StopSequence"]:>3}  {r["BusStopCode"]}  {names.get(r["BusStopCode"], "?")}')

else:
    start, end = args
    print(f"From {start} {names.get(start, '?')}")
    print(f"To   {end} {names.get(end, '?')}\n")

    # For each service+direction, where in the route each stop appears
    position = {}
    for r in routes:
        position.setdefault((r["ServiceNo"], r["Direction"]), {}).setdefault(r["BusStopCode"], r["StopSequence"])

    found = False
    for (service, direction), seq in sorted(position.items()):
        if start in seq and end in seq and seq[start] < seq[end]:
            print(f"  {service:>5}  (direction {direction}, {seq[end] - seq[start]} stops)")
            found = True
    if not found:
        print("  No direct service between these two stops.")
