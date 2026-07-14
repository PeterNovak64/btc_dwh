import json

# Odpri datoteko run_results.json
with open("target/run_results.json", encoding="utf8") as f:
    rr = json.load(f)

# Odpri datoteko manifest.json
with open("target/manifest.json", encoding="utf8") as f:
    mf = json.load(f)

# Iteriraj skozi rezultate testov
for r in rr["results"]:

    uid = r["unique_id"]

    # Poišči test v manifestu
    node = mf["nodes"].get(uid)

    if not node:
        continue

    if node["resource_type"] != "test":
        continue

    # MODEL
    model_name = None

    for dep in node.get("depends_on", {}).get("nodes", []):
        if dep.startswith("model."):
            model_name = dep.split(".")[-1]
            break

    # TEST type
    test_metadata = node.get("test_metadata", {})
    test_type = test_metadata.get("name")

    # Stolpec, ki ga testira
    column_name = node.get("column_name")

    # Včasih dbt stolpec hrani v kwargs
    if not column_name:
        column_name = test_metadata.get("kwargs", {}).get("column_name")


    print("MODEL:", model_name)
    print("TEST:", node["name"])
    print("TEST TYPE:", test_type)
    print("COLUMN NAME:", column_name)
    print("STATUS:", r["status"])
    print("FAILURES:", r.get("failures"))
    print("----------------------")
